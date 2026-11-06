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
begin
  RequireArguments(False);
  Output := TConsoleOutput.Create;
  Model := TLanguageModel.Create;
  try
    Model.OnStatus := Output.Status;
    Model.Load(ParamStr(1), ParamStr(2));
    Options := DefaultLanguageOptions;
    PrintAnswer(Model.Generate('Say hello in English.', Options, []));
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
