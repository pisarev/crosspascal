unit ExampleSupport;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils, Windows{$ELSE}System.SysUtils, Winapi.Windows{$ENDIF},
  LanguageModel;

type
  TExampleImages = array of string;

  TConsoleOutput = class
  private
    FPrevious: string;
  public
    procedure Status(const Text: string);
    procedure Text(const Value: string);
    function StopRequested: Boolean;
  end;

procedure RequireArguments(const ImageRequired: Boolean = False);
function ExampleArgument(const Index: Integer): string;
procedure FinishExample;
function ExampleImages: TExampleImages;
function ExamplePrompt(const TextPrompt, ImagePrompt: string): string;
procedure PrintAnswer(const Report: string);
procedure ConsoleWrite(const Text: string);
procedure ConsoleWriteLine(const Text: string);

implementation

uses CrossPascal.Json, ExampleDefaults;

procedure ConsoleWrite(const Text: string);
var
  Bytes: UTF8String;
  Offset, Written: DWORD;
begin
  Bytes := UTF8Encode(Text);
  Offset := 0;
  while Offset < DWORD(Length(Bytes)) do
  begin
    if not WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), Bytes[Offset + 1],
      DWORD(Length(Bytes)) - Offset, Written, nil) then RaiseLastOSError;
    if Written = 0 then raise Exception.Create('Could not write console output');
    Inc(Offset, Written);
  end;
end;

procedure ConsoleWriteLine(const Text: string);
begin
  ConsoleWrite(Text + #13#10);
end;

function ExampleArgument(const Index: Integer): string;
begin
  if ParamCount > 0 then Exit(ParamStr(Index));
  case Index of
    1: Result := PreparedPath('model');
    2: Result := PreparedPath('sdk');
    3: Result := PreparedPath('image');
  else
    Result := '';
  end;
end;

procedure FinishExample;
begin
  if (ParamCount = 0) and HasPreparedExample and
    ({$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}.GetEnvironmentVariable('CROSSPASCAL_EXAMPLE_NO_PAUSE') <> '1') then
    begin
      ConsoleWriteLine('Press Enter to close this example.');
      Readln;
    end;
end;

procedure RequireArguments(const ImageRequired: Boolean);
begin
  SetConsoleOutputCP(CP_UTF8);
  if (ParamCount > 3) then
    raise Exception.Create('Too many arguments: expected bundle, SDK folder and an optional image.');
  if ((ParamCount > 0) and (ParamCount < 2)) or (ExampleArgument(1) = '') or
    (ExampleArgument(2) = '') or (ImageRequired and (ExampleArgument(3) = '')) then
      raise Exception.Create('Arguments: "converted bundle" "SDK root" ["image.png"]. ' +
        'Use the supplied SDK root, not the original model directory.');
end;

function ExampleImages: TExampleImages;
var
  Info: TLanguageCapabilities;
begin
  SetLength(Result, 0);
  if ExampleArgument(3) = '' then Exit;
  if not FileExists(ExampleArgument(3)) then
    raise Exception.Create('Image file was not found: ' + ExampleArgument(3));
  Info := TLanguageModel.Inspect(ExampleArgument(1));
  if not Info.SupportsImages then
    raise Exception.Create(Info.ImageExplanation);
  SetLength(Result, 1);
  Result[0] := ExpandFileName(ExampleArgument(3));
end;

function ExamplePrompt(const TextPrompt, ImagePrompt: string): string;
begin
  if ExampleArgument(3) <> '' then
    Result := ImagePrompt
  else
    Result := TextPrompt;
end;

procedure TConsoleOutput.Status(const Text: string);
begin
  ConsoleWriteLine(Text);
end;

procedure TConsoleOutput.Text(const Value: string);
begin
  if Copy(Value, 1, Length(FPrevious)) = FPrevious then
    ConsoleWrite(Copy(Value, Length(FPrevious) + 1, MaxInt))
  else
    ConsoleWriteLine(Value);
  FPrevious := Value;
end;

function TConsoleOutput.StopRequested: Boolean;
begin
  Result := GetAsyncKeyState(VK_ESCAPE) < 0;
end;

procedure PrintAnswer(const Report: string);
var
  Value, Text: TJSONValue;
begin
  Value := ParseCrossJSON(Report);
  try
    if not (Value is TJSONObject) then raise Exception.Create('Invalid generation report');
    Text := TJSONObject(Value).GetValue('generated_text');
    if Text = nil then Text := TJSONObject(Value).GetValue('answer');
    if Text = nil then Text := TJSONObject(Value).GetValue('text');
    if Text = nil then
      ConsoleWriteLine(Report)
    else
      ConsoleWriteLine(JSONValueText(Text));
  finally
    Value.Free;
  end;
end;

end.
