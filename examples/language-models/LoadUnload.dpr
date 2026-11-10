program LoadUnload;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}, QwenCuda, LanguageModel, ExampleSupport;

procedure Run;
var
  Model: TLanguageModel;
  Output: TConsoleOutput;
  Info: TLanguageCapabilities;
begin
  RequireArguments(False);
  Output := TConsoleOutput.Create;
  Model := TLanguageModel.Create;
  try
    Model.OnStatus := Output.Status;
    Info := TLanguageModel.Inspect(ExampleArgument(1));
    ConsoleWriteLine('Bundle architecture: ' + Info.Architecture);
    ConsoleWriteLine('Image support: ' + BoolToStr(Info.SupportsImages, True));
    Model.Load(ExampleArgument(1), ExampleArgument(2));
    ConsoleWriteLine('Loaded architecture: ' + Model.Capabilities.Architecture);
    ConsoleWriteLine('Device: ' + Model.Capabilities.Device);
    ConsoleWriteLine('Context tokens: ' + IntToStr(Model.Capabilities.ContextTokens));
    Model.Unload;
    ConsoleWriteLine('Model unloaded.');
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
