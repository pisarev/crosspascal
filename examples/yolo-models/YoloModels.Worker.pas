{ ************************************************************************** }
{                                                                            }
{ YoloModels.Worker                                                           }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                       }
{                                                                            }
{ ************************************************************************** }

unit YoloModels.Worker;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  {$IFDEF FPC}Classes, SysUtils, {$IFDEF MSWINDOWS}Windows,{$ENDIF}SyncObjs{$ELSE}
  System.Classes, System.SysUtils, Winapi.Windows, System.SyncObjs{$ENDIF},
  CrossVision.Mat, TVM.Yolo.Profile, TVM.Yolo.RunOptions, YoloModels.Run, YoloModels.Render;

type
  TYoloExampleJobKind = (yjInfer, yjUnload, yjExport, yjRender);
  TYoloExampleJob = record
    Kind: TYoloExampleJobKind;
    BundleDirectory: string;
    RuntimeDirectory: string;
    ManifestSHA256: string;
    ManifestBytes: Int64;
    Profile: TYoloProfile;
    Options: TYoloRunOptions;
    Image: IMat;
    ImageSHA256: string;
    ExportDirectory: string;
    Preview: IMat;
    Value: TYoloExampleResult;
    PreviewRequested: Boolean;
    ViewStyle: TYoloViewStyle;
    TextMode: TYoloTextMode;
  end;

  TYoloExampleOutcome = record
    Kind: TYoloExampleJobKind;
    Value: TYoloExampleResult;
    Frame: TYoloViewFrame;
    ErrorText: string;
    Stopped: Boolean;
    Fatal: Boolean;
    SessionReused: Boolean;
    SessionGeneration: UInt64;
    OperationMilliseconds: UInt64;
  end;

  { One persistent owning thread. Submit and Collect run on the UI thread;
    Stop may run on any thread. Submitted image/map pixels remain immutable.
    Stop cooperates with inference; an export finishes its current file work.
    Destroy joins before releasing images or the selected image runtime. }
  TYoloExampleWorker = class(TThread)
  private
    FLock: TCriticalSection;
    FWake: TEvent;
    FJob: TYoloExampleJob;
    FOutcome: TYoloExampleOutcome;
    FBusy: Boolean;
    FDone: Boolean;
    FJoined: Boolean;
    FStopFlag: LongInt;
    FStage: string;
    FShutdownError: string;
    function Stopping: Boolean;
    procedure Progress(const Value: string);
    procedure Publish(const Value: TYoloExampleOutcome);
    function MakePreview(const Image: IMat; const Value: TYoloExampleResult;
      const Style: TYoloViewStyle; const TextMode: TYoloTextMode): TYoloViewFrame;
  protected
    procedure Execute; override;
  public
    constructor Create;
    procedure AfterConstruction; override;
    destructor Destroy; override;
    procedure Submit(const Job: TYoloExampleJob);
    procedure Stop;
    procedure Shutdown;
    function Busy: Boolean;
    function Stage: string;
    function Collect(out Value: TYoloExampleOutcome): Boolean;
    function ShutdownError: string;
  end;

implementation

uses
  TVM.CpuGraph, TVM.Threads, TVM.Yolo.Native, TVM.Yolo.Identity, YoloModels.Export
  {$IFDEF MSWINDOWS}, YoloModels.WindowsText{$ENDIF};

constructor TYoloExampleWorker.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
end;

procedure TYoloExampleWorker.AfterConstruction;
begin
  inherited;
  Start;
end;

destructor TYoloExampleWorker.Destroy;
begin
  Shutdown;
  FJob := Default(TYoloExampleJob);
  FOutcome := Default(TYoloExampleOutcome);
  FWake.Free;
  FLock.Free;
  inherited;
end;

procedure TYoloExampleWorker.Submit(const Job: TYoloExampleJob);
var
  CopyJob: TYoloExampleJob;
