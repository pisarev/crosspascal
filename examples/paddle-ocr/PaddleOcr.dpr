program PaddleOcr;
{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE GUI}
{$IFNDEF TVM_LAZY_INIT}
  {$MESSAGE ERROR 'Open the PaddleOcr project; TVM_LAZY_INIT must be a project-wide define'}
{$ENDIF}
uses
  {$IFDEF FPC}Interfaces, Windows, SysUtils, Forms, {$ELSE}
  Winapi.Windows, System.SysUtils, Vcl.Forms, {$ENDIF}
  CrossPascal.Json, CrossVision.Mat, OpenCV, ExampleDefaults, PaddleOcr.Run in 'PaddleOcr.Run.pas',
  PaddleOcr.Main in 'PaddleOcr.Main.pas';

function Option(const Name, Default: string): string;
var
  I: Integer;
  Prefix: string;
begin
  Result := Default;
  Prefix := Name + '=';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, Length(Prefix)) = Prefix then
      Exit(Copy(ParamStr(I), Length(Prefix) + 1, MaxInt));
end;

function Recorded: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do if ParamStr(I) = '--recorded' then Exit(True);
end;

procedure Run;
var
  CVLibrary, Runtime, Clipper, Digest, Report: string;
  Image: IMat;
  Value: TPaddleResult;
  MainWindow: TPaddleOcrForm;
begin
  CVLibrary := Option('--opencv', FindPaddlePath('crosspascal-opencv\bin\crosscv.dll', False));
  if (CVLibrary = '') or not FileExists(CVLibrary) then
    raise Exception.Create('OpenCV was not found. Run Prepare.cmd in the example folder.');
  if not CVInitialize(CVLibrary) then raise Exception.Create('OpenCV: ' + CV.Module.Error);
  try
    if CVLibraryAbiVersion <> CVSupportedAbiVersion then
      raise Exception.Create('The OpenCV runtime and Pascal bindings have different ABI versions.');
    if Recorded then
    begin
      Report := Option('--report', '');
      if (Report = '') or FileExists(Report) then
        raise Exception.Create('Recorded mode requires --report=<new JSON file>.');
      Runtime := Option('--runtime', PreparedPath('runtime',
        FindPaddlePath('crosspascal-tvm\runtime\windows-x64-cuda', True)));
      Clipper := Option('--clipper', PreparedPath('clipper',
        FindPaddlePath('crosspascal-tvm\runtime\paddleocr\ppocr_db_jt_round.dll', False)));
      Image := nil;
      try
        Image := ReadPaddleImage(Option('--image', PreparedPath('image')), CVLibrary, Digest);
        Value := RunPaddle(Option('--detector', PreparedPath('detector')),
          Option('--recognizer', PreparedPath('recognizer')), Runtime, Clipper, Digest, Image);
        SavePaddleText(Report, Value.JSON);
      finally
        Image := nil;
      end;
    end
    else begin
      Application.Initialize;
      {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
      Application.Title := 'CrossPascal PaddleOCR';
      MainWindow := nil;
      try
        Application.CreateForm(TPaddleOcrForm, MainWindow);
        Application.Run;
      finally
        FreeAndNil(MainWindow);
      end;
    end;
  finally
    if not CVFinalize then raise Exception.Create('OpenCV release failed: ' + CV.Module.Error);
  end;
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
    Root.AddPair('schema', 'crosspascal.paddleocr-result.v1');
    Root.AddPair('status', 'FAILED');
    Root.AddPair('error_class', Error.ClassName);
    Root.AddPair('error', Error.Message);
    SavePaddleText(Path, Root.ToJSON);
  finally
    Root.Free;
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
      if Recorded then
      begin
        OutputDebugStringW(PWideChar(E.Message));
        try
          Failure(E);
          except
            on ReportError: Exception do OutputDebugStringW(PWideChar(ReportError.Message));
          end;
      end
      else
        {$IFDEF FPC}Application.ShowException(E);{$ELSE}
        Application.MessageBox(PChar(E.Message), 'PaddleOCR', MB_OK or MB_ICONERROR);{$ENDIF}
    end;
    end;
end.
