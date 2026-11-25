unit YoloModels.Main;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  {$IFDEF FPC}Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls,
  Dialogs, ComCtrls{$ELSE}System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, Vcl.ComCtrls{$ENDIF},
  CrossVision.Mat, TVM.Yolo.Profile, YoloModels.Config, YoloModels.Run, YoloModels.Render,
  YoloModels.Worker;

type
  TYoloModelsForm = class(TForm)
  private
    FConfig: TYoloExampleConfig;
    FCVLibrary: string;
    FWorker: TYoloExampleWorker;
    FScroll: TScrollBox;
    FContent: TPanel;
    FModels: TComboBox;
    FDevice: TComboBox;
    FConfidence: TEdit;
    FNMS: TEdit;
    FKeypoints: TEdit;
    FOpacity: TTrackBar;
    FLabels: TComboBox;
    FView: TComboBox;
    FOpen: TButton;
    FRun: TButton;
    FStop: TButton;
    FUnload: TButton;
    FSave: TButton;
    FPreview: TImage;
    FDetails: TMemo;
    FStatus: TLabel;
    FTimer: TTimer;
    FImage: IMat;
    FImageSHA256: string;
    FValue: TYoloExampleResult;
    FFrame: TYoloViewFrame;
    FHasResult: Boolean;
    FFatal: Boolean;
    FChanging: Boolean;
    FClosePending: Boolean;
    FSessionError: string;
    FExportDirectory: string;
    procedure OpenImage(Sender: TObject);
    procedure Infer(Sender: TObject);
    procedure Stop(Sender: TObject);
    procedure Unload(Sender: TObject);
    procedure Save(Sender: TObject);
    procedure ModelChanged(Sender: TObject);
    procedure DeviceChanged(Sender: TObject);
    procedure DisplayChanged(Sender: TObject);
    procedure ViewChanged(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure FitContent(Sender: TObject);
    procedure ClearResult;
    procedure InvalidateDisplay;
    procedure UpdateControls;
    procedure PutPreview(const Image: IMat);
    procedure ShowPreview;
    procedure ShowDetails;
    procedure ReportError(const Text: string);
    function ViewStyle(const Task: TYoloTask): TYoloViewStyle;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Configure(const Config: TYoloExampleConfig; const CVLibrary: string);
    procedure LoadImage(const FileName: string);
    procedure CloseSession;
    property SessionError: string read FSessionError;
  end;

implementation

uses
  {$IFDEF FPC}Math, FPReadPNG{$ELSE}System.Math, Vcl.Imaging.pngimage{$ENDIF},
  OpenCV, CrossPascal.Json, CrossPascal.SHA256, TVM.CpuGraph, TVM.ImageInput,
  TVM.NativeDevice, TVM.Yolo.RunOptions;

function UI(const Text: string): {$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};
begin
  {$IFDEF FPC}Result := UTF8Encode(Text);
  {$ELSE}Result := Text;{$ENDIF}
end;

function EditText(const Edit: TEdit): string;
begin
  {$IFDEF FPC}Result := UTF8Decode(Edit.Text);
  {$ELSE}Result := Edit.Text;{$ENDIF}
end;

function Fraction(const Edit: TEdit): Single;
var
  Value: Double;
begin
  RequireCpu(TryStrToFloat(EditText(Edit), Value, JSONInvariantFormat) and
    not IsNan(Value) and not IsInfinite(Value) and (Value >= 0) and (Value <= 1),
    'Enter a value from 0 to 1, using a decimal point.');
  Result := Value;
end;

function Decimal(const Value: Double; const Digits: Integer = 3): string;
begin
  Result := FloatToStrF(Value, ffFixed, 12, Digits, JSONInvariantFormat);
end;

constructor TYoloModelsForm.Create(AOwner: TComponent);
var
  Header, Row, Tools, Display, Body, Sidebar: TPanel;
  RootCaption: TLabel;
  I: Integer;

  function Panel(const Parent: TWinControl; const AlignValue: TAlign;
    const HeightValue: Integer): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Caption := '';
    Result.BevelOuter := bvNone;
    Result.Parent := Parent;
    if AlignValue = alTop then Result.Top := 30000;
    Result.Height := HeightValue;
    Result.Align := AlignValue;
  end;

  procedure LabelAt(const Parent: TWinControl; const Text: string; const X, Y, WidthValue: Integer);
  var
    Value: TLabel;
  begin
    Value := TLabel.Create(Self);
    Value.Parent := Parent;
    Value.SetBounds(X, Y, WidthValue, 22);
    Value.AutoSize := False;
    Value.Caption := UI(Text);
    Value.FocusControl := nil;
  end;

  function Combo(const Parent: TWinControl; const X, Y, WidthValue: Integer): TComboBox;
  begin
    Result := TComboBox.Create(Self);
    Result.Parent := Parent;
    Result.Style := csDropDownList;
    Result.SetBounds(X, Y, WidthValue, 28);
  end;

  function Edit(const Text: string; const X: Integer): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Row;
    Result.SetBounds(X, 25, 100, 28);
    Result.Text := UI(Text);
  end;

  function Button(const Text: string; const X: Integer; const Handler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Tools;
    Result.SetBounds(X, 6, 128, 34);
    Result.Caption := UI(Text);
    Result.OnClick := Handler;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal YOLO';
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 1180;
  ClientHeight := 820;
  Position := poScreenCenter;
  OnCloseQuery := CheckClose;
  OnResize := FitContent;
  FChanging := True;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FContent := Panel(FScroll, alNone, 790);
  FContent.SetBounds(0, 0, 1160, 790);
  FContent.BorderWidth := 12;
  FContent.DisableAlign;
  Header := Panel(FContent, alTop, 250);
  Header.DisableAlign;
  RootCaption := TLabel.Create(Self);
  RootCaption.Parent := Header;
  RootCaption.SetBounds(0, 0, 720, 24);
  RootCaption.AutoSize := False;
  RootCaption.Align := alTop;
  RootCaption.Caption := 'Open an image, choose a model and device, then Run.';
  Row := Panel(Header, alTop, 78);
  Row.Top := 24;
  LabelAt(Row, 'Model / task', 0, 0, 480);
  FModels := Combo(Row, 0, 24, 470);
  FModels.OnChange := ModelChanged;
  LabelAt(Row, 'Device', 486, 0, 220);
  FDevice := Combo(Row, 486, 24, 210);
  FDevice.Items.Add('CPU');
  FDevice.Items.Add('NVIDIA CUDA');
  FDevice.ItemIndex := 0;
  FDevice.OnChange := DeviceChanged;
  Row := Panel(Header, alTop, 66);
  Row.Top := 102;
  LabelAt(Row, 'Confidence', 0, 0, 110);
  FConfidence := Edit('0.25', 0);
  LabelAt(Row, 'NMS IoU', 126, 0, 110);
  FNMS := Edit('0.45', 126);
  LabelAt(Row, 'Point visibility', 252, 0, 130);
  FKeypoints := Edit('0.5', 252);
  FKeypoints.OnChange := DisplayChanged;
  Tools := Panel(Header, alTop, 48);
  Tools.Top := 168;
  FOpen := Button('Open image...', 0, OpenImage);
  FRun := Button('Run', 140, Infer);
  FStop := Button('Stop', 280, Stop);
  FUnload := Button('Unload', 420, Unload);
  FSave := Button('Save results...', 560, Save);
  Header.EnableAlign;
  Display := Panel(FContent, alTop, 72);
  Display.Top := 250;
  LabelAt(Display, 'View', 0, 0, 150);
  FView := Combo(Display, 0, 24, 140);
  FView.Items.Add('Result');
  FView.Items.Add('Original');
  FView.ItemIndex := 0;
  FView.OnChange := ViewChanged;
  LabelAt(Display, 'Labels', 160, 0, 150);
  FLabels := Combo(Display, 160, 24, 140);
  FLabels.Items.Add('Auto');
  FLabels.Items.Add('All');
  FLabels.Items.Add('None');
  FLabels.ItemIndex := 0;
  FLabels.OnChange := DisplayChanged;
  LabelAt(Display, 'Mask opacity', 326, 0, 220);
  FOpacity := TTrackBar.Create(Self);
  FOpacity.Parent := Display;
  FOpacity.SetBounds(320, 20, 238, 42);
  FOpacity.Min := 0;
  FOpacity.Max := 100;
  FOpacity.Frequency := 25;
  FOpacity.Position := 45;
  FOpacity.OnChange := DisplayChanged;
  Body := Panel(FContent, alClient, 0);
  Body.Top := 322;
  Sidebar := Panel(Body, alRight, 0);
  Sidebar.Width := 280;
  Sidebar.BorderWidth := 6;
  FDetails := TMemo.Create(Self);
  FDetails.Parent := Sidebar;
  FDetails.Align := alClient;
  FDetails.ReadOnly := True;
  FDetails.ScrollBars := ssVertical;
  FDetails.WordWrap := True;
  FDetails.TabStop := True;
  FDetails.Text := 'Choose a model and open a photo.';
  FPreview := TImage.Create(Self);
  FPreview.Parent := Body;
  FPreview.Align := alClient;
  FPreview.Stretch := True;
  FPreview.Proportional := True;
  FPreview.Center := True;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := FContent;
  FStatus.Align := alBottom;
  FStatus.Height := 42;
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;
  FStatus.Caption := 'Ready';
  FContent.EnableAlign;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 75;
  FTimer.OnTimer := Tick;
  FWorker := TYoloExampleWorker.Create;
  FChanging := False;
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TButton then TButton(Components[I]).ShowHint := True;
  UpdateControls;
end;

destructor TYoloModelsForm.Destroy;
begin
  CloseSession;
  inherited;
end;

procedure TYoloModelsForm.Configure(const Config: TYoloExampleConfig; const CVLibrary: string);
var
  I: Integer;
  Profile: TYoloProfile;
begin
  RequireCpu(Config <> nil, 'Choose a prepared YOLO kit.');
  FConfig := Config;
  FCVLibrary := CVLibrary;
  FChanging := True;
  try
    FModels.Items.Clear;
    for I := 0 to Config.ProfileCount - 1 do
    begin
      Profile := Config.Profile(I);
      FModels.Items.Add(UI(Profile.ID + ' | ' + YoloTaskName(Profile.Task)));
    end;
    FModels.ItemIndex := 0;
    FContent.Hint := UI(Config.Root);
    FContent.ShowHint := True;
  finally
    FChanging := False;
  end;
  ModelChanged(nil);
  FitContent(nil);
end;

procedure TYoloModelsForm.CloseSession;
begin
  if FTimer <> nil then FTimer.Enabled := False;
  if FWorker <> nil then
  begin
    FWorker.Shutdown;
    FSessionError := FWorker.ShutdownError;
    FreeAndNil(FWorker);
  end;
  FImage := nil;
  FValue := Default(TYoloExampleResult);
  FFrame := Default(TYoloViewFrame);
end;

procedure TYoloModelsForm.FitContent(Sender: TObject);
var
  MinimumWidth, MinimumHeight: Integer;
begin
  if FContent = nil then Exit;
  MinimumWidth := Round(740 * PixelsPerInch / 96);
  MinimumHeight := Round(700 * PixelsPerInch / 96);
  FContent.Width := Max(MinimumWidth, FScroll.ClientWidth - 22);
  FContent.Height := Max(MinimumHeight, FScroll.ClientHeight - 22);
end;

procedure TYoloModelsForm.ClearResult;
begin
  FHasResult := False;
  FValue := Default(TYoloExampleResult);
  FFrame := Default(TYoloViewFrame);
  try
    FDetails.Clear;
    ShowPreview;
  except
    InvalidateDisplay;
    raise;
  end;
end;

procedure TYoloModelsForm.InvalidateDisplay;
begin
  FHasResult := False;
  FImage := nil;
  FImageSHA256 := '';
  FValue := Default(TYoloExampleResult);
  FFrame := Default(TYoloViewFrame);
  { An unsuccessful UI update must leave neither Run nor Save available. }
  try
    FPreview.Picture.Assign(nil);
  except
    { Keep the original exception; disabled actions also cover a failed clear. }
  end;
  try
    FDetails.Clear;
  except
    { The invalidated state remains authoritative if the control cannot clear. }
  end;
  FStatus.Caption := 'Display update failed. Open an image to continue.';
  UpdateControls;
end;

procedure TYoloModelsForm.ReportError(const Text: string);
begin
  FStatus.Caption := UI(Text);
  MessageDlg(UI(Text), mtError, [mbOK], 0);
end;

procedure TYoloModelsForm.UpdateControls;
var
  Idle, HasModel: Boolean;
  Profile: TYoloProfile;
begin
  Idle := (FWorker <> nil) and not FWorker.Busy and not FClosePending;
  HasModel := (FConfig <> nil) and (FModels.ItemIndex >= 0);
  FOpen.Enabled := Idle;
  FModels.Enabled := Idle and HasModel and not FFatal;
  FDevice.Enabled := Idle and not FFatal;
  FRun.Enabled := Idle and HasModel and (FImage <> nil) and not FFatal;
  FStop.Enabled := (FWorker <> nil) and FWorker.Busy;
  FUnload.Enabled := Idle and not FFatal;
  FSave.Enabled := Idle and FHasResult;
  FLabels.Enabled := Idle and not FFatal;
  FView.Enabled := Idle and (FImage <> nil);
  FConfidence.Enabled := False;
  FNMS.Enabled := False;
  FOpacity.Enabled := False;
  FKeypoints.Enabled := False;
  if HasModel then
  begin
    Profile := FConfig.Profile(FModels.ItemIndex);
    FConfidence.Enabled := Idle and not FFatal and
      (Profile.Task in [ytDetection, ytInstances, ytPose, ytOriented]);
    FNMS.Enabled := FConfidence.Enabled and (Profile.NmsKind <> ynSelectedInGraph);
    FOpacity.Enabled := Idle and not FFatal and (Profile.Task in [ytInstances, ytSemantic]);
    FKeypoints.Enabled := Idle and not FFatal and (Profile.Task = ytPose);
  end;
end;

procedure TYoloModelsForm.LoadImage(const FileName: string);
var
  Bytes: TBytes;
  Image: IMat;
  Digest: string;
begin
  RequireCpu((FWorker <> nil) and not FWorker.Busy, 'Wait for the current operation.');
  Bytes := ReadImageBytes(FileName);
  Digest := SHA256Bytes(Bytes);
  Image := DecodeColorImage(Bytes, FCVLibrary);
  RequireCpu((Image.Width <= 4096) and (Image.Height <= 4096),
    'Choose an image no larger than 4096 pixels on either side.');
  try
    PutPreview(Image);
    FImage := Image;
    FImageSHA256 := Digest;
    FHasResult := False;
    FValue := Default(TYoloExampleResult);
    FFrame := Default(TYoloViewFrame);
    FDetails.Clear;
    FStatus.Caption := UI(ExtractFileName(FileName) + ' | ' + IntToStr(Image.Width) +
      ' x ' + IntToStr(Image.Height));
  except
    InvalidateDisplay;
    raise;
  end;
  UpdateControls;
end;

procedure TYoloModelsForm.OpenImage(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.webp|All files|*.*';
    if Dialog.Execute then
      try
        LoadImage({$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName));
      except
        on E: Exception do ReportError(E.Message);
      end;
  finally
    Dialog.Free;
  end;
end;

procedure TYoloModelsForm.ModelChanged(Sender: TObject);
var
  Profile: TYoloProfile;
begin
  if FChanging or (FConfig = nil) then Exit;
  Profile := FConfig.Profile(FModels.ItemIndex);
  FConfidence.Text := UI(Decimal(Profile.Detections.Confidence));
  FNMS.Text := UI(Decimal(Profile.Detections.NmsIoU));
  ClearResult;
  FStatus.Caption := 'Ready';
  UpdateControls;
end;

procedure TYoloModelsForm.DeviceChanged(Sender: TObject);
begin
  if FChanging then Exit;
  ClearResult;
  FStatus.Caption := 'Ready';
  UpdateControls;
end;

function TYoloModelsForm.ViewStyle(const Task: TYoloTask): TYoloViewStyle;
begin
  Result := TYoloViewStyle.Defaults;
  if Task in [ytInstances, ytSemantic] then
    Result.MaskOpacity := FOpacity.Position / 100;
  if Task = ytPose then Result.KeypointConfidence := Fraction(FKeypoints);
  Result.Validate;
end;

procedure TYoloModelsForm.Infer(Sender: TObject);
var
  Job: TYoloExampleJob;
  Bundle: TYoloExampleBundle;
  Target: string;
begin
  try
    RequireCpu(not FFatal, 'Restart the application before running another model.');
    RequireCpu(FImage <> nil, 'Open an image first.');
    Job := Default(TYoloExampleJob);
    Job.Kind := yjInfer;
    Job.Profile := FConfig.Profile(FModels.ItemIndex);
    Target := 'cpu';
    if FDevice.ItemIndex = 1 then Target := NativeCudaArchitecture(0);
    Bundle := FConfig.FindBundle(Job.Profile.ID, Target);
    Job.BundleDirectory := Bundle.Directory;
    Job.ManifestSHA256 := Bundle.ManifestSHA256;
    Job.ManifestBytes := Bundle.ManifestBytes;
    Job.RuntimeDirectory := FConfig.RuntimeDirectory;
    Job.Options := TYoloRunOptions.FromProfile(Job.Profile);
    if FConfidence.Enabled then Job.Options.Confidence := Fraction(FConfidence);
    if FNMS.Enabled then Job.Options.NmsIoU := Fraction(FNMS);
    Job.Image := FImage;
    Job.ImageSHA256 := FImageSHA256;
    Job.PreviewRequested := True;
    Job.ViewStyle := ViewStyle(Job.Profile.Task);
    Job.TextMode := TYoloTextMode(FLabels.ItemIndex);
    ClearResult;
    FWorker.Submit(Job);
    FStatus.Caption := 'Running...';
  except
    on E: Exception do ReportError(E.Message);
  end;
  UpdateControls;
end;

procedure TYoloModelsForm.Stop(Sender: TObject);
begin
  FWorker.Stop;
  FStatus.Caption := 'Stopping...';
end;

procedure TYoloModelsForm.Unload(Sender: TObject);
var
  Job: TYoloExampleJob;
begin
  Job := Default(TYoloExampleJob);
  Job.Kind := yjUnload;
  try
    FWorker.Submit(Job);
    FStatus.Caption := 'Unloading model...';
  except
    on E: Exception do ReportError(E.Message);
  end;
  UpdateControls;
end;

procedure TYoloModelsForm.DisplayChanged(Sender: TObject);
var
  Job: TYoloExampleJob;
begin
  if FChanging or not FHasResult or FWorker.Busy then Exit;
  try
    Job := Default(TYoloExampleJob);
    Job.Kind := yjRender;
    Job.Image := FImage;
    Job.Value := FValue;
    Job.ViewStyle := ViewStyle(Job.Value.Profile.Task);
    Job.TextMode := TYoloTextMode(FLabels.ItemIndex);
    FWorker.Submit(Job);
    FStatus.Caption := 'Updating display...';
  except
    on E: Exception do FStatus.Caption := UI(E.Message);
  end;
  UpdateControls;
end;

procedure TYoloModelsForm.ViewChanged(Sender: TObject);
begin
  try
    ShowPreview;
  except
    on E: Exception do
    begin
      InvalidateDisplay;
      ReportError(E.Message);
    end;
  end;
  UpdateControls;
end;

procedure TYoloModelsForm.ShowPreview;
var
  Image: IMat;
begin
  Image := FImage;
  if FHasResult and (FView.ItemIndex = 0) then Image := FFrame.Image;
  PutPreview(Image);
end;

procedure TYoloModelsForm.PutPreview(const Image: IMat);
var
  Data: Pointer;
  Size: Integer;
  Stream: TMemoryStream;
  Picture: TPicture;
begin
  Picture := TPicture.Create;
  try
    if Image <> nil then
    begin
      Stream := TMemoryStream.Create;
      try
        Data := nil;
        Size := 0;
        try
          RequireCpu(CV.ImgCodecs.ImEncode('.png', Image.Raw, @Data, @Size, 1) and
            (Data <> nil) and (Size > 0), 'Preview encoding failed.');
          Stream.WriteBuffer(Data^, Size);
        finally
          if Data <> nil then
            RequireCpu(CV.ImgCodecs.FreeBuf(Data), 'Preview buffer release failed.');
        end;
        Stream.Position := 0;
        Picture.LoadFromStream(Stream);
      finally
        Stream.Free;
      end;
    end;
    FPreview.Picture.Assign(Picture);
  finally
    Picture.Free;
  end;
end;

procedure TYoloModelsForm.ShowDetails;
var
  I, Count: Integer;
  Lines: TStringList;

  procedure Add(const Text: string);
  begin
    Lines.Add(UI(Text));
  end;

  procedure Item(const Name: string; const Score: Double);
  begin
    Add(Name + '  ' + Decimal(Score * 100, 1) + '%');
  end;

begin
  if not FHasResult then Exit;
  Lines := TStringList.Create;
  try
    Add(FValue.Profile.ID);
    Add(YoloTaskName(FValue.Profile.Task));
    Add(FValue.Device + ' | ' + IntToStr(FValue.Milliseconds) + ' ms');
    Add(IntToStr(FValue.Width) + ' x ' + IntToStr(FValue.Height));
    Add('');
    Count := 0;
    case FValue.Profile.Task of
      ytClassification:
        for I := 0 to High(FValue.Classes) do
          Item(FValue.Classes[I].ClassName, FValue.Classes[I].Score);
      ytDetection:
        begin
          Count := Length(FValue.Detections);
          for I := 0 to Min(Count - 1, 99) do
            Item(FValue.Detections[I].ClassName, FValue.Detections[I].Score);
        end;
      ytInstances:
        begin
          Count := Length(FValue.Instances);
          for I := 0 to Min(Count - 1, 99) do
            Item(FValue.Instances[I].ClassName, FValue.Instances[I].Score);
        end;
      ytPose:
        begin
          Count := Length(FValue.Poses);
          Add(IntToStr(FValue.Profile.KeypointCount) + ' points per pose');
          for I := 0 to Min(Count - 1, 99) do
            Item(FValue.Poses[I].ClassName, FValue.Poses[I].Score);
        end;
      ytOriented:
        begin
          Count := Length(FValue.Oriented);
          for I := 0 to Min(Count - 1, 99) do
            Item(FValue.Oriented[I].ClassName, FValue.Oriented[I].Score);
        end;
      ytSemantic:
        for I := 0 to High(FFrame.Legend) do
          Add(FFrame.Legend[I].Text + ': ' + IntToStr(FFrame.Legend[I].Pixels) + ' pixels');
      ytDepth:
        if FFrame.HasDepthScale then
        begin
          Add('Estimated depth in meters');
          Add(Decimal(FFrame.DepthMinimum, 2) + ' to ' + Decimal(FFrame.DepthMaximum, 2) + ' m');
          Add('Red: nearer. Blue: farther.');
        end;
    end;
    if FValue.Profile.Task in [ytDetection, ytInstances, ytPose, ytOriented] then
    begin
      Add('');
      Add(IntToStr(Count) + ' objects');
      if Count > 100 then Add('First 100 listed; Save includes every object.');
    end;
    FDetails.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TYoloModelsForm.Save(Sender: TObject);
var
  Dialog: TSaveDialog;
  Job: TYoloExampleJob;
begin
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := 'Choose a new result folder name';
    Dialog.Filter := 'Result folder|*.*';
    Dialog.FileName := UI(FValue.Profile.ID + '-' + FormatDateTime('yyyymmdd-hhnnss', Now));
    Dialog.Options := [ofPathMustExist, ofNoChangeDir, ofEnableSizing];
    if not Dialog.Execute then Exit;
    try
      FExportDirectory := {$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName);
      RequireCpu(not DirectoryExists(FExportDirectory) and not FileExists(FExportDirectory),
        'Choose a new folder name. Existing results are never overwritten.');
      Job := Default(TYoloExampleJob);
      Job.Kind := yjExport;
      Job.Image := FImage;
      Job.Preview := FFrame.Image;
      Job.Value := FValue;
      Job.ExportDirectory := FExportDirectory;
      FWorker.Submit(Job);
      FStatus.Caption := 'Saving images, maps and result.json...';
    except
      on E: Exception do ReportError(E.Message);
    end;
  finally
    Dialog.Free;
  end;
  UpdateControls;
end;

procedure TYoloModelsForm.Tick(Sender: TObject);
var
  Outcome: TYoloExampleOutcome;
  Image: IMat;
begin
  if FWorker = nil then Exit;
  if FWorker.Collect(Outcome) then
  begin
    FFatal := FFatal or Outcome.Fatal;
    if Outcome.ErrorText <> '' then
    begin
      FStatus.Caption := UI(Outcome.ErrorText);
      if not FClosePending then ReportError(Outcome.ErrorText);
    end
    else if Outcome.Stopped then
    begin
      if FImage <> nil then
        FStatus.Caption := 'Stopped. You can run again.'
      else
        FStatus.Caption := 'Open an image to continue.';
    end
    else
      case Outcome.Kind of
        yjInfer, yjRender:
          if (FImage = nil) or (Outcome.Value.ImageSHA256 <> FImageSHA256) then
            FStatus.Caption := 'Display update failed. Open an image to continue.'
          else begin
            try
              Image := FImage;
              if FView.ItemIndex = 0 then Image := Outcome.Frame.Image;
              PutPreview(Image);
              FValue := Outcome.Value;
              FFrame := Outcome.Frame;
              FHasResult := True;
              ShowDetails;
              FStatus.Caption := UI(FValue.Profile.ID + ' | ' + FValue.Device + ' | ' +
                IntToStr(FValue.Milliseconds) + ' ms. Ready.');
            except
              on E: Exception do
              begin
                InvalidateDisplay;
                if not FClosePending then ReportError(E.Message);
              end;
            end;
          end;
        yjUnload: FStatus.Caption := 'Model unloaded. You can run again.';
        yjExport: FStatus.Caption := UI('Saved: ' + FExportDirectory);
      end;
    UpdateControls;
    if FClosePending then Close;
  end
  else if FWorker.Busy and not FClosePending and (FImage <> nil) then
    FStatus.Caption := UI(FWorker.Stage);
end;

procedure TYoloModelsForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := (FWorker = nil) or not FWorker.Busy;
  if not CanClose then
  begin
    FClosePending := True;
    FWorker.Stop;
    FStatus.Caption := 'Stopping before closing...';
    UpdateControls;
  end;
end;

end.
