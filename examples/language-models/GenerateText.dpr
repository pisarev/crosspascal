program GenerateText;

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
    Model.Load(ExampleArgument(1), ExampleArgument(2));
    Options := DefaultLanguageOptions;
    PrintAnswer(Model.Generate(ExamplePrompt('Say hello in English.', 'Describe this image.'),
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
  FinishExample;
end.
