unit QwenChat.Main;

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}

interface

uses
  {$IFDEF FPC}Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls, {$ELSE}
  System.Classes, System.SysUtils, System.UITypes, Vcl.Controls, Vcl.Forms,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, {$ENDIF} QwenCuda;

type
  TQwenChatForm = class;

  TQwenWorker = class(TThread)
  private
    FForm: TQwenChatForm;
    FBundle: string;
    FRuntime: string;
    FPrompt: string;
    FOptions: TQwenGenerationOptions;
    FResult: TQwenCudaResult;
    FErrorText: string;
    FProgressText: string;
    FStoppedBeforeGeneration: Boolean;
    function StopRequested: Boolean;
    procedure ShowProgress;
    procedure ReportProgress(const MessageText: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const Form: TQwenChatForm; const Bundle, Runtime, Prompt: string;
      const Options: TQwenGenerationOptions);
  end;

  TQwenChatForm = class(TForm)
  private
    FBundle: TEdit;
    FRuntime: TEdit;
    FPrompt: TMemo;
    FOutput: TMemo;
    FMaxTokens: TEdit;
    FGeneration: TGroupBox;
    FSampling: TComboBox;
    FEffort: TComboBox;
    FTemperature: TEdit;
    FTopP: TEdit;
    FTopK: TEdit;
    FRepetitionPenalty: TEdit;
    FSeed: TEdit;
    FRun: TButton;
    FStop: TButton;
    FBundleBrowse: TButton;
    FRuntimeBrowse: TButton;
    FSave: TButton;
    FStatus: TLabel;
    FTimer: TTimer;
    FWorker: TQwenWorker;
    FLastJSON: string;
    procedure BrowseBundle(Sender: TObject);
    procedure BrowseRuntime(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure WorkerTerminated(Sender: TObject);
    procedure WorkerTick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure SetRunning(const Value: Boolean);
    function ReadGenerationOptions: TQwenGenerationOptions;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetStatus(const MessageText: string);
  end;

var
  QwenChatForm: TQwenChatForm;

procedure WriteNewReport(const Path, JSONText: string);

implementation

uses
  {$IFDEF FPC}Windows, Dialogs{$ELSE}Winapi.Windows, Vcl.Dialogs, Vcl.FileCtrl{$ENDIF},
  CrossPascal.Json;

function ChooseBundleDirectory(const Caption: string; var Directory: string;
  const Owner: TWinControl): Boolean;
{$IFDEF FPC}
var
  Dialog: TSelectDirectoryDialog;
{$ENDIF}
begin
  {$IFDEF FPC}
  Dialog := TSelectDirectoryDialog.Create(Owner);
  try
    Dialog.Title := UTF8Encode(Caption);
    Dialog.InitialDir := UTF8Encode(Directory);
    Result := Dialog.Execute;
    if Result then Directory := UTF8Decode(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  {$ELSE}
  Result := SelectDirectory(Caption, '', Directory, [sdNewUI, sdNewFolder], Owner);
  {$ENDIF}
end;

procedure WriteNewReport(const Path, JSONText: string);
var
  Handle: THandle;
  Stream: THandleStream;
  Bytes: TBytes;
begin
  Handle := CreateFileW(PWideChar(ExpandFileName(Path)), GENERIC_WRITE, 0, nil,
    CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    Stream := THandleStream.Create(Handle);
    try
      Bytes := TEncoding.UTF8.GetBytes(JSONText + sLineBreak);
      if Length(Bytes) > 0 then
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
  finally
    CloseHandle(Handle);
  end;
end;

function FindRuntimeDirectory: string;
var
  Current, Parent, Candidate: string;
  I: Integer;
begin
  Result := '';
  Current := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  for I := 0 to 8 do
  begin
    Candidate := IncludeTrailingPathDelimiter(Current) + 'crosspascal-tvm\runtime\windows-x64-cuda';
    if FileExists(IncludeTrailingPathDelimiter(Candidate) + 'tvm_runtime_cuda.dll') then
      Exit(Candidate);
    Parent := ExtractFileDir(Current);
    if SameText(Parent, Current) then
      Break;
    Current := Parent;
  end;
end;

constructor TQwenWorker.Create(const Form: TQwenChatForm; const Bundle, Runtime, Prompt: string;
  const Options: TQwenGenerationOptions);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FForm := Form;
  FBundle := Bundle;
  FRuntime := Runtime;
  FPrompt := Prompt;
  FOptions := Options;
end;

function TQwenWorker.StopRequested: Boolean;
begin
  Result := Terminated;
end;

procedure TQwenWorker.ReportProgress(const MessageText: string);
begin
  FProgressText := MessageText;
  Synchronize(ShowProgress);
end;

procedure TQwenWorker.ShowProgress;
begin
  if not Terminated then
    FForm.SetStatus(FProgressText);
end;

procedure TQwenWorker.Execute;
begin
  try
    FResult := RunQwenCuda(FBundle, FRuntime, FPrompt, FOptions, ReportProgress, StopRequested);
  except
    on EQwenCudaCancelled do
      FStoppedBeforeGeneration := True;
    on E: Exception do
      FErrorText := E.ClassName + ': ' + E.Message;
  end;
end;

constructor TQwenChatForm.Create(AOwner: TComponent);
var
  LabelControl: TLabel;
  Options: TQwenGenerationOptions;

  function AddLabel(const Text: string; const Y: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.Caption := Text;
    Result.SetBounds(16, Y, 860, 20);
  end;

  procedure PlaceSetting(const Control: TWinControl; const Text: string;
    const X, Y, Width: Integer);
  var
    SettingLabel: TLabel;
  begin
    SettingLabel := TLabel.Create(Self);
    SettingLabel.Parent := FGeneration;
    SettingLabel.Caption := Text;
    SettingLabel.SetBounds(X, Y, Width, 20);
    SettingLabel.FocusControl := Control;
    Control.Parent := FGeneration;
    Control.SetBounds(X, Y + 20, Width, 26);
  end;

  function AddSetting(const CaptionText, DefaultText: string; const X, Width: Integer): TEdit;
  begin
    Result := TEdit.Create(Self);
    PlaceSetting(Result, CaptionText, X, 18, Width);
    Result.Text := DefaultText;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal Qwen CUDA';
  Position := poScreenCenter;
  ClientWidth := 900;
  ClientHeight := 690;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 600;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  OnCloseQuery := CheckClose;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 100;
  FTimer.OnTimer := WorkerTick;
  AddLabel('Converted model bundle (model.json, qwen2-cuda.dll, parameters and tokenizer)', 16);
  FBundle := TEdit.Create(Self);
  FBundle.Parent := Self;
  FBundle.SetBounds(16, 40, 758, 27);
  FBundle.Anchors := [akLeft, akTop, akRight];
  FBundleBrowse := TButton.Create(Self);
  FBundleBrowse.Parent := Self;
  FBundleBrowse.Caption := 'Browse...';
  FBundleBrowse.SetBounds(784, 40, 100, 27);
  FBundleBrowse.Anchors := [akTop, akRight];
  FBundleBrowse.OnClick := BrowseBundle;
  AddLabel('Pinned CUDA runtime directory (the four supplied TVM DLLs)', 80);
  FRuntime := TEdit.Create(Self);
  FRuntime.Parent := Self;
  FRuntime.SetBounds(16, 104, 758, 27);
  FRuntime.Anchors := [akLeft, akTop, akRight];
  FRuntime.Text := FindRuntimeDirectory;
  FRuntimeBrowse := TButton.Create(Self);
  FRuntimeBrowse.Parent := Self;
  FRuntimeBrowse.Caption := 'Browse...';
  FRuntimeBrowse.SetBounds(784, 104, 100, 27);
  FRuntimeBrowse.Anchors := [akTop, akRight];
  FRuntimeBrowse.OnClick := BrowseRuntime;
  LabelControl := AddLabel(Format('CUDA / float32 / %d-token context.',
    [QwenDefaultContextSize]), 144);
  LabelControl.Font.Style := [fsBold];
  AddLabel('Prompt (the chat template and generated tokens share the context window)', 176);
  FPrompt := TMemo.Create(Self);
  FPrompt.Parent := Self;
  FPrompt.SetBounds(16, 200, 868, 76);
  FPrompt.Anchors := [akLeft, akTop, akRight];
  FPrompt.ScrollBars := ssVertical;
  FPrompt.Lines.Text := 'Say hello in English.';
  Options := DefaultQwenGenerationOptions;
  FGeneration := TGroupBox.Create(Self);
  FGeneration.Parent := Self;
  FGeneration.Caption := 'Generation settings';
  FGeneration.SetBounds(16, 282, 868, 132);
  FGeneration.Anchors := [akLeft, akTop, akRight];
  FTemperature := AddSetting('Temperature', FloatToStr(Options.Temperature, JSONInvariantFormat), 12, 98);
  FTopP := AddSetting('Top-P', FloatToStr(Options.TopP, JSONInvariantFormat), 122, 72);
  FTopK := AddSetting('Top-K', IntToStr(Options.TopK), 206, 72);
  FRepetitionPenalty := AddSetting('Repetition penalty',
    FloatToStr(Options.RepetitionPenalty, JSONInvariantFormat), 290, 125);
  FSeed := AddSetting('Seed (blank = random)', '', 427, 155);
  FSampling := TComboBox.Create(Self);
  PlaceSetting(FSampling, 'Token selection', 12, 72, 265);
  FSampling.Style := csDropDownList;
  FSampling.Items.Add('Default (sample in Auto)');
  FSampling.Items.Add('Sample');
  FSampling.Items.Add('Greedy');
  FSampling.ItemIndex := Ord(Options.Sampling);
  FEffort := TComboBox.Create(Self);
  PlaceSetting(FEffort, 'Answer effort (Auto only)', 290, 72, 245);
  FEffort.Style := csDropDownList;
  FEffort.Items.Add('Full context');
  FEffort.Items.Add('Brief (128 tokens)');
  FEffort.Items.Add('Balanced (512 tokens)');
  FEffort.Items.Add('Detailed (1024 tokens)');
  FEffort.ItemIndex := Ord(Options.Effort);
  AddLabel('Max new tokens (0 = Auto)', 434);
  FMaxTokens := TEdit.Create(Self);
  FMaxTokens.Parent := Self;
  FMaxTokens.SetBounds(180, 428, 110, 28);
  FMaxTokens.NumbersOnly := True;
  FMaxTokens.Text := IntToStr(QwenDefaultMaxNewTokens);
  FRun := TButton.Create(Self);
  FRun.Parent := Self;
  FRun.Caption := 'Run on GPU';
  FRun.SetBounds(300, 428, 135, 30);
  FRun.OnClick := RunClick;
  FStop := TButton.Create(Self);
  FStop.Parent := Self;
  FStop.Caption := 'Stop';
  FStop.SetBounds(445, 428, 90, 30);
  FStop.Enabled := False;
  FStop.OnClick := StopClick;
  FSave := TButton.Create(Self);
  FSave.Parent := Self;
  FSave.Caption := 'Save result...';
  FSave.SetBounds(545, 428, 135, 30);
  FSave.Enabled := False;
  FSave.OnClick := SaveClick;
  FStatus := AddLabel('Select a converted bundle, enter a short prompt, and click Run on GPU.', 468);
  FStatus.SetBounds(16, 468, 868, 44);
  FStatus.Anchors := [akLeft, akTop, akRight];
  FStatus.WordWrap := True;
  FOutput := TMemo.Create(Self);
  FOutput.Parent := Self;
  FOutput.SetBounds(16, 520, 868, 154);
  FOutput.Anchors := [akLeft, akTop, akRight, akBottom];
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssVertical;
end;

procedure TQwenChatForm.SetStatus(const MessageText: string);
begin
  FStatus.Caption := MessageText;
end;

procedure TQwenChatForm.BrowseBundle(Sender: TObject);
var
  Directory: string;
begin
  Directory := FBundle.Text;
  if ChooseBundleDirectory('Select the converted Qwen CUDA bundle', Directory, Self) then
    FBundle.Text := Directory;
end;

procedure TQwenChatForm.BrowseRuntime(Sender: TObject);
var
  Directory: string;
begin
  Directory := FRuntime.Text;
  if ChooseBundleDirectory('Select the pinned CUDA runtime directory', Directory, Self) then
    FRuntime.Text := Directory;
end;

procedure TQwenChatForm.SetRunning(const Value: Boolean);
begin
  FRun.Enabled := not Value;
  FStop.Enabled := Value;
  FBundle.Enabled := not Value;
  FRuntime.Enabled := not Value;
  FBundleBrowse.Enabled := not Value;
  FRuntimeBrowse.Enabled := not Value;
  FPrompt.Enabled := not Value;
  FMaxTokens.Enabled := not Value;
  FGeneration.Enabled := not Value;
  FSave.Enabled := not Value and (FLastJSON <> '');
end;

function TQwenChatForm.ReadGenerationOptions: TQwenGenerationOptions;

  function ReadDecimal(const Edit: TEdit; const CaptionText: string): Double;
  begin
    if not TryStrToFloat(StringReplace(Trim(Edit.Text), ',', '.', [rfReplaceAll]), Result,
      JSONInvariantFormat) then
        raise EQwenCuda.Create(CaptionText + ' must be a number.');
  end;

begin
  Result := DefaultQwenGenerationOptions;
  if not TryStrToInt64(Trim(FMaxTokens.Text), Result.MaxNewTokens) then
    raise EQwenCuda.Create('Max new tokens must be 0 (Auto) or a positive whole number.');
  Result.Sampling := TQwenSamplingMode(FSampling.ItemIndex);
  Result.Effort := TQwenAnswerEffort(FEffort.ItemIndex);
  Result.Temperature := ReadDecimal(FTemperature, 'Temperature');
  Result.TopP := ReadDecimal(FTopP, 'Top-P');
  if not TryStrToInt(Trim(FTopK.Text), Result.TopK) then
    raise EQwenCuda.Create('Top-K must be a whole number.');
  Result.RepetitionPenalty := ReadDecimal(FRepetitionPenalty, 'Repetition penalty');
  if Trim(FSeed.Text) <> '' then
    if not TryStrToInt64(Trim(FSeed.Text), Result.Seed) or (Result.Seed < 0) then
      raise EQwenCuda.Create('Seed must be blank or a nonnegative whole number.');
  ValidateQwenGenerationOptions(Result);
end;

procedure TQwenChatForm.RunClick(Sender: TObject);
var
  Options: TQwenGenerationOptions;
begin
  if Assigned(FWorker) then
    Exit;
  Options := ReadGenerationOptions;
  FLastJSON := '';
  FOutput.Clear;
  SetRunning(True);
  try
    FWorker := TQwenWorker.Create(Self, FBundle.Text, FRuntime.Text, Trim(FPrompt.Text), Options);
    FWorker.Start;
    FTimer.Enabled := True;
  except
    FreeAndNil(FWorker);
    SetRunning(False);
    raise;
  end;
end;

procedure TQwenChatForm.StopClick(Sender: TObject);
begin
  if not Assigned(FWorker) then
    Exit;
  FWorker.Terminate;
  FStop.Enabled := False;
  SetStatus('Stopping after the current operation...');
end;

procedure TQwenChatForm.WorkerTick(Sender: TObject);
var
  Worker: TQwenWorker;
begin
  if not Assigned(FWorker) then
    Exit;
  if WaitForSingleObject(FWorker.Handle, 0) <> WAIT_OBJECT_0 then
    Exit;
  FTimer.Enabled := False;
  Worker := FWorker;
  try
    Worker.WaitFor;
    WorkerTerminated(Worker);
  finally
    FWorker := nil;
    Worker.Free;
  end;
end;

procedure TQwenChatForm.WorkerTerminated(Sender: TObject);
var
  Worker: TQwenWorker;
begin
  Worker := TQwenWorker(Sender);
  FWorker := nil;
  if Worker.FStoppedBeforeGeneration then
    SetStatus('Stopped before generation. Model and cache objects have been released.')
  else if Worker.FErrorText <> '' then
    begin
      FOutput.Lines.Text := Worker.FErrorText;
      SetStatus('Run failed. No CPU fallback was attempted.');
    end
    else begin
      FLastJSON := QwenResultJSON(Worker.FResult);
      FOutput.Lines.Add('GPU: ' + Worker.FResult.DeviceName +
        ' (compute ' + Worker.FResult.ComputeVersion + ')');
      FOutput.Lines.Add(Format('Context: %d tokens; available for the answer: %d',
        [Worker.FResult.ContextTokens, Worker.FResult.AvailableNewTokens]));
      FOutput.Lines.Add(Format('Prompt tokens: %d; generated tokens: %d; stop: %s',
        [Length(Worker.FResult.PromptTokenIDs), Length(Worker.FResult.GeneratedTokenIDs),
         Worker.FResult.StopReason]));
      FOutput.Lines.Add('');
      FOutput.Lines.Add(Worker.FResult.Answer);
      if Worker.FResult.StopReason = 'cancelled' then
        SetStatus('Stopped. The partial answer is shown below.')
      else
        SetStatus('CUDA generation finished. Model and cache objects have been released.');
    end;
  SetRunning(False);
end;

procedure TQwenChatForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not Assigned(FWorker);
  if not CanClose then
    MessageDlg('Use Stop or wait for the current GPU operation to finish before closing.',
      mtInformation, [mbOK], 0);
end;

procedure TQwenChatForm.SaveClick(Sender: TObject);
var
  Dialog: TSaveDialog;
begin
  if FLastJSON = '' then
    Exit;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Filter := 'JSON result (*.json)|*.json';
    Dialog.DefaultExt := 'json';
    Dialog.FileName := 'qwen-cuda-result.json';
    Dialog.Options := [ofPathMustExist, ofEnableSizing];
    if Dialog.Execute then
      WriteNewReport(Dialog.FileName, FLastJSON);
  finally
    Dialog.Free;
  end;
end;

end.
