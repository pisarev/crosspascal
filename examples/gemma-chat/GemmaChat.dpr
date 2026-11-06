program GemmaChat;

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}
{$APPTYPE GUI}

uses
  {$IFDEF FPC}Interfaces, Forms{$ELSE}Vcl.Forms{$ENDIF},
  GemmaChat.Main in 'GemmaChat.Main.pas';

begin
  Application.Initialize;
  {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
  Application.CreateForm(TGemmaChatForm, GemmaChatForm);
  Application.Run;
end.
