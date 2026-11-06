unit QwenChat.Main;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Classes{$ELSE}System.Classes{$ENDIF}, LanguageChat.Form;

type
  TQwenChatForm = class(TLanguageChatForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  QwenChatForm: TQwenChatForm;

implementation

constructor TQwenChatForm.Create(AOwner: TComponent);
begin
  inherited;
  SetDemoTitle('CrossPascal Qwen Chat');
end;

end.
