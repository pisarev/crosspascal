unit LanguageChat.Form;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls,
  Dialogs, Windows, {$ELSE}System.Classes, System.SysUtils, Vcl.Controls, Vcl.Forms,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Winapi.Windows, {$ENDIF}
  QwenCuda, LanguageModel, ExampleDefaults;

type
  TLanguageChatForm = class;
  TModelAction = (maLoad, maGenerate, maUnload);

  TLanguageWorker = class(TThread)
  private
    FForm: TLanguageChatForm;
    FAction: TModelAction;
    FBundle: string;
    FRuntime: string;
    FPrompt: string;
    FImage: string;
    FOptions: TLanguageOptions;
    FStatus: string;
    FText: string;
    FError: string;
    FReport: string;
    procedure ShowStatus;
    procedure ShowText;
    procedure ReportStatus(const Value: string);
    procedure ReportText(const Value: string);
    function Stopping: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const Form: TLanguageChatForm; const Action: TModelAction);
  end;

  TLanguageChatForm = class(TForm)
  private
    FModel: TLanguageModel;
    FContent: TScrollBox;
    FAdvanced: TScrollBox;
    FSettingsToggle: TButton;
    FWorker: TLanguageWorker;
    FTimer: TTimer;
    FBundle: TEdit;
    FRuntime: TEdit;
    FMaxTokens: TEdit;
    FTemperature: TEdit;
    FTopP: TEdit;
    FTopK: TEdit;
    FPenalty: TEdit;
    FSeed: TEdit;
    FSampling: TComboBox;
    FEffort: TComboBox;
    FPrompt: TMemo;
    FOutput: TMemo;
    FSystem: TMemo;
    FPlain: TCheckBox;
    FLoad: TButton;
    FUnload: TButton;
    FRun: TButton;
    FStop: TButton;
    FSave: TButton;
    FAttach: TButton;
    FRemove: TButton;
    FBundleBrowse: TButton;
    FRuntimeBrowse: TButton;
    FPreview: TImage;
    FImageName: TLabel;
    FCapability: TLabel;
    FStatus: TLabel;
    FSettings: TGroupBox;
    FImagePath: string;
    FLastJSON: string;
    FLoadedBundle: string;
    FLoadedRuntime: string;
    FClosing: Boolean;
    procedure FitOnScreen(Sender: TObject);
    procedure ToggleSettings(Sender: TObject);
    procedure BrowseBundle(Sender: TObject);
    procedure BrowseRuntime(Sender: TObject);
    procedure AttachImage(Sender: TObject);
    procedure RemoveImage(Sender: TObject);
    procedure LoadClick(Sender: TObject);
    procedure UnloadClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure RefreshControls;
    procedure StartAction(const Action: TModelAction);
    function ReadOptions: TLanguageOptions;
  protected
    procedure SetDemoTitle(const Title: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure WriteNewReport(const Path, JSONText: string);

implementation

uses
  {$IFDEF FPC}FPImage, IntfGraphics{$ELSE}Vcl.FileCtrl, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage{$ENDIF},
  CrossPascal.Json;

type TUIText = {$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};

function ToUI(const Value: string): TUIText;
begin
  Result := {$IFDEF FPC}UTF8Encode(Value){$ELSE}Value{$ENDIF};
end;

function FromUI(const Value: TUIText): string;
begin
  Result := {$IFDEF FPC}UTF8Decode(Value){$ELSE}Value{$ENDIF};
end;

function FolderFromUI(const Value: TUIText): string;
begin
  Result := StringReplace(Trim(FromUI(Value)), '/', PathDelim, [rfReplaceAll]);
end;

function ChooseFolder(const Title: string; var Path: string; Owner: TWinControl): Boolean;
{$IFDEF FPC}
var
  D: TSelectDirectoryDialog;
{$ENDIF}
begin
  {$IFDEF FPC}
  D := TSelectDirectoryDialog.Create(Owner);
  try
    D.Title := UTF8Encode(Title);
    D.InitialDir := UTF8Encode(Path);
    Result := D.Execute;
    if Result then Path := UTF8Decode(D.FileName);
  finally
    D.Free;
  end;
  {$ELSE}
  Result := SelectDirectory(Title, '', Path, [sdNewUI, sdNewFolder], Owner);
  {$ENDIF}
end;

procedure WriteNewReport(const Path, JSONText: string);
var
  H: THandle;
  Stream: THandleStream;
  Bytes: TBytes;
begin
  H := CreateFileW(PWideChar(ExpandFileName(Path)), GENERIC_WRITE, 0, nil,
    CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then RaiseLastOSError;
  try
    Stream := THandleStream.Create(H);
    try
      Bytes := TEncoding.UTF8.GetBytes(JSONText + sLineBreak);
      if Length(Bytes) > 0 then Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
  finally
    CloseHandle(H);
  end;
end;

function FindSDK: string;
var
  Current, Parent: string;
  I: Integer;
begin
  Result := '';
  Current := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  for I := 0 to 10 do
  begin
    if DirectoryExists(IncludeTrailingPathDelimiter(Current) + 'crosspascal-tvm') then
      Exit(Current);
    Parent := ExtractFileDir(Current);
    if SameText(Parent, Current) then Break;
    Current := Parent;
  end;
end;

constructor TLanguageWorker.Create(const Form: TLanguageChatForm; const Action: TModelAction);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FForm := Form;
  FAction := Action;
  FBundle := FolderFromUI(Form.FBundle.Text);
  FRuntime := FolderFromUI(Form.FRuntime.Text);
  FPrompt := FromUI(Form.FPrompt.Text);
  FImage := Form.FImagePath;
  if Action = maGenerate then
    FOptions := Form.ReadOptions
  else
    FOptions := DefaultLanguageOptions;
end;

procedure TLanguageWorker.ShowStatus;
begin
  FForm.FStatus.Caption := ToUI(FStatus);
end;

procedure TLanguageWorker.ShowText;
begin
  FForm.FOutput.Text := ToUI(FText);
  FForm.FOutput.SelStart := Length(FForm.FOutput.Text);
end;

procedure TLanguageWorker.ReportStatus(const Value: string);
begin
  FStatus := Value;
  Synchronize(ShowStatus);
end;

procedure TLanguageWorker.ReportText(const Value: string);
begin
  FText := Value;
  Synchronize(ShowText);
end;

function TLanguageWorker.Stopping: Boolean;
begin
  Result := Terminated;
end;

procedure TLanguageWorker.Execute;
begin
  FForm.FModel.OnStatus := ReportStatus;
  FForm.FModel.OnText := ReportText;
  FForm.FModel.ShouldStop := Stopping;
  try
    try
      if FAction = maUnload then
        FForm.FModel.Unload
      else begin
        if not FForm.FModel.Loaded or (FBundle <> FForm.FLoadedBundle) or
          (FRuntime <> FForm.FLoadedRuntime) then FForm.FModel.Load(FBundle, FRuntime);
        if (FAction = maGenerate) and not Terminated then
        begin
          if FImage = '' then
            FReport := FForm.FModel.Generate(FPrompt, FOptions, [])
          else
            FReport := FForm.FModel.Generate(FPrompt, FOptions, [FImage]);
        end;
      end;
    except
      on E: Exception do FError := E.ClassName + ': ' + E.Message;
    end;
  finally
    FForm.FModel.OnStatus := nil;
    FForm.FModel.OnText := nil;
    FForm.FModel.ShouldStop := nil;
  end;
end;

procedure TLanguageChatForm.FitOnScreen(Sender: TObject);
var
  Area: TRect;
  AvailableWidth, AvailableHeight: Integer;
begin
  Area := Monitor.WorkareaRect;
  AvailableWidth := Area.Right - Area.Left;
  AvailableHeight := Area.Bottom - Area.Top;
  if Constraints.MinWidth > AvailableWidth then Constraints.MinWidth := AvailableWidth;
  if Constraints.MinHeight > AvailableHeight then Constraints.MinHeight := AvailableHeight;
  if Width > AvailableWidth then Width := AvailableWidth;
  if Height > AvailableHeight then Height := AvailableHeight;
  if Left + Width > Area.Right then Left := Area.Right - Width;
  if Top + Height > Area.Bottom then Top := Area.Bottom - Height;
  if Left < Area.Left then Left := Area.Left;
  if Top < Area.Top then Top := Area.Top;
end;

constructor TLanguageChatForm.Create(AOwner: TComponent);
var
  Header, ModelRow, Actions, Composer, Attachments, PromptPanel: TPanel;
  AnswerPanel, SettingsBody, Footer, Row, Field: TPanel;
  Heading: TLabel;
  SettingsY: Integer;

  function Panel(Parent: TWinControl; Alignment: TAlign; Size: Integer): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.BevelOuter := bvNone;
    Result.Caption := '';
    if Alignment = alTop then Result.Top := 30000;
    if Alignment = alLeft then Result.Left := 30000;
    if Alignment in [alTop, alBottom] then Result.Height := Size;
    if Alignment in [alLeft, alRight] then Result.Width := Size;
    Result.Align := Alignment;
    Result.Parent := Parent;
  end;

  function LabelOn(Parent: TWinControl; const Text: string; Alignment: TAlign): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Parent;
    Result.AutoSize := False;
    Result.Align := Alignment;
    Result.Height := 24;
    Result.Caption := ToUI(Text);
    Result.Layout := tlCenter;
  end;

  function ButtonOn(Parent: TWinControl; const Text: string; Width: Integer; Alignment: TAlign;
    Handler: TNotifyEvent): TButton;
  var
    Cell: TPanel;
  begin
    Cell := Panel(Parent, Alignment, Width);
    Cell.BorderWidth := 0;
    Cell.Width := 128;
    Cell.TabStop := False;
    Result := TButton.Create(Self);
    Result.Parent := Cell;
    Result.SetBounds(4, 2, 120, 32);
    Result.TabOrder := 0;
    Result.Caption := ToUI(Text);
    Result.OnClick := Handler;
  end;

  function SettingRow(const Text: string; Height: Integer): TPanel;
  var
    Cell: TPanel;
  begin
    Cell := Panel(SettingsBody, alTop, Height + 12);
    Cell.Top := SettingsY;
    Result := Panel(Cell, alTop, Height);
    if Text <> '' then LabelOn(Result, Text, alTop);
    Inc(SettingsY, Height + 12);
  end;

  function SettingEdit(const Text, Value: string): TEdit;
  var
    Field: TPanel;
  begin
    Field := SettingRow(Text, 52);
    Result := TEdit.Create(Self);
    Result.Parent := Field;
    Result.Align := alClient;
    Result.Text := ToUI(Value);
  end;

  function SettingCombo(const Text, Items: string): TComboBox;
  var
    Field: TPanel;
  begin
    Field := SettingRow(Text, 52);
    Result := TComboBox.Create(Self);
    Result.Parent := Field;
    Result.Align := alClient;
    Result.Style := csDropDownList;
    Result.Items.Text := ToUI(Items);
    Result.ItemIndex := 0;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal Language Chat';
  Position := poScreenCenter;
  OnShow := FitOnScreen;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 1080;
  ClientHeight := 740;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 560;
  FModel := TLanguageModel.Create;
  FContent := TScrollBox.Create(Self);
  FContent.Parent := Self;
  FContent.Align := alClient;
  FContent.BorderStyle := bsNone;
  FContent.AutoScroll := False;
  Header := Panel(FContent, alTop, 132);
  Header.BorderWidth := 12;
  Heading := LabelOn(Header, 'Model', alTop);
  Heading.Font.Style := [fsBold];
  ModelRow := Panel(Header, alTop, 36);
  ModelRow.DisableAlign;
  FUnload := ButtonOn(ModelRow, 'Unload', 86, alRight, UnloadClick);
  FLoad := ButtonOn(ModelRow, 'Load model', 110, alRight, LoadClick);
  FBundleBrowse := ButtonOn(ModelRow, 'Browse...', 92, alRight, BrowseBundle);
  Row := Panel(ModelRow, alClient, 0);
  Row.BorderWidth := 2;
  FBundle := TEdit.Create(Self);
  FBundle.Parent := Row;
  FBundle.Align := alClient;
  FBundle.AutoSize := False;
  FBundle.ShowHint := True;
  FBundle.Hint := 'Select the converted folder containing model.json.';
  FBundleBrowse.Parent.Left := 100;
  FLoad.Parent.Left := 200;
  FUnload.Parent.Left := 300;
  ModelRow.EnableAlign;
  Row := Panel(Header, alClient, 0);
  FSettingsToggle := ButtonOn(Row, 'Settings', 110, alRight, ToggleSettings);
  FCapability := LabelOn(Row, 'Choose a model to see its supported inputs.', alClient);
  FCapability.WordWrap := True;
  Footer := Panel(FContent, alBottom, 44);
  Footer.BorderWidth := 8;
  FStatus := LabelOn(Footer, 'Ready. Load a model, then enter a message.', alClient);
  FStatus.WordWrap := True;
  FAdvanced := TScrollBox.Create(Self);
  FAdvanced.Parent := FContent;
  FAdvanced.Align := alRight;
  FAdvanced.Width := 300;
  FAdvanced.BorderStyle := bsNone;
  FAdvanced.HorzScrollBar.Visible := False;
  FAdvanced.Visible := False;
  FSettings := TGroupBox.Create(Self);
  FSettings.Parent := FAdvanced;
  FSettings.Caption := 'Settings';
  FSettings.SetBounds(8, 0, 278, 920);
  FSettings.Anchors := [akLeft, akTop, akRight];
  SettingsBody := Panel(FSettings, alClient, 0);
  SettingsBody.BorderWidth := 8;
  SettingsBody.DisableAlign;
  SettingsY := 8;
  FMaxTokens := SettingEdit('New tokens (0 = automatic)', '0');
  FSampling := SettingCombo('Sampling', 'Auto' + sLineBreak + 'Sample' + sLineBreak + 'Greedy');
  FEffort := SettingCombo('Answer budget', 'Full context' + sLineBreak + 'Brief (128)' +
    sLineBreak + 'Balanced (512)' + sLineBreak + 'Detailed (1024)');
  FTemperature := SettingEdit('Temperature', '0.7');
  FTopP := SettingEdit('Top P', '0.8');
  FTopK := SettingEdit('Top K', '20');
  FPenalty := SettingEdit('Repetition penalty', '1.1');
  FSeed := SettingEdit('Seed (-1 = random)', '-1');
  Row := SettingRow('', 32);
  FPlain := TCheckBox.Create(Self);
  FPlain.Parent := Row;
  FPlain.Align := alClient;
  FPlain.Caption := 'Plain completion';
  Row := SettingRow('Instructions', 100);
  FSystem := TMemo.Create(Self);
  FSystem.Parent := Row;
  FSystem.Align := alClient;
  FSystem.Text := 'You are a helpful assistant.';
  FSystem.ScrollBars := ssVertical;
  Row := SettingRow('Installed SDK folder', 64);
  Row := Panel(Row, alBottom, 36);
  FRuntimeBrowse := ButtonOn(Row, '...', 40, alRight, BrowseRuntime);
  Field := Panel(Row, alClient, 0);
  Field.BorderWidth := 2;
  FRuntime := TEdit.Create(Self);
  FRuntime.Parent := Field;
  FRuntime.AutoSize := False;
  FRuntime.Align := alClient;
  FRuntime.Text := ToUI(FindSDK);
  FSettings.Height := SettingsY + 40;
  SettingsBody.EnableAlign;
  AnswerPanel := Panel(FContent, alClient, 0);
  AnswerPanel.BorderWidth := 12;
  Composer := Panel(AnswerPanel, alBottom, 206);
  Composer.BorderWidth := 3;
  Heading := LabelOn(Composer, 'Message', alTop);
  Heading.Font.Style := [fsBold];
  Actions := Panel(Composer, alBottom, 40);
  Actions.Top := 30000;
  FStop := ButtonOn(Actions, 'Stop', 82, alRight, StopClick);
  FRun := ButtonOn(Actions, 'Generate', 116, alRight, RunClick);
  FSave := ButtonOn(Actions, 'Save result...', 126, alLeft, SaveClick);
  Attachments := Panel(Composer, alBottom, 40);
  Attachments.Top := 20000;
  Attachments.DisableAlign;
  FAttach := ButtonOn(Attachments, 'Attach image...', 132, alLeft, AttachImage);
  FRemove := ButtonOn(Attachments, 'Remove', 86, alLeft, RemoveImage);
  FImageName := LabelOn(Attachments, 'No image attached', alClient);
  FImageName.ShowHint := True;
  FAttach.Parent.Left := 0;
  FRemove.Parent.Left := 128;
  Attachments.EnableAlign;
  PromptPanel := Panel(Composer, alClient, 0);
  PromptPanel.BorderWidth := 3;
  FPreview := TImage.Create(Self);
  FPreview.Parent := PromptPanel;
  FPreview.Align := alRight;
  FPreview.Width := 112;
  FPreview.Proportional := True;
  FPreview.Center := True;
  FPreview.Stretch := True;
  FPreview.Visible := False;
  FPrompt := TMemo.Create(Self);
  FPrompt.Parent := PromptPanel;
  FPrompt.Align := alClient;
  FPrompt.Text := 'Say hello in English.';
  FPrompt.ScrollBars := ssVertical;
  Heading := LabelOn(AnswerPanel, 'Answer', alTop);
  Heading.Font.Style := [fsBold];
  FOutput := TMemo.Create(Self);
  FOutput.Parent := AnswerPanel;
  FOutput.Align := alClient;
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssVertical;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 40;
  FTimer.OnTimer := Tick;
  OnCloseQuery := CheckClose;
  if HasPreparedExample then
  begin
    FBundle.Text := ToUI(PreparedPath('model'));
    FRuntime.Text := ToUI(PreparedPath('sdk', FindSDK));
    FPrompt.Text := ToUI(PreparedValue('prompt', 'Say hello in English.'));
    FImagePath := PreparedPath('image');
    if FImagePath <> '' then
    begin
      FPreview.Picture.LoadFromFile(ToUI(FImagePath));
      FPreview.Visible := True;
      FImageName.Caption := ToUI(ExtractFileName(FImagePath));
      FImageName.Hint := ToUI(FImagePath);
    end;
    FStatus.Caption := 'Prepared example. Click Load model, then Generate.';
  end;
  Header.TabOrder := 0;
  FAdvanced.TabOrder := 1;
  AnswerPanel.TabOrder := 2;
  Footer.TabOrder := 3;
  ModelRow.TabOrder := 0;
  FSettingsToggle.Parent.Parent.TabOrder := 1;
  FBundle.Parent.TabOrder := 0;
  FBundleBrowse.Parent.TabOrder := 1;
  FLoad.Parent.TabOrder := 2;
  FUnload.Parent.TabOrder := 3;
  FBundle.TabOrder := 0;
  FOutput.TabOrder := 0;
  Composer.TabOrder := 1;
  PromptPanel.TabOrder := 0;
  Attachments.TabOrder := 1;
  Actions.TabOrder := 2;
  FPrompt.TabOrder := 0;
  FAttach.Parent.TabOrder := 0;
  FRemove.Parent.TabOrder := 1;
  FSave.Parent.TabOrder := 0;
  FStop.Parent.TabOrder := 1;
  FRun.Parent.TabOrder := 2;
  FStop.Parent.Left := 200;
  FRun.Parent.Left := 300;
  FRuntime.Parent.TabOrder := 0;
  FRuntime.TabOrder := 0;
  FRuntimeBrowse.Parent.TabOrder := 1;
  RefreshControls;
end;

procedure TLanguageChatForm.ToggleSettings(Sender: TObject);
begin
  FAdvanced.Visible := not FAdvanced.Visible;
  if FAdvanced.Visible then
    FSettingsToggle.Caption := 'Hide settings'
  else
    FSettingsToggle.Caption := 'Settings';
end;

procedure TLanguageChatForm.SetDemoTitle(const Title: string);
begin
  Caption := ToUI(Title);
end;

function TLanguageChatForm.ReadOptions: TLanguageOptions;
var
  FS: TFormatSettings;
begin
  Result := DefaultLanguageOptions;
  FS := JSONInvariantFormat;
  if not TryStrToInt64(FMaxTokens.Text, Result.MaxNewTokens) then
    raise Exception.Create('New tokens must be an integer; 0 means automatic.');
  Result.Sampling := TQwenSamplingMode(FSampling.ItemIndex);
  Result.Effort := TQwenAnswerEffort(FEffort.ItemIndex);
  if not TryStrToFloat(FTemperature.Text, Result.Temperature, FS) then
    raise Exception.Create('Invalid temperature. Use a decimal point.');
  if not TryStrToFloat(FTopP.Text, Result.TopP, FS) then raise Exception.Create('Invalid Top P.');
  if not TryStrToInt(FTopK.Text, Result.TopK) then raise Exception.Create('Invalid Top K.');
  if not TryStrToFloat(FPenalty.Text, Result.RepetitionPenalty, FS) then
    raise Exception.Create('Invalid repetition penalty.');
  if not TryStrToInt64(FSeed.Text, Result.Seed) then raise Exception.Create('Invalid seed.');
  Result.SystemPrompt := FromUI(FSystem.Text);
  Result.PlainCompletion := FPlain.Checked;
  ValidateQwenGenerationOptions(Result);
end;

procedure TLanguageChatForm.BrowseBundle(Sender: TObject);
var
  Path: string;
  Info: TLanguageCapabilities;
begin
  Path := FolderFromUI(FBundle.Text);
  if not ChooseFolder('Select a converted model bundle', Path, Self) then Exit;
  FBundle.Text := ToUI(Path);
  try
    Info := TLanguageModel.Inspect(Path);
    FCapability.Caption := ToUI(Info.Architecture + ' / ' + Info.Device + ' / context ' + IntToStr(Info.ContextTokens));
    if Info.SupportsImages then
      FCapability.Caption := FCapability.Caption + ' / text + images'
    else
      FCapability.Caption := FCapability.Caption + ToUI(' / text only. ' + Info.ImageExplanation);
  except
    on E: Exception do FCapability.Caption := ToUI(E.Message);
  end;
end;

procedure TLanguageChatForm.BrowseRuntime(Sender: TObject);
var
  Path: string;
begin
  Path := FolderFromUI(FRuntime.Text);
  if ChooseFolder('Select the installed SDK root', Path, Self) then FRuntime.Text := ToUI(Path);
end;

procedure TLanguageChatForm.AttachImage(Sender: TObject);
var
  D: TOpenDialog;
  Info: TLanguageCapabilities;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Attach an image';
    D.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp';
    if not D.Execute then Exit;
    try
      FPreview.Picture.LoadFromFile(D.FileName);
      FImagePath := {$IFDEF FPC}UTF8Decode(D.FileName){$ELSE}D.FileName{$ENDIF};
      FImageName.Caption := ToUI(ExtractFileName(FImagePath));
      FImageName.Hint := ToUI(FImagePath);
      FPreview.Visible := True;
      if FBundle.Text <> '' then
      begin
        Info := TLanguageModel.Inspect(FolderFromUI(FBundle.Text));
        if not Info.SupportsImages then
          FStatus.Caption := 'This is a text-only bundle. Remove the image to continue, or select a compatible image bundle.';
      end;
    except
      on E: Exception do FStatus.Caption := ToUI(E.Message);
    end;
    RefreshControls;
  finally
    D.Free;
  end;
end;

procedure TLanguageChatForm.RemoveImage(Sender: TObject);
begin
  FImagePath := '';
  FPreview.Picture.Assign(nil);
  FPreview.Visible := False;
  FImageName.Hint := '';
  FImageName.Caption := 'No image attached';
  FStatus.Caption := 'Image removed. The next request will contain text only.';
  RefreshControls;
end;

procedure TLanguageChatForm.StartAction(const Action: TModelAction);
var
  Info: TLanguageCapabilities;
begin
  if FWorker <> nil then Exit;
  try
    if (Action = maGenerate) and (FImagePath <> '') then
    begin
      Info := TLanguageModel.Inspect(FolderFromUI(FBundle.Text));
      if not Info.SupportsImages then
      begin
        FStatus.Caption := 'Image cannot be used with this bundle. Click Remove image for a text-only request, or choose a multimodal bundle.';
        Exit;
      end;
    end;
    FWorker := TLanguageWorker.Create(Self, Action);
    if Action = maGenerate then
    begin
      FOutput.Clear;
      FLastJSON := '';
    end;
    FStatus.Caption := 'Working...'; RefreshControls; FWorker.Start;
  except
    on E: Exception do
    begin
      FStatus.Caption := ToUI(E.Message);
      RefreshControls;
    end;
  end;
end;

procedure TLanguageChatForm.LoadClick(Sender: TObject);
begin
  StartAction(maLoad);
end;

procedure TLanguageChatForm.UnloadClick(Sender: TObject);
begin
  StartAction(maUnload);
end;

procedure TLanguageChatForm.RunClick(Sender: TObject);
begin
  StartAction(maGenerate);
end;

procedure TLanguageChatForm.StopClick(Sender: TObject);
begin
  if FWorker <> nil then
  begin
    FWorker.Terminate;
    FStatus.Caption := 'Stopping at the next safe operation boundary...';
  end;
end;

procedure TLanguageChatForm.SaveClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  if FLastJSON = '' then Exit;
  D := TSaveDialog.Create(Self);
  try
    D.Title := 'Save generation report';
    D.DefaultExt := 'json';
    D.Filter := 'JSON report|*.json';
    if D.Execute then
      WriteNewReport({$IFDEF FPC}UTF8Decode(D.FileName){$ELSE}D.FileName{$ENDIF}, FLastJSON);
  finally
    D.Free;
  end;
end;

procedure TLanguageChatForm.RefreshControls;
var
  Idle: Boolean;
begin
  Idle := FWorker = nil;
  FBundle.Enabled := Idle;
  FRuntime.Enabled := Idle;
  FBundleBrowse.Enabled := Idle;
  FRuntimeBrowse.Enabled := Idle;
  FPrompt.Enabled := Idle;
  FSystem.Enabled := Idle;
  FSettings.Enabled := Idle;
  FLoad.Enabled := Idle;
  FUnload.Enabled := Idle and FModel.Loaded;
  FRun.Enabled := Idle;
  FStop.Enabled := not Idle;
  FAttach.Enabled := Idle;
  FRemove.Enabled := Idle and (FImagePath <> '');
  FSave.Enabled := Idle and (FLastJSON <> '');
end;

procedure TLanguageChatForm.Tick(Sender: TObject);
var
  Info: TLanguageCapabilities;
begin
  if (FWorker = nil) or not FWorker.Finished then Exit;
  FWorker.WaitFor;
  if FWorker.FError <> '' then
    FStatus.Caption := ToUI(FWorker.FError)
  else begin
    if FModel.Loaded then
    begin
      FLoadedBundle := FWorker.FBundle;
      FLoadedRuntime := FWorker.FRuntime;
      Info := FModel.Capabilities;
      FCapability.Caption := ToUI(Info.Architecture + ' / ' + Info.Device + ' / context ' + IntToStr(Info.ContextTokens));
      if Info.SupportsImages then
        FCapability.Caption := FCapability.Caption + ' / text + images'
      else
        FCapability.Caption := FCapability.Caption + ' / text only';
      FStatus.Caption := 'Model remains loaded for the next request. Use Unload model to release it.';
    end
    else
      FStatus.Caption := 'Model unloaded. Memory released.';
    if FWorker.FReport <> '' then FLastJSON := FWorker.FReport;
  end;
  FreeAndNil(FWorker); RefreshControls;
  if FClosing then Close;
end;

procedure TLanguageChatForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then
  begin
    FClosing := True; StopClick(nil);
  end;
end;

destructor TLanguageChatForm.Destroy;
begin
  if FTimer <> nil then FTimer.Enabled := False;
  FModel.Free;
  inherited;
end;

end.
