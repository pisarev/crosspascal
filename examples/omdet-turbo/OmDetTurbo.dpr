program OmDetTurbo;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE GUI}
{$IFNDEF TVM_LAZY_INIT}
  {$MESSAGE ERROR 'Open the OmDetTurbo project; TVM_LAZY_INIT must be a project-wide define'}
{$ENDIF}

uses
  CrossPascal.NativeIO, {$IFDEF FPC}Interfaces, Windows, SysUtils, Classes, Forms, Graphics{$ELSE}
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Forms, Vcl.Graphics{$ENDIF},
  CrossPascal.Json, CrossVision.Mat, OpenCV, ExampleDefaults, TVM.CpuGraph, TVM.OmDetModel,
  OmDetTurbo.Run in 'OmDetTurbo.Run.pas', OmDetTurbo.Render in 'OmDetTurbo.Render.pas',
  OmDetTurbo.Worker in 'OmDetTurbo.Worker.pas', OmDetTurbo.Main in 'OmDetTurbo.Main.pas';

function Option(const Name, Default: string): string;
var
  I: Integer;
  Prefix: string;
begin
  Result := Default;
  Prefix := Name + '=';
  for I := 1 to NativeParamCount do
    if Copy(NativeParamStr(I), 1, Length(Prefix)) = Prefix then
      Exit(Copy(NativeParamStr(I), Length(Prefix) + 1, MaxInt));
end;