begin
  CopyJob := Job;
  if Job.Kind = yjInfer then
  begin
    Job.Profile.Validate;
    Job.Options.Validate;
    CopyJob.Profile := CopyYoloProfile(Job.Profile);
    CopyJob.Options.ShouldStop := nil;
  end;
  if (Job.Kind = yjRender) or ((Job.Kind = yjInfer) and Job.PreviewRequested) then
    Job.ViewStyle.Validate;
  if Job.Kind = yjRender then
    CopyJob.Value.Profile := CopyYoloProfile(Job.Value.Profile);
  FLock.Enter;
  try
    RequireCpu(not FBusy and not FDone and not FJoined and not Terminated,
      'Wait for the current operation and collect its result first.');
    FJob := CopyJob;
    FBusy := True;
    FStage := 'Queued';
    InterlockedExchange(FStopFlag, 0);
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TYoloExampleWorker.MakePreview(const Image: IMat; const Value: TYoloExampleResult;
  const Style: TYoloViewStyle; const TextMode: TYoloTextMode): TYoloViewFrame;
{$IFDEF MSWINDOWS}
var
  Extent: NativeInt;
{$ENDIF}
begin
  Progress('Rendering result');
  Result := RenderYoloFrame(Image, Value, Style, Stopping);
  {$IFDEF MSWINDOWS}
  try
    Extent := NativeInt(Result.Image.Height - 1) * Result.Image.Step +
      NativeInt(Result.Image.Width) * 3;
    PaintYoloWindowsText(Result.Image.DataPtr, Extent, Result.Image.Step,
      Result.Image.Width, Result.Image.Height, Result.Labels, Result.Legend, TextMode, Stopping);
  except
    Result := Default(TYoloViewFrame);
    raise;
  end;
  {$ENDIF}
end;

procedure TYoloExampleWorker.Stop;
begin
  InterlockedExchange(FStopFlag, 1);
end;

procedure TYoloExampleWorker.Shutdown;
begin
  if FJoined then Exit;
  Terminate;
  Stop;
  if FWake <> nil then FWake.SetEvent;
  WaitFor;
  { The RTL may skip Execute when termination wins the initial start race. }
  FLock.Enter;
  try
    FJob := Default(TYoloExampleJob);
    FBusy := False;
    FJoined := True;
    FStage := 'Closed';
  finally
    FLock.Leave;
  end;
end;

function TYoloExampleWorker.Stopping: Boolean;
begin
  Result := Terminated or (InterlockedCompareExchange(FStopFlag, 0, 0) <> 0);
end;

procedure TYoloExampleWorker.Progress(const Value: string);
begin
  FLock.Enter;
  try
    FStage := Value;
  finally
    FLock.Leave;
  end;
end;

procedure TYoloExampleWorker.Publish(const Value: TYoloExampleOutcome);
begin
  FLock.Enter;
  try
    FOutcome := Value;
    FDone := True;
    FBusy := False;
    if Value.Stopped then
      FStage := 'Stopped'
    else if Value.ErrorText <> '' then
      FStage := 'Error'
    else
      FStage := 'Ready';
  finally
    FLock.Leave;
  end;
end;

function TYoloExampleWorker.Busy: Boolean;
begin
  FLock.Enter;
  try
    Result := FBusy;
  finally
    FLock.Leave;
  end;
end;

function TYoloExampleWorker.Stage: string;
begin
  FLock.Enter;
  try
    Result := FStage;
  finally
    FLock.Leave;
  end;
end;

function TYoloExampleWorker.ShutdownError: string;
begin
  FLock.Enter;
  try
    Result := FShutdownError;
  finally
    FLock.Leave;
  end;
end;

function TYoloExampleWorker.Collect(out Value: TYoloExampleOutcome): Boolean;
begin
  FLock.Enter;
  try
    Result := FDone;
    if Result then
    begin
      Value := FOutcome;
      FOutcome := Default(TYoloExampleOutcome);
      FDone := False;
    end
    else
      Value := Default(TYoloExampleOutcome);
  finally
    FLock.Leave;
  end;
end;

procedure TYoloExampleWorker.Execute;
var
  Session: TYoloExampleSession;
  Job: TYoloExampleJob;
  Outcome: TYoloExampleOutcome;
  Options, CachedOptions: TYoloRunOptions;
  BundleDirectory, RuntimeDirectory, ManifestSHA256, Identity, CachedIdentity: string;
  ManifestBytes: Int64;
  Generation, Started: UInt64;
  WaitResult: TWaitResult;
  ErrorText: string;
