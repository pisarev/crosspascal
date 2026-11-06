unit LanguageChat.Form;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls,
  Dialogs, Windows, {$ELSE}System.Classes, System.SysUtils, Vcl.Controls, Vcl.Forms,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Winapi.Windows, {$ENDIF}
  QwenCuda, LanguageModel;

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
  FBundle := FromUI(Form.FBundle.Text);
  FRuntime := FromUI(Form.FRuntime.Text);
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

constructor TLanguageChatForm.Create(AOwner: TComponent);
var
  LabelControl: TLabel;

  function AddLabel(const Text: string; X, Y, W: Integer; Parent: TWinControl): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Parent;
    Result.Caption := ToUI(Text); Result.SetBounds(X, Y, W, 20);
  end;

  function AddEdit(const Text, Value: string; X, Y, W: Integer; Parent: TWinControl): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Parent;
    LabelControl := AddLabel(Text, X, Y, W, Parent);
    LabelControl.FocusControl := Result;
    Result.SetBounds(X, Y + 21, W, 26);
    Result.Text := ToUI(Value);
  end;

  function AddButton(const Text: string; X, Y, W: Integer; Handler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := FContent;
    Result.Caption := ToUI(Text);
    Result.SetBounds(X, Y, W, 28);
    Result.OnClick := Handler;
  end;

  function AddCombo(const Text, Items: string; X, Y, W: Integer): TComboBox;
  begin
    Result := TComboBox.Create(Self);
    Result.Parent := FSettings;
    AddLabel(Text, X, Y, W, FSettings); Result.SetBounds(X, Y + 21, W, 28);
    Result.Style := csDropDownList;
    Result.Items.Text := ToUI(Items);
    Result.ItemIndex := 0;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal Language Chat';
  Position := poScreenCenter;
  ClientWidth := 980;
  ClientHeight := 850;
  if ClientHeight > Screen.WorkAreaHeight - 80 then
    ClientHeight := Screen.WorkAreaHeight - 80;
  Constraints.MinWidth := 996;
  Constraints.MinHeight := 460;
  FContent := TScrollBox.Create(Self);
  FContent.Parent := Self;
  FContent.Align := alClient;
  FContent.BorderStyle := bsNone;
  FContent.AutoScroll := True;
  FModel := TLanguageModel.Create;
  FBundle := AddEdit('Converted model bundle (the folder containing model.json)', '', 16, 12, 820, FContent);
  FBundleBrowse := AddButton('Browse...', 850, 33, 110, BrowseBundle);
  FRuntime := AddEdit('Installed SDK root (contains crosspascal-tvm and runtime)', FindSDK, 16, 65,
    820, FContent);
  FRuntimeBrowse := AddButton('Browse...', 850, 86, 110, BrowseRuntime);
  FCapability := AddLabel('Select a converted bundle. Supported inputs are checked before inference.',
    16, 122, 940, FContent);
  FCapability.WordWrap := True;
  FCapability.Height := 38;
  FLoad := AddButton('Load model', 16, 164, 120, LoadClick);
  FUnload := AddButton('Unload model', 146, 164, 120, UnloadClick);
  FSettings := TGroupBox.Create(Self);
  FSettings.Parent := FContent;
  FSettings.Caption := 'Generation settings'; FSettings.SetBounds(16, 205, 944, 138);
  FMaxTokens := AddEdit('New tokens (0 = auto)', '0', 12, 20, 155, FSettings);
  FSampling := AddCombo('Sampling', 'Auto' + sLineBreak + 'Sample' + sLineBreak + 'Greedy', 180, 20, 145);
  FEffort := AddCombo('Answer budget', 'Full context' + sLineBreak + 'Brief (128)' + sLineBreak +
    'Balanced (512)' + sLineBreak + 'Detailed (1024)', 340, 20, 185);
  FTemperature := AddEdit('Temperature', '0.7', 540, 20, 110, FSettings);
  FTopP := AddEdit('Top P', '0.8', 665, 20, 110, FSettings);
  FTopK := AddEdit('Top K', '20', 790, 20, 110, FSettings);
  FPenalty := AddEdit('Repetition penalty', '1.1', 12, 78, 155, FSettings);
  FSeed := AddEdit('Seed (-1 = random)', '-1', 180, 78, 145, FSettings);
  FPlain := TCheckBox.Create(Self);
  FPlain.Parent := FSettings;
  FPlain.Caption := 'Plain completion (no chat template)'; FPlain.SetBounds(340, 99, 340, 24);
  AddLabel('Instructions (Qwen: system role; Gemma: prepended to the user prompt)', 16, 355, 940, FContent);
  FSystem := TMemo.Create(Self);
  FSystem.Parent := FContent; FSystem.SetBounds(16, 377, 944, 46);
  FSystem.Text := 'You are a helpful assistant.';
  FSystem.ScrollBars := ssVertical;
  AddLabel('Prompt', 16, 432, 740, FContent);
  FPrompt := TMemo.Create(Self);
  FPrompt.Parent := FContent; FPrompt.SetBounds(16, 454, 740, 100);
  FPrompt.Text := 'Say hello in English.';
  FPrompt.ScrollBars := ssVertical;
  FPreview := TImage.Create(Self);
  FPreview.Parent := FContent; FPreview.SetBounds(775, 454, 185, 100);
  FPreview.Proportional := True;
  FPreview.Center := True;
  FPreview.Stretch := True;
  FAttach := AddButton('Attach image...', 16, 565, 140, AttachImage);
  FRemove := AddButton('Remove image', 166, 565, 135, RemoveImage);
  FImageName := AddLabel('No image attached', 315, 570, 645, FContent);
  FRun := AddButton('Generate', 16, 607, 130, RunClick);
  FStop := AddButton('Stop', 156, 607, 110, StopClick);
  FSave := AddButton('Save result...', 276, 607, 140, SaveClick);
  FStatus := AddLabel('Ready. Auto stops at end of answer, Stop, or the real bundle context limit.',
    16, 646, 940, FContent);
  FStatus.WordWrap := True;
  FStatus.Height := 38;
  FOutput := TMemo.Create(Self);
  FOutput.Parent := FContent; FOutput.SetBounds(16, 692, 944, 142);
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssVertical;
  FOutput.Anchors := [akLeft, akTop, akRight];
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 40;
  FTimer.OnTimer := Tick;
  OnCloseQuery := CheckClose;
  RefreshControls;
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
  Path := FromUI(FBundle.Text);
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
  Path := FromUI(FRuntime.Text);
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
    FPreview.Picture.LoadFromFile(D.FileName);
    FImagePath := {$IFDEF FPC}UTF8Decode(D.FileName){$ELSE}D.FileName{$ENDIF};
    FImageName.Caption := ToUI(ExtractFileName(FImagePath));
    if FBundle.Text <> '' then
    begin
      Info := TLanguageModel.Inspect(FromUI(FBundle.Text));
      if not Info.SupportsImages then
        FStatus.Caption := 'This is a text-only bundle. Remove the image to continue, or select a compatible image bundle.';
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
  FImageName.Caption := 'No image attached';
  FStatus.Caption := 'Image removed. The next request will contain text only.';
  RefreshControls;
end;

procedure TLanguageChatForm.StartAction(const Action: TModelAction);
var
  Info: TLanguageCapabilities;
begin
  if FWorker <> nil then Exit;
  if (Action = maGenerate) and (FImagePath <> '') then
  begin
    Info := TLanguageModel.Inspect(FromUI(FBundle.Text));
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
