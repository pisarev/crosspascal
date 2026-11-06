unit GemmaChat.Main;

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}

interface

uses
  {$IFDEF FPC}Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs{$ELSE}
  System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Dialogs{$ENDIF}, GemmaProcess, CrossPascal.Json;

type
  TGemmaChatForm = class(TForm)
  private
    FBundle: TEdit;
    FSDK: TEdit;
    FMaxTokens: TEdit;
    FPrompt: TMemo;
    FOutput: TMemo;
    FRun: TButton;
    FStop: TButton;
    FSave: TButton;
    FBundleBrowse: TButton;
    FSDKBrowse: TButton;
    FPlain: TCheckBox;
    FStatus: TLabel;
    FTimer: TTimer;
    FProcess: TGemmaProcess;
    FBusy: Boolean;
    FClosing: Boolean;
    FRuntimeClosed: Boolean;
    FLastJSON: string;
    FRuntimeRoot: string;
    FDiagnostic: string;
    procedure BrowseBundle(Sender: TObject);
    procedure BrowseSDK(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure HandleEvent(const Line: string);
    procedure SetBusy(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  GemmaChatForm: TGemmaChatForm;

implementation

uses
  {$IFDEF FPC}Windows{$ELSE}Winapi.Windows, Vcl.FileCtrl{$ENDIF};

function Field(const Obj: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Value := Obj.GetValue(Name);
  if Value = nil then
    Result := ''
  else
    Result := JSONValueText(Value);
end;

function ChooseDirectory(const Owner: TWinControl; const Title: string; var Path: string): Boolean;
{$IFDEF FPC}
var
  Dialog: TSelectDirectoryDialog;
{$ENDIF}
begin
  {$IFDEF FPC}
  Dialog := TSelectDirectoryDialog.Create(Owner);
  try
    Dialog.Title := UTF8Encode(Title);
    Dialog.InitialDir := UTF8Encode(Path);
    Result := Dialog.Execute;
    if Result then Path := UTF8Decode(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  {$ELSE}
  Result := SelectDirectory(Title, '', Path, [sdNewUI, sdNewFolder], Owner);
  {$ENDIF}
end;

constructor TGemmaChatForm.Create(AOwner: TComponent);

  function AddLabel(const CaptionText: string; const Y: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.Caption := CaptionText;
    Result.SetBounds(16, Y, 860, 22);
  end;

  function AddEdit(const Y, Width: Integer): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(16, Y, Width, 28);
    Result.Anchors := [akLeft, akTop, akRight];
  end;

  function AddButton(const CaptionText: string; const X, Y, Width: Integer;
    const Handler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.Caption := CaptionText;
    Result.SetBounds(X, Y, Width, 30);
    Result.OnClick := Handler;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal Gemma 3n CUDA';
  Position := poScreenCenter;
  ClientWidth := 900;
  ClientHeight := 650;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 600;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  OnCloseQuery := CheckClose;
  AddLabel('Converted Gemma 3n CUDA bundle (select the folder containing model.json)', 16);
  FBundle := AddEdit(40, 752);
  FBundleBrowse := AddButton('Browse...', 784, 40, 100, BrowseBundle);
  FBundleBrowse.Anchors := [akTop, akRight];
  AddLabel('SDK root (with the supplied Gemma runtime asset extracted)', 82);
  FSDK := AddEdit(106, 752);
  FSDK.Text := FindGemmaSDK;
  FSDKBrowse := AddButton('Browse...', 784, 106, 100, BrowseSDK);
  FSDKBrowse.Anchors := [akTop, akRight];
  AddLabel('Text input only. Native TVM CUDA W8A32; greedy decoding. No CPU fallback.', 148);
  AddLabel('Prompt (each request starts a new conversation; loaded model weights are reused)', 180);
  FPrompt := TMemo.Create(Self);
  FPrompt.Parent := Self;
  FPrompt.SetBounds(16, 206, 868, 100);
  FPrompt.Anchors := [akLeft, akTop, akRight];
  FPrompt.ScrollBars := ssVertical;
  FPrompt.Text := 'What is the capital of France? Answer with the city name only.';
  AddLabel('Max new tokens: 0 = automatic until EOS or bundle context; Stop ends generation.', 316);
  FMaxTokens := AddEdit(344, 100);
  FMaxTokens.Anchors := [akLeft, akTop];
  FMaxTokens.Text := '0';
  FRun := AddButton('Run on GPU', 132, 344, 132, RunClick);
  FStop := AddButton('Stop', 276, 344, 100, StopClick);
  FSave := AddButton('Save result...', 388, 344, 132, SaveClick);
  FPlain := TCheckBox.Create(Self);
  FPlain.Parent := Self;
  FPlain.Caption := 'Plain completion (base model)';
  FPlain.SetBounds(540, 344, 340, 30);
  FStatus := AddLabel('Choose a converted Gemma 3n CUDA bundle to begin.', 386);
  FOutput := TMemo.Create(Self);
  FOutput.Parent := Self;
  FOutput.SetBounds(16, 416, 868, 218);
  FOutput.Anchors := [akLeft, akTop, akRight, akBottom];
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssVertical;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 30;
  FTimer.OnTimer := Tick;
  SetBusy(False);
end;

destructor TGemmaChatForm.Destroy;
begin
  FTimer.Enabled := False;
  FProcess.Free;
  inherited;
end;

procedure TGemmaChatForm.SetBusy(const Value: Boolean);
begin
  FBusy := Value;
  FRun.Enabled := not Value and not FClosing;
  FStop.Enabled := Value and not FClosing;
  FSave.Enabled := not Value and (FLastJSON <> '') and not FClosing;
  FBundle.Enabled := not Value;
  FBundleBrowse.Enabled := not Value;
  FSDK.Enabled := not Value and (FProcess = nil);
  FSDKBrowse.Enabled := FSDK.Enabled;
  FMaxTokens.Enabled := not Value;
  FPlain.Enabled := not Value;
end;

procedure TGemmaChatForm.BrowseBundle(Sender: TObject);
var
  Path: string;
begin
  Path := FBundle.Text;
  if ChooseDirectory(Self, 'Select the converted Gemma 3n bundle', Path) then FBundle.Text := Path;
end;

procedure TGemmaChatForm.BrowseSDK(Sender: TObject);
var
  Path: string;
begin
  Path := FSDK.Text;
  if ChooseDirectory(Self, 'Select the SDK root', Path) then FSDK.Text := Path;
end;

procedure TGemmaChatForm.RunClick(Sender: TObject);
var
  Limit: Int64;
begin
  try
    if not TryStrToInt64(Trim(FMaxTokens.Text), Limit) or (Limit < 0) then
      raise Exception.Create('Max new tokens must be 0 or a positive integer.');
    if Trim(FPrompt.Text) = '' then raise Exception.Create('Enter a prompt.');
    if not FileExists(IncludeTrailingPathDelimiter(FBundle.Text) + 'model.json') then
      raise Exception.Create('Choose a converted bundle containing model.json.');
    if FProcess = nil then
    begin
      FProcess := TGemmaProcess.Create;
      try
        FRuntimeRoot := FSDK.Text;
        FProcess.Start(FRuntimeRoot);
      except
        FreeAndNil(FProcess);
        raise;
      end;
    end;
    FLastJSON := '';
    FDiagnostic := '';
    FOutput.Clear;
    FProcess.Generate(FBundle.Text, FPrompt.Text, Limit, FPlain.Checked);
    FStatus.Caption := 'Preparing the model and prompt...';
    SetBusy(True);
  except
    on E: Exception do FStatus.Caption := E.Message;
  end;
end;

procedure TGemmaChatForm.StopClick(Sender: TObject);
begin
  if FProcess <> nil then
  begin
    FProcess.Stop;
    FStop.Enabled := False;
    FStatus.Caption := 'Stopping after the current token...';
  end;
end;

procedure TGemmaChatForm.SaveClick(Sender: TObject);
var
  Dialog: TSaveDialog;
  Stream: TFileStream;
  Bytes: TBytes;
begin
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Filter := 'JSON result|*.json';
    Dialog.DefaultExt := 'json';
    Dialog.Options := Dialog.Options + [ofOverwritePrompt];
    if Dialog.Execute then
    begin
      Stream := TFileStream.Create(Dialog.FileName, fmCreate);
      try
        Bytes := TEncoding.UTF8.GetBytes(FLastJSON + sLineBreak);
        if Length(Bytes) > 0 then Stream.WriteBuffer(Bytes[0], Length(Bytes));
      finally
        Stream.Free;
      end;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TGemmaChatForm.HandleEvent(const Line: string);
var
  Value, Payload: TJSONValue;
  Obj, Report: TJSONObject;
  Kind, Reused: string;
begin
  if (Line = '') or (Line[1] <> '{') then
  begin
    FDiagnostic := Copy(FDiagnostic + Line + sLineBreak, 1, 16000);
    Exit;
  end;
  Value := ParseCrossJSON(Line);
  try
    if not (Value is TJSONObject) then raise Exception.Create('Invalid runtime response.');
    Obj := TJSONObject(Value);
    Kind := Field(Obj, 'event');
    if Kind = 'closed' then
    begin
      FRuntimeClosed := True;
      Exit;
    end;
    if (Kind = 'ready') then Exit;
    if (Kind <> 'fatal') and (Field(Obj, 'id') <> IntToStr(FProcess.RequestID)) then Exit;
    if Kind = 'text' then
    begin
      FOutput.Text := Field(Obj, 'text');
      FOutput.SelStart := Length(FOutput.Text);
    end
    else if Kind = 'status' then
        FStatus.Caption := Field(Obj, 'text')
      else if Kind = 'loaded' then
        begin
          Reused := 'Loaded model';
          if JSONIsTrue(Obj.GetValue('reused')) then Reused := 'Reusing loaded model';
          FStatus.Caption := Reused + '; context ' + Field(Obj, 'context') + '; ' +
            Field(Obj, 'gpu');
        end
        else if Kind = 'result' then
          begin
            Payload := Obj.GetValue('result');
            if not (Payload is TJSONObject) then
              raise Exception.Create('Missing generation result.');
            Report := TJSONObject(Payload);
            FLastJSON := Report.ToJSON;
            FOutput.Text := Field(Report, 'text');
            Reused := 'no';
            if JSONIsTrue(Report.GetValue('model_reused')) then Reused := 'yes';
            FStatus.Caption := 'Generated ' + Field(Report, 'generated_tokens') + ' tokens; stop: ' +
              Field(Report, 'stop') + '; model reused: ' + Reused + '; seconds: ' +
              Field(Report, 'total_seconds');
          end
          else if (Kind = 'error') or (Kind = 'fatal') then
            begin
              FStatus.Caption := 'Failed: ' + Field(Obj, 'message');
              FOutput.Text := FStatus.Caption;
            end
            else if Kind = 'done' then
                SetBusy(False);
  finally
    Value.Free;
  end;
end;

procedure TGemmaChatForm.Tick(Sender: TObject);
var
  Line: string;
  Code: Cardinal;
  I: Integer;
begin
  if FProcess = nil then Exit;
  try
    for I := 1 to 256 do
    begin
      if not FProcess.ReadLine(Line) then Break;
      HandleEvent(Line);
    end;
    if FProcess.HasExited(Code) then
    begin
      while FProcess.ReadLine(Line) do HandleEvent(Line);
      FreeAndNil(FProcess);
      if (Code <> 0) or not FRuntimeClosed then
      begin
        FClosing := False;
        FStatus.Caption := 'Runtime exited unexpectedly (code ' + UIntToStr(Code) + ').';
        FOutput.Lines.Add(FStatus.Caption + sLineBreak + FDiagnostic);
      end;
      SetBusy(False);
      if FClosing then Close;
    end;
  except
    on E: Exception do FStatus.Caption := 'Runtime error: ' + E.Message;
  end;
end;

procedure TGemmaChatForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FProcess = nil;
  if not CanClose and not FClosing then
  begin
    FClosing := True;
    FProcess.RequestClose;
    SetBusy(FBusy);
    FStatus.Caption := 'Closing the model and releasing GPU memory...';
  end;
end;

end.
