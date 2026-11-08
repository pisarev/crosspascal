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
function ExampleImages: TExampleImages;
function ExamplePrompt(const TextPrompt, ImagePrompt: string): string;
procedure PrintAnswer(const Report: string);
procedure ConsoleWrite(const Text: string);
procedure ConsoleWriteLine(const Text: string);

implementation

uses CrossPascal.Json;

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

procedure RequireArguments(const ImageRequired: Boolean);
begin
  SetConsoleOutputCP(CP_UTF8);
  if (ParamCount > 3) then
    raise Exception.Create('Too many arguments: expected bundle, SDK folder and an optional image.');
  if (ParamCount < 2) or (ImageRequired and (ParamCount < 3)) then
    raise Exception.Create('Arguments: "converted bundle" "SDK root" ["image.png"]. ' +
      'Use the supplied SDK root, not the original model directory.');
end;

function ExampleImages: TExampleImages;
var
  Info: TLanguageCapabilities;
begin
  SetLength(Result, 0);
  if ParamCount < 3 then Exit;
  if not FileExists(ParamStr(3)) then
    raise Exception.Create('Image file was not found: ' + ParamStr(3));
  Info := TLanguageModel.Inspect(ParamStr(1));
  if not Info.SupportsImages then
    raise Exception.Create(Info.ImageExplanation);
  SetLength(Result, 1);
  Result[0] := ExpandFileName(ParamStr(3));
end;

function ExamplePrompt(const TextPrompt, ImagePrompt: string): string;
begin
  if ParamCount >= 3 then
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