begin
  Session := nil;
  Generation := 0;
  ManifestBytes := 0;
  CachedOptions := Default(TYoloRunOptions);
  try
    try
      while not Terminated do
      begin
        WaitResult := FWake.WaitFor(100);
        if WaitResult = wrTimeout then Continue;
        RequireCpu(WaitResult = wrSignaled, 'The YOLO worker could not wait for a request.');
        if Terminated then Break;
        FLock.Enter;
        try
          Job := FJob;
          FJob := Default(TYoloExampleJob);
        finally
          FLock.Leave;
        end;
        Outcome := Default(TYoloExampleOutcome);
        Outcome.Kind := Job.Kind;
        Started := GetTickCount64;
        try
          case Job.Kind of
            yjUnload:
              begin
                Progress('Unloading model');
                FreeAndNil(Session);
              end;
            yjInfer:
              begin
                CheckYoloRunStop(Stopping);
                Identity := YoloProfileIdentity(Job.Profile);
                Options := Job.Options;
                Options.ShouldStop := Stopping;
                Outcome.SessionReused := (Session <> nil) and
                  (BundleDirectory = Job.BundleDirectory) and
                  (RuntimeDirectory = Job.RuntimeDirectory) and
                  (ManifestSHA256 = Job.ManifestSHA256) and
                  (ManifestBytes = Job.ManifestBytes) and (CachedIdentity = Identity) and
                  (CachedOptions.Confidence = Options.Confidence) and
                  (CachedOptions.NmsIoU = Options.NmsIoU);
                if not Outcome.SessionReused then
                begin
                  FreeAndNil(Session);
                  Progress('Loading model');
                  Session := TYoloExampleSession.Create(Job.BundleDirectory, Job.ManifestSHA256,
                    Job.ManifestBytes, Job.RuntimeDirectory, Job.Profile, Options);
                  RequireCpu(TVMThreadShutdownAvailable,
                    'The selected runtime does not provide native worker shutdown.');
                  BundleDirectory := Job.BundleDirectory;
                  RuntimeDirectory := Job.RuntimeDirectory;
                  ManifestSHA256 := Job.ManifestSHA256;
                  ManifestBytes := Job.ManifestBytes;
                  CachedIdentity := Identity;
                  CachedOptions := Options;
                  Inc(Generation);
                end;
                Progress('Running ' + Job.Profile.ID);
                Outcome.Value := Session.Run(Job.Image, Job.ImageSHA256);
                if Job.PreviewRequested then
                  Outcome.Frame := MakePreview(Job.Image, Outcome.Value, Job.ViewStyle, Job.TextMode);
              end;
            yjExport:
              begin
                Progress('Saving result');
                CheckYoloRunStop(Stopping);
                SaveYoloExampleResult(Job.ExportDirectory, Job.Image, Job.Preview, Job.Value);
              end;
            yjRender:
              begin
                Outcome.Value := Job.Value;
                Outcome.Frame := MakePreview(Job.Image, Job.Value, Job.ViewStyle, Job.TextMode);
              end;
          end;
        except
          on E: ECpuGraphStopped do Outcome.Stopped := True;
          on E: Exception do
          begin
            Outcome.ErrorText := Stage + ': ' + E.ClassName + ': ' + E.Message;
            if Job.Kind = yjInfer then FreeAndNil(Session);
          end;
        end;
        Outcome.OperationMilliseconds := GetTickCount64 - Started;
        Outcome.SessionGeneration := Generation;
        Job := Default(TYoloExampleJob);
        Publish(Outcome);
        Outcome := Default(TYoloExampleOutcome);
      end;
    except
      on E: Exception do
      begin
        ErrorText := E.ClassName + ': ' + E.Message;
        Outcome := Default(TYoloExampleOutcome);
        Outcome.ErrorText := ErrorText;
        Outcome.Fatal := True;
        Terminate;
        Publish(Outcome);
      end;
    end;
  finally
    Session.Free;
    Job := Default(TYoloExampleJob);
    FLock.Enter;
    try
      FJob := Default(TYoloExampleJob);
      FBusy := False;
    finally
      FLock.Leave;
    end;
    FinishTVMThread(ErrorText);
    FLock.Enter;
    try
      FShutdownError := ErrorText;
    finally
      FLock.Leave;
    end;
  end;
end;

end.
