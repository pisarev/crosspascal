program MarkerLite;

uses
  {$IFDEF FPC}
  Windows, SysUtils, Interfaces, Forms,
  {$ELSE}
  Winapi.Windows, System.SysUtils, Vcl.Forms,
  {$ENDIF}
  OpenCV,
  MarkerLiteForm in 'MarkerLiteForm.pas';

{$IFDEF FPC}
function SetDllDirectoryW(PathName: PWideChar): BOOL; stdcall; external 'kernel32.dll';
{$ENDIF}

procedure Run;
var
  RuntimeDirectory: string;
  MainWindow: TMarkerLiteForm;
begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'CrossPascal MarkerLite';
  RuntimeDirectory := ExpandFileName(ExtractFilePath(ParamStr(0)) +
    {$IFDEF FPC}'..\' +{$ENDIF}'..\..\..\..\crosspascal-opencv\bin');
  if not FileExists(IncludeTrailingPathDelimiter(RuntimeDirectory) + 'crosscv.dll') then
    raise Exception.Create('The supplied OpenCV runtime was not found in ' + RuntimeDirectory);
  if not SetDllDirectoryW(PWideChar(UnicodeString(RuntimeDirectory))) then
    RaiseLastOSError;
  try
    if not CVInitialize(IncludeTrailingPathDelimiter(RuntimeDirectory) + 'crosscv.dll') then
      raise Exception.Create('Cannot load the OpenCV runtime: ' + CV.Module.Error);
    try
      if CVLibraryAbiVersion <> CVSupportedAbiVersion then
        raise Exception.Create('The OpenCV runtime and Pascal bindings have different ABI versions.');
      MainWindow := nil;
      try
        Application.CreateForm(TMarkerLiteForm, MainWindow);
        Application.Run;
      finally
        FreeAndNil(MainWindow);
      end;
    finally
      if not CVFinalize then
        raise Exception.Create('Cannot release the OpenCV runtime: ' + CV.Module.Error);
    end;
  finally
    SetDllDirectoryW(nil);
  end;
end;

begin
  ExitCode := 0;
  try
    Run;
  except
    on E: Exception do
    begin
      Application.MessageBox(PChar(E.Message), 'MarkerLite', MB_OK or MB_ICONERROR);
      ExitCode := 1;
    end;
  end;
end.
