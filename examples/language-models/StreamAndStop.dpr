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
begin
  RequireArguments(False);
  Output := TConsoleOutput.Create;
  Model := TLanguageModel.Create;
  try
    Model.OnStatus := Output.Status;
    Model.Load(ParamStr(1), ParamStr(2));
    Model.OnText := Output.Text;
    Model.ShouldStop := Output.StopRequested;
    ConsoleWriteLine('Hold Escape to stop generation.');
    Options := DefaultLanguageOptions;
    Model.Generate('Explain how stars form.', Options, []);
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
end.
