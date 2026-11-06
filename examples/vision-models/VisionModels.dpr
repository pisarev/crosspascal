program VisionModels;

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}

{$APPTYPE GUI}
{$IFNDEF TVM_LAZY_INIT}
  {$MESSAGE ERROR 'Open VisionModels project; TVM_LAZY_INIT must be a project-wide define'}
{$ENDIF}

uses
  {$IFDEF FPC}Interfaces, Windows, SysUtils, Forms, {$ELSE}
  Winapi.Windows, System.SysUtils, Vcl.Forms, {$ENDIF}
  CrossPascal.Json, OpenCV, CrossVision.Mat, CrossVision.ML.CpuVision,
  VisionModels.Main in 'VisionModels.Main.pas';

{$IFDEF FPC}
function SetDllDirectoryW(PathName: PWideChar): BOOL; stdcall; external 'kernel32.dll';
{$ENDIF}

function RecordedMode: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if ParamStr(I) = '--recorded' then Exit(True);
end;

function OptionValue(const Name: string): string;
var
  I: Integer;
  Prefix: string;
begin
  Result := '';
  Prefix := Name + '=';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, Length(Prefix)) = Prefix then
      Exit(Copy(ParamStr(I), Length(Prefix) + 1, MaxInt));
end;

function RunRecorded: string;
var
  Profiles: TArray<TCpuVisionProfile>;
  Profile: TCpuVisionProfile;
  Image: IMat;
  Value: TCpuVisionResult;
  CatalogPath, RuntimePath, ImageHash, ReportPath: string;
  Found: Boolean;
begin
  ReportPath := OptionValue('--report');
  if (ReportPath = '') or FileExists(ReportPath) then
    raise Exception.Create('Recorded mode requires --report=<new JSON file>.');
  CatalogPath := OptionValue('--catalog');
  if CatalogPath = '' then CatalogPath := DefaultCatalogPath;
  RuntimePath := OptionValue('--runtime');
  if RuntimePath = '' then RuntimePath := DefaultRuntimeDirectory;
  Profiles := LoadCpuVisionProfiles(CatalogPath);
  Found := False;
  for Profile in Profiles do
    if Profile.ID = OptionValue('--profile') then
    begin
      Found := True;
      Break;
    end;
  if not Found then raise Exception.Create('Select one of the five named --profile values.');
  Image := nil;
  try
    Image := DecodeVisionImage(OptionValue('--image'), ImageHash);
    Value := RunCpuVision(Profile, OptionValue('--bundle'), RuntimePath,
      OptionValue('--image'), ImageHash, Image, nil, OptionValue('--audit-directory'));
    Result := Value.JSONText;
  finally
    Image := nil;
  end;
end;

procedure Run;
var
  OpenCVDirectory, JSONText: string;
  MainWindow: TVisionModelsForm;
begin
  OpenCVDirectory := OptionValue('--opencv');
  if OpenCVDirectory = '' then
    OpenCVDirectory := FindDeliveredPath('crosspascal-opencv\bin', True);
  OpenCVDirectory := ExpandFileName(OpenCVDirectory);
  if not FileExists(IncludeTrailingPathDelimiter(OpenCVDirectory) + 'crosscv.dll') then
    raise Exception.Create('The supplied OpenCV runtime was not found. Keep the sibling repositories together.');
  if not SetDllDirectoryW(PWideChar(OpenCVDirectory)) then RaiseLastOSError;
  try
    if not CVInitialize(IncludeTrailingPathDelimiter(OpenCVDirectory) + 'crosscv.dll') then
      raise Exception.Create('Cannot load the OpenCV runtime: ' + CV.Module.Error);
    try
      if CVLibraryAbiVersion <> CVSupportedAbiVersion then
        raise Exception.Create('The OpenCV runtime and Pascal bindings have different ABI versions.');
      if RecordedMode then
        JSONText := RunRecorded
      else begin
        Application.Initialize;
        {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
        Application.Title := 'CrossPascal CPU Vision Models';
        MainWindow := nil;
        try
          Application.CreateForm(TVisionModelsForm, MainWindow);
          MainWindow.AuditDirectory := OptionValue('--audit-directory');
          Application.Run;
        finally
          FreeAndNil(MainWindow);
        end;
      end;
    finally
      if not CVFinalize then
        raise Exception.Create('Cannot release the OpenCV runtime: ' + CV.Module.Error);
    end;
  finally
    SetDllDirectoryW(nil);
  end;
  if RecordedMode then WriteCpuVisionReport(OptionValue('--report'), JSONText);
end;

procedure RecordFailure(const Error: Exception);
var
  Path: string;
  Obj: TJSONObject;
begin
  Path := OptionValue('--report');
  if (Path = '') or FileExists(Path) then Exit;
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('schema', 'crosspascal.cpu-vision-result.v1');
    Obj.AddPair('status', 'FAILED');
    Obj.AddPair('error_class', Error.ClassName);
    Obj.AddPair('error', Error.Message);
    Obj.AddPair('release_acceptance', JSONBoolean(False));
    WriteCpuVisionReport(Path, Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

begin
  ExitCode := 0;
  try
    Run;
  except
    on E: Exception do
    begin
      ExitCode := 1;
      if RecordedMode then
      begin
        OutputDebugStringW(PWideChar(E.ClassName + ': ' + E.Message));
        try
          RecordFailure(E);
        except
          on ReportError: Exception do
            OutputDebugStringW(PWideChar('Cannot save failure result: ' + ReportError.Message));
        end;
      end
      else
        {$IFDEF FPC}Application.ShowException(E);{$ELSE}
        Application.MessageBox(PChar(E.Message), 'VisionModels', MB_OK or MB_ICONERROR);{$ENDIF}
    end;
  end;
end.
