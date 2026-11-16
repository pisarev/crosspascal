unit OmDetTurbo.Worker;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Windows, Classes, SysUtils, SyncObjs{$ELSE}
  Winapi.Windows, System.Classes, System.SysUtils, System.SyncObjs{$ENDIF},
  TVM.OmDetModel, CrossVision.Mat, OmDetTurbo.Run;

type
  TOmDetJobKind = (ojInfer, ojUnload);
  TOmDetJob = record
    Kind: TOmDetJobKind;
    Bundle: string;
    Runtime: string;
    ImageDigest: string;
    Image: IMat;
    Labels: TOmDetLabels;
    Task: UnicodeString;
    AllowTruncate: Boolean;
    ScoreThreshold: Single;
    NmsThreshold: Single;
  end;
  TOmDetOutcome = record
    Kind: TOmDetJobKind;
    Value: TOmDetResult;
    ErrorText: string;
    Stopped: Boolean;
    RequiresRestart: Boolean;
  end;

  TOmDetWorker = class(TThread)
  private
    FLock: TRTLCriticalSection;
    FWake: TEvent;
    FJob: TOmDetJob;
    FOutcome: TOmDetOutcome;
    FBusy: Boolean;
    FDone: Boolean;
    FStopFlag: LongInt;
    FStage: string;
    FShutdownError: string;
    procedure Progress(const Stage: UnicodeString);
    function Stopping: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Submit(const Job: TOmDetJob);
    procedure Stop;
    procedure Shutdown;
    function Busy: Boolean;
    function Stage: string;
    function Collect(out Value: TOmDetOutcome): Boolean;
    property ShutdownError: string read FShutdownError;
  end;

implementation

uses
  TVM.CpuGraph, TVM.Threads;

constructor TOmDetWorker.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  InitializeCriticalSection(FLock);
  FWake := TEvent.Create(nil, False, False, '');
end;

destructor TOmDetWorker.Destroy;
begin
  Shutdown;
  FJob := Default(TOmDetJob);
  FOutcome := Default(TOmDetOutcome);
  FWake.Free;
  DeleteCriticalSection(FLock);
  inherited;
end;

procedure TOmDetWorker.Submit(const Job: TOmDetJob);
begin
  EnterCriticalSection(FLock);
  try
    RequireCpu(not FBusy and not FDone and not Terminated, 'Wait for the current operation to finish.');
    FJob := Job;
    FJob.Labels := Copy(Job.Labels, 0, Length(Job.Labels));
    FBusy := True;
    FStage := 'Starting';
    InterlockedExchange(FStopFlag, 0);
  finally
    LeaveCriticalSection(FLock);
  end;
  FWake.SetEvent;
end;

procedure TOmDetWorker.Stop;
begin
  InterlockedExchange(FStopFlag, 1);
end;

procedure TOmDetWorker.Shutdown;
begin
  Terminate;
  Stop;
  if FWake <> nil then FWake.SetEvent;
  if Suspended then Start;
  WaitFor;
end;

function TOmDetWorker.Stopping: Boolean;
begin
  Result := Terminated or (InterlockedCompareExchange(FStopFlag, 0, 0) <> 0);
end;

procedure TOmDetWorker.Progress(const Stage: UnicodeString);
begin
  EnterCriticalSection(FLock);
  try
    FStage := Stage;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TOmDetWorker.Busy: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FBusy;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TOmDetWorker.Stage: string;
begin
  EnterCriticalSection(FLock);
  try
    Result := FStage;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TOmDetWorker.Collect(out Value: TOmDetOutcome): Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FDone;
    if Result then
    begin
      Value := FOutcome;
      FOutcome := Default(TOmDetOutcome);
      FDone := False;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TOmDetWorker.Execute;
var
  Model: TOmDetModel;
  Bundle, Runtime: string;
  Job: TOmDetJob;
  Outcome: TOmDetOutcome;
  ErrorText: string;
  WaitResult: TWaitResult;
  Started: UInt64;
begin
  Model := nil;
  try
    try
      while not Terminated do
      begin
        WaitResult := FWake.WaitFor(100);
        if WaitResult = wrTimeout then Continue;
        RequireCpu(WaitResult = wrSignaled, 'The inference worker could not wait for a request.');
        if Terminated then Break;
        EnterCriticalSection(FLock);
        try
          Job := FJob;
          FJob := Default(TOmDetJob);
        finally
          LeaveCriticalSection(FLock);
        end;
        Outcome := Default(TOmDetOutcome);
        Outcome.Kind := Job.Kind;
        Started := GetTickCount64;
        try
          if (Job.Kind = ojUnload) or ((Model <> nil) and
            (not SameText(Bundle, Job.Bundle) or not SameText(Runtime, Job.Runtime))) then
            begin
              Progress('Unload model');
              if Model <> nil then
              begin
                Model.Close;
                FreeAndNil(Model);
              end;
            end;
          if Job.Kind = ojInfer then
          begin
            if Model = nil then
            begin
              Progress('Load model');
              Model := TOmDetModel.Create(Job.Bundle, Job.Runtime);
              Bundle := Job.Bundle;
              Runtime := Job.Runtime;
            end;
            Outcome.Value := InferOmDet(Model, Job.Image, Job.ImageDigest, Job.Labels, Job.Task,
              Job.AllowTruncate, Job.ScoreThreshold, Job.NmsThreshold, Stopping, Progress);
            Outcome.Value.Milliseconds := GetTickCount64 - Started;
          end;
        except
          on E: ECpuGraphStopped do Outcome.Stopped := True;
          on E: Exception do Outcome.ErrorText := Stage + ': ' + E.ClassName + ': ' + E.Message;
        end;
        Outcome.RequiresRestart := OmDetRequiresProcessRestart;
        if Outcome.RequiresRestart then FreeAndNil(Model);
        Job := Default(TOmDetJob);
        EnterCriticalSection(FLock);
        try
          FOutcome := Outcome;
          FDone := True;
          FBusy := False;
        finally
          LeaveCriticalSection(FLock);
        end;
      end;
    except
      on E: Exception do
      begin
        FShutdownError := E.ClassName + ': ' + E.Message;
        Terminate;
        EnterCriticalSection(FLock);
        try
          FOutcome := Default(TOmDetOutcome);
          FOutcome.ErrorText := FShutdownError;
          FOutcome.RequiresRestart := True;
          FDone := True;
          FBusy := False;
        finally
          LeaveCriticalSection(FLock);
        end;
      end;
    end;
  finally
    try
      try
        if Model <> nil then Model.Close;
      except
        on E: Exception do
        begin
          if FShutdownError <> '' then FShutdownError := FShutdownError + ' ';
          FShutdownError := FShutdownError + E.ClassName + ': ' + E.Message;
        end;
      end;
    finally
      Model.Free;
      Job := Default(TOmDetJob);
      ErrorText := FShutdownError;
      FinishTVMThread(ErrorText);
      FShutdownError := ErrorText;
    end;
  end;
end;

end.
