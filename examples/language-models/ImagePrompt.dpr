program ImagePrompt;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}, QwenCuda, LanguageModel, ExampleSupport;

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
    Info := TLanguageModel.Inspect(ExampleArgument(1));
    if not Info.SupportsImages then
      raise Exception.Create(Info.ImageExplanation);
    Model.Load(ExampleArgument(1), ExampleArgument(2));
    Model.OnText := Output.Text;
    Model.ShouldStop := Output.StopRequested;
    ConsoleWriteLine('Hold Escape to stop generation.');
    Options := DefaultLanguageOptions;
    Options.Sampling := qsGreedy;
    Model.Generate('Describe the main object in this image in one sentence.', Options, [ExampleArgument(3)]);
    ConsoleWriteLine('');
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
  FinishExample;
end.
