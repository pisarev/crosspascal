program QwenChat;

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}

{$APPTYPE GUI}
{$IFNDEF TVM_LAZY_INIT}
  {$MESSAGE ERROR 'Open QwenChat project; TVM_LAZY_INIT must be a project-wide define'}
{$ENDIF}

uses
  {$IFDEF FPC}Interfaces, Windows, SysUtils, Forms, {$ELSE}
  Winapi.Windows, System.SysUtils, Vcl.Forms, {$ENDIF}
  CrossPascal.Json, QwenCuda, QwenChat.Main in 'QwenChat.Main.pas';

function RecordedMode: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if ParamStr(I) = '--recorded' then
      Exit(True);
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

procedure RunRecorded;
var
  ResultValue: TQwenCudaResult;
  MaxTokens: Integer;
  ReportPath, Value: string;
begin
  ReportPath := OptionValue('--report');
  if ReportPath = '' then
    raise Exception.Create('Recorded mode requires --report=<new JSON file>.');
  if FileExists(ReportPath) then
    raise Exception.Create('The recorded result file must not already exist.');
  Value := OptionValue('--max-new-tokens');
  if Value = '' then
    MaxTokens := QwenDefaultMaxNewTokens
  else if not TryStrToInt(Value, MaxTokens) then
      raise Exception.Create('Invalid --max-new-tokens value.');
  ResultValue := RunQwenCuda(OptionValue('--bundle'), OptionValue('--runtime'),
    OptionValue('--prompt'), MaxTokens);
  WriteNewReport(ReportPath, QwenResultJSON(ResultValue));
end;

procedure RecordFailure(const Error: Exception);
var
  ReportPath: string;
  Obj: TJSONObject;
begin
  ReportPath := OptionValue('--report');
  if (ReportPath = '') or FileExists(ReportPath) then
    Exit;
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('schema', 'crosspascal-qwen-cuda-run-v1');
    Obj.AddPair('status', 'FAILED');
    Obj.AddPair('error_class', Error.ClassName);
    Obj.AddPair('error', Error.Message);
    Obj.AddPair('acceptance_claim', JSONBoolean(False));
    WriteNewReport(ReportPath, Obj.ToJSON);
  finally
    Obj.Free;
  end;
end;

begin
  try
    if RecordedMode then
      RunRecorded
    else begin
      Application.Initialize;
      {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
      Application.CreateForm(TQwenChatForm, QwenChatForm);
      Application.Run;
    end;
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
            OutputDebugStringW(PWideChar('Cannot write failure report: ' + ReportError.Message));
        end;
      end
      else
        Application.ShowException(E);
    end;
  end;
end.
