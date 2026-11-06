program ImagePrompt;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF},
  QwenCuda, LanguageModel, ExampleSupport;

procedure Run;
var
  Model: TLanguageModel;
  Output: TConsoleOutput;
  Options: TLanguageOptions;
  Info: TLanguageCapabilities;
begin
  RequireArguments(True);
  Output := TConsoleOutput.Create;
  Model := TLanguageModel.Create;
  try
    Model.OnStatus := Output.Status;
    Info := TLanguageModel.Inspect(ParamStr(1));
    if not Info.SupportsImages then
      raise Exception.Create(Info.ImageExplanation);
    Model.Load(ParamStr(1), ParamStr(2));
    Options := DefaultLanguageOptions;
    PrintAnswer(Model.Generate('Describe this image.', Options, [ParamStr(3)]));
    Model.Unload;
  finally
    Model.Free;
    Output.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      ConsoleWriteLine(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
