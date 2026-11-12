{ ************************************************************************** }
{                                                                            }
{ CrossPascalConvert                                                         }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                                             }
{                                                                            }
{ ************************************************************************** }

program CrossPascalConvert;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE GUI}

uses
  {$IFDEF FPC}Interfaces, Forms, Windows, SysUtils{$ELSE}Vcl.Forms, Winapi.Windows, System.SysUtils{$ENDIF},
  CrossPascalConvert.Form in 'CrossPascalConvert.Form.pas',
  CrossPascalConvert.Native in 'CrossPascalConvert.Native.pas';

function SelectedProfile(const Name: string): TConverterProfile;
var
  Profile: TConverterProfile;
begin
  for Profile := Low(TConverterProfile) to High(TConverterProfile) do
    if SameText(Name, ProfileIDs[Profile]) then Exit(Profile);
  raise Exception.Create('Unknown conversion profile: ' + Name);
end;

procedure BuildFromCommandLine;
var
  Command: TConversionCommand;
  Process: THandle;
  Status: DWORD;
  Projector, Log: string;
begin
  if (ParamStr(1) <> '--build') or (ParamCount <> 8) then
    raise Exception.Create('Usage: CrossPascalConvert --build profile source destination projector-or-- context prefill architecture-or--');
  Projector := ParamStr(5);
  if Projector = '-' then Projector := '';
  Command := PrepareConversion(ExecutableFolder, ParamStr(3), Projector, ParamStr(4), ParamStr(8),
    SelectedProfile(ParamStr(2)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)));
  Process := StartConversion(Command, Log);
  try
    if WaitForSingleObject(Process, INFINITE) <> WAIT_OBJECT_0 then RaiseLastOSError;
    if not GetExitCodeProcess(Process, Status) then RaiseLastOSError;
    ExitCode := Status;
  finally
    CloseHandle(Process);
  end;
end;

begin
  try
    if ParamCount > 0 then
      BuildFromCommandLine
    else begin
      Application.Initialize;
      {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
      Application.CreateForm(TConverterForm, ConverterForm);
      Application.Run;
    end;
  except
    on E: Exception do
    begin
      if ParamCount = 0 then
        MessageBoxW(0, PWideChar(UnicodeString(E.Message)), 'CrossPascal Converter', MB_OK or MB_ICONERROR);
      ExitCode := 2;
    end;
  end;
end.