function Flag(const Name: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to NativeParamCount do if NativeParamStr(I) = Name then Exit(True);
end;

function ClassesOption: TOmDetLabels;
var
  Lines: TStringList;
  Path, Text: string;
  I, Count: Integer;
begin
  Lines := TStringList.Create;
  try
    Path := Option('--classes-file', '');
    if Path <> '' then
      Lines.LoadFromFile(Path, TEncoding.UTF8)
    else begin
      Lines.StrictDelimiter := True;
      Lines.Delimiter := ';';
      Lines.DelimitedText := {$IFDEF FPC}UTF8Encode{$ENDIF}(Option('--classes',
        'person;helmet;flag;space shuttle'));
    end;
    SetLength(Result, Lines.Count);
    Count := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Text := Trim({$IFDEF FPC}UTF8Decode{$ENDIF}(Lines[I]));
      if Text = '' then Continue;
      Result[Count] := Text;
      Inc(Count);
    end;
    RequireCpu((Count >= 1) and (Count <= 16), 'Choose 1 to 16 text classes.');
    SetLength(Result, Count);
  finally
    Lines.Free;
  end;
end;

function ThresholdOption(const Name: string): Single;
var
  Value: Double;
  Bits: UInt64;
begin
  RequireCpu(TryStrToFloat(Option(Name, '0.3'), Value, JSONInvariantFormat), 'Invalid threshold: ' + Name);
  Move(Value, Bits, SizeOf(Bits));
  RequireCpu((Bits and $7FF0000000000000) <> $7FF0000000000000, 'Threshold must be finite.');
  RequireCpu((Value >= 0) and (Value <= 1), 'Threshold must be between 0 and 1.');
  Result := Value;
end;

function RecordedResult(const CVLibrary, Bundle, Runtime, ImagePath: string): string;
var
  Worker: TOmDetWorker;
  Job: TOmDetJob;
  Outcome: TOmDetOutcome;
  Image: IMat;
  Bitmap: TBitmap;
  Value: TOmDetResult;
  ReportPath, OutputPath, Digest, ErrorText: string;
  Started: UInt64;
begin
  ReportPath := Option('--report', '');
  RequireCpu((ReportPath <> '') and not FileExists(ReportPath) and SameText(ExtractFileExt(ReportPath), '.json'),
    'Recorded mode requires --report=<new JSON file>.');
  OutputPath := Option('--output', ChangeFileExt(ReportPath, '.png'));
  RequireCpu(SameText(ExtractFileExt(OutputPath), '.png') and not FileExists(OutputPath),
    'Choose a new PNG output file.');
  Image := ReadOmDetImage(ImagePath, CVLibrary, Digest);
  Worker := nil;
  ErrorText := '';
  Started := GetTickCount64;
  try
    try
      Job := Default(TOmDetJob);
      Job.Bundle := Bundle;
      Job.Runtime := Runtime;
      Job.Image := Image;
      Job.ImageDigest := Digest;
      Job.Labels := ClassesOption;
      Job.Task := Option('--task', '');
      Job.AllowTruncate := Flag('--truncate');
      Job.ScoreThreshold := ThresholdOption('--confidence');
      Job.NmsThreshold := ThresholdOption('--nms');
      Worker := TOmDetWorker.Create;
      Worker.Start;
      Worker.Submit(Job);
      while not Worker.Collect(Outcome) do Sleep(5);
      RequireCpu(Outcome.ErrorText = '', Outcome.ErrorText);
      RequireCpu(not Outcome.Stopped, 'OmDet was stopped.');
      RequireCpu(not Outcome.RequiresRestart, 'Restart the application. ' + OmDetCleanupDiagnostic);
      Value := Outcome.Value;
    except
      on E: Exception do ErrorText := E.ClassName + ': ' + E.Message;
    end;
  finally
    if Worker <> nil then
    begin
      Worker.Shutdown;
      if Worker.ShutdownError <> '' then
      begin
        if ErrorText <> '' then ErrorText := ErrorText + ' ';
        ErrorText := ErrorText + Worker.ShutdownError;
      end;
      Worker.Free;
    end;
    Job := Default(TOmDetJob);
  end;
  RequireCpu(ErrorText = '', ErrorText);
  Value.Milliseconds := GetTickCount64 - Started;
  Bitmap := OmDetOverlay(Image, Value);
  try
    SaveOmDetPNG(OutputPath, Bitmap);
  finally
    Bitmap.Free;
  end;
  Result := OmDetResultJSON(Value, 'PASS');
end;

procedure RunWindow(const CVLibrary, Bundle, Runtime, ImagePath: string);
var
  Window: TOmDetForm;
begin
  Window := nil;
  try
    Application.CreateForm(TOmDetForm, Window);
    Window.Configure(CVLibrary, Bundle, Runtime, ImagePath);
    Application.Run;
    Window.CloseSession;
    RequireCpu(Window.SessionError = '', Window.SessionError);
  finally
    Window.Free;
  end;
end;

procedure Run;
var
  CVLibrary, Bundle, Runtime, ImagePath, Report: string;
begin
  CVLibrary := Option('--opencv', PreparedPath('opencv',
    FindOmDetPath('crosspascal-opencv\bin\crosscv.dll', False)));
  Bundle := Option('--bundle', PreparedPath('model'));
  Runtime := Option('--runtime', PreparedPath('runtime'));
  ImagePath := Option('--image', PreparedPath('image'));
  RequireCpu((CVLibrary <> '') and FileExists(CVLibrary), 'OpenCV was not found. Run Prepare.cmd first.');
  RequireCpu(CVInitialize(CVLibrary), 'OpenCV initialization failed');
  Report := '';
  try
    RequireCpu(CVLibraryAbiVersion = CVSupportedAbiVersion,
      'The OpenCV runtime and Pascal bindings have different ABI versions.');
    Application.Initialize;
    {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
    Application.Title := 'CrossPascal OmDet-Turbo';
    if Flag('--recorded') then
      Report := RecordedResult(CVLibrary, Bundle, Runtime, ImagePath)
    else
      RunWindow(CVLibrary, Bundle, Runtime, ImagePath);
  finally
    RequireCpu(CVLiveObjects = 0, 'Image objects remain alive before OpenCV finalization');
    RequireCpu(CVFinalize, 'OpenCV release failed');
  end;
  if Flag('--recorded') then SaveOmDetReport(Option('--report', ''), Report);
end;

procedure Failure(const Error: Exception);
var
  Root: TJSONObject;
  Path: string;
begin
  Path := Option('--report', '');
  if (Path = '') or FileExists(Path) then Exit;
  Root := TJSONObject.Create;
  try
    Root.AddPair('schema', 'crosspascal.omdet-result.v1');
    Root.AddPair('status', 'FAILED');
    Root.AddPair('error_class', Error.ClassName);
    Root.AddPair('error', Error.Message);
    if OmDetCleanupDiagnostic <> '' then Root.AddPair('cleanup_detail', OmDetCleanupDiagnostic);
    SaveOmDetReport(Path, Root.ToJSON);
  finally
    Root.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      ExitCode := 1;
      if Flag('--recorded') then
      begin
        OutputDebugStringW(PWideChar(UnicodeString(E.Message)));
        try
          Failure(E);
        except
          on ReportError:
            Exception do OutputDebugStringW(PWideChar(UnicodeString(ReportError.Message)));
        end;
      end
      else
        {$IFDEF FPC}Application.ShowException(E);{$ELSE}
        Application.MessageBox(PChar(E.Message), 'OmDet-Turbo', MB_OK or MB_ICONERROR);{$ENDIF}
    end;
  end;
end.
