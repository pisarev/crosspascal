{ ************************************************************************** }
{                                                                            }
{ CrossPascalConvert                                                         }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                     }
{                                                                            }
{ ************************************************************************** }

program CrossPascalConvert;

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}
{$APPTYPE GUI}

uses
  {$IFDEF FPC}
  Windows, SysUtils;
  {$ELSE}
  Winapi.Windows, System.SysUtils;
  {$ENDIF}

function ExecutableFolder: UnicodeString;
var
  Buffer: array[0..32767] of WideChar;
  Count: DWORD;
begin
  Count := GetModuleFileNameW(0, @Buffer[0], Length(Buffer));
  if Count = 0 then
    RaiseLastOSError;
  if Count >= Length(Buffer) then
    raise Exception.Create('The application path is too long.');
  SetString(Result, PWideChar(@Buffer[0]), Count);
  Result := ExtractFilePath(Result);
end;

function IsFile(const FileName: UnicodeString): Boolean;
var
  Attributes: DWORD;
begin
  Attributes := GetFileAttributesW(PWideChar(FileName));
  Result := (Attributes <> INVALID_FILE_ATTRIBUTES) and
    ((Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

procedure OpenConverter;
var
  BundleRoot, PythonPath, CommandLine: UnicodeString;
  Startup: TStartupInfoW;
  ProcessInfo: TProcessInformation;
  WaitResult, ChildExit: DWORD;
begin
  BundleRoot := ExecutableFolder;
  PythonPath := BundleRoot + 'runtime\python\pythonw.exe';
  if not IsFile(PythonPath) then
    raise Exception.Create(
      'The application runtime is missing.' + sLineBreak + 'Extract the complete CrossPascal SDK and start CrossPascalConvert.exe from its top-level folder.'
    );
  if not IsFile(BundleRoot + 'crosspascal-convert\source\pascalvision_convert\wizard_entry.py') then
    raise Exception.Create(
      'The converter source folder is missing.' + sLineBreak + 'Keep crosspascal-convert and runtime beside CrossPascalConvert.exe.'
    );
  CommandLine := '"' + PythonPath + '" -B -m pascalvision_convert.wizard_entry';
  UniqueString(CommandLine);
  FillChar(Startup, SizeOf(Startup), 0);
  Startup.cb := SizeOf(Startup);
  Startup.dwFlags := STARTF_USESHOWWINDOW;
  Startup.wShowWindow := SW_HIDE;
  FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
  if not CreateProcessW(
    PWideChar(PythonPath),
    PWideChar(CommandLine),
    nil,
    nil,
    False,
    CREATE_UNICODE_ENVIRONMENT,
    nil,
    PWideChar(BundleRoot),
    Startup,
    ProcessInfo
  ) then
      RaiseLastOSError;
  try
    WaitResult := WaitForSingleObject(ProcessInfo.hProcess, 1500);
    if WaitResult = WAIT_FAILED then
      RaiseLastOSError;
    if WaitResult = WAIT_OBJECT_0 then
    begin
      if not GetExitCodeProcess(ProcessInfo.hProcess, ChildExit) then
        RaiseLastOSError;
      if ChildExit <> 0 then
        raise Exception.CreateFmt(
          'The converter could not start (exit %u).' + sLineBreak + 'See the startup message and the logs in Local AppData\CrossPascal\Convert\logs.',
          [ChildExit]
        );
    end;
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

begin
  ExitCode := 0;
  try
    OpenConverter;
  except
    on E: Exception do
    begin
      MessageBoxW(
        0,
        PWideChar(UnicodeString(E.Message)),
        'CrossPascal Converter',
        MB_OK or MB_ICONERROR
      );
      ExitCode := 2;
    end;
  end;
end.
