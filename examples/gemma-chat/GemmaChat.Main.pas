unit GemmaChat.Main;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Classes{$ELSE}System.Classes{$ENDIF}, LanguageChat.Form;

type
  TGemmaChatForm = class(TLanguageChatForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  GemmaChatForm: TGemmaChatForm;

implementation

constructor TGemmaChatForm.Create(AOwner: TComponent);
begin
  inherited;
  SetDemoTitle('CrossPascal Gemma Chat');
end;

end.
