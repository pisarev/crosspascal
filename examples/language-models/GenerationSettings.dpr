program GenerationSettings;

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
  Images: TExampleImages;
begin
  RequireArguments(False);
  Images := ExampleImages;
  Output := TConsoleOutput.Create;
  Model := TLanguageModel.Create;
  try
    Model.OnStatus := Output.Status;
    Model.Load(ParamStr(1), ParamStr(2));
    Options := DefaultLanguageOptions;
    Options.MaxNewTokens := 0;
    Options.Sampling := qsSample;
    Options.Temperature := 0.7;
    Options.TopP := 0.9;
    Options.TopK := 40;
    Options.RepetitionPenalty := 1.1;
    Options.Seed := 42;
    Options.Effort := qeFullContext;
    Options.SystemPrompt := 'Answer clearly and briefly.';
    Options.PlainCompletion := False;
    PrintAnswer(Model.Generate(ExamplePrompt('What is a black hole?', 'Describe the important details in this image.'),
      Options, Images));
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
