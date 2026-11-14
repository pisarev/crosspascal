program BiRefNet;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE GUI}
{$IFNDEF TVM_LAZY_INIT}
  {$MESSAGE ERROR 'Open the BiRefNet project; TVM_LAZY_INIT must be a project-wide define'}
{$ENDIF}

uses
  {$IFDEF FPC}Interfaces, Windows, SysUtils, Forms, {$ELSE}
  Winapi.Windows, System.SysUtils, Vcl.Forms, {$ENDIF}
  CrossPascal.Json, CrossVision.Mat, OpenCV, OpenCVTypes, OpenCVConsts, ExampleDefaults,
  TVM.CpuGraph, BiRefNet.Run in 'BiRefNet.Run.pas', BiRefNet.Main in 'BiRefNet.Main.pas';

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

function RecordedResult(const CVLibrary: string): string;
var
  Image, ByteMask: IMat;
  Value: TBiRefResult;
  Runtime, Digest, CutoutPath, MaskPath, ReportPath: string;
begin
  ReportPath := Option('--report', '');
  RequireCpu((ReportPath <> '') and not FileExists(ReportPath),
    'Recorded mode requires --report=<new JSON file>.');
  RequireCpu(SameText(ExtractFileExt(ReportPath), '.json'), 'Choose a JSON report file.');
  CutoutPath := Option('--cutout', ChangeFileExt(ReportPath, '.cutout.png'));
  MaskPath := Option('--mask', ChangeFileExt(ReportPath, '.mask.png'));
  RequireCpu(
    SameText(ExtractFileExt(CutoutPath), '.png') and SameText(ExtractFileExt(MaskPath), '.png') and not SameText(ExpandFileName(CutoutPath), ExpandFileName(MaskPath)) and not FileExists(CutoutPath) and not FileExists(MaskPath),
    'Choose separate new PNG output files.'
  );
  Runtime := Option('--runtime', PreparedPath('runtime',
    FindBiRefPath('crosspascal-tvm\runtime\windows-x64-cuda', True)));
  Image := ReadBiRefImage(Option('--image', PreparedPath('image')), CVLibrary, Digest);
  Value := RunBiRef(Option('--bundle', PreparedPath('model')), Runtime, Digest, Image);
  ByteMask := Value.Mask.ConvertTo(CV_MAKETYPE(CV_8U, 1), 255, 0);
  SaveBiRefPNG(CutoutPath, Value.Cutout);
  SaveBiRefPNG(MaskPath, ByteMask);
  Result := Value.JSON;
end;

procedure RunWindow;
var
  MainWindow: TBiRefNetForm;
begin
  Application.Initialize;
  {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
  Application.Title := 'CrossPascal BiRefNet';
  MainWindow := nil;
  try
    Application.CreateForm(TBiRefNetForm, MainWindow);
    Application.Run;
  finally
    FreeAndNil(MainWindow);
  end;
end;

procedure Run;
var
  CVLibrary, Report: string;
begin
  CVLibrary := Option('--opencv', FindBiRefPath('crosspascal-opencv\bin\crosscv.dll', False));
  RequireCpu((CVLibrary <> '') and FileExists(CVLibrary),
    'OpenCV was not found. Run Prepare.cmd in the example folder.');
  RequireCpu(CVInitialize(CVLibrary), 'OpenCV initialization failed');
  Report := '';
  try
    RequireCpu(CVLibraryAbiVersion = CVSupportedAbiVersion,
      'The OpenCV runtime and Pascal bindings have different ABI versions.');
    if Recorded then
      Report := RecordedResult(CVLibrary)
    else
      RunWindow;
  finally
    RequireCpu(CVLiveObjects = 0, 'Image objects remain alive before OpenCV finalization');
    RequireCpu(CVFinalize, 'OpenCV release failed');
  end;
  if Recorded then SaveBiRefReport(Option('--report', ''), Report);
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
    Root.AddPair('schema', 'crosspascal.birefnet-result.v1');
    Root.AddPair('status', 'FAILED');
    Root.AddPair('error_class', Error.ClassName);
    Root.AddPair('error', Error.Message);
    SaveBiRefReport(Path, Root.ToJSON);
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
        Application.MessageBox(PChar(E.Message), 'BiRefNet', MB_OK or MB_ICONERROR);{$ENDIF}
    end;
  end;
end.
