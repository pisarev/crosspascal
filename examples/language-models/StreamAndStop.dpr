program StreamAndStop;

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
    Model.OnText := Output.Text;
    Model.ShouldStop := Output.StopRequested;
    ConsoleWriteLine('Hold Escape to stop generation.');
    Options := DefaultLanguageOptions;
    Model.Generate(ExamplePrompt('Explain how stars form.', 'Explain what you can see in this image.'),
      Options, Images);
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
