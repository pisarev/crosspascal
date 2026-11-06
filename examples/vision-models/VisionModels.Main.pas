unit VisionModels.Main;

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}

interface

uses
  {$IFDEF FPC}Windows, Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls, {$ELSE}
  Winapi.Windows, System.Classes, System.SysUtils, System.UITypes, Vcl.Controls,
  Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, {$ENDIF} CrossVision.Mat, CrossVision.ML,
  CrossVision.ML.CpuVision;

type
  TVisionWorker = class(TThread)
  private
    FProfile: TCpuVisionProfile;
    FBundle: string;
    FRuntime: string;
    FImagePath: string;
    FImageSHA256: string;
    FAuditDirectory: string;
    FImage: IMat;
    FResult: TCpuVisionResult;
    FErrorText: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const Profile: TCpuVisionProfile;
      const Bundle, Runtime, ImagePath, ImageSHA256: string; const Image: IMat;
      const AuditDirectory: string = '');
  end;

  TVisionModelsForm = class(TForm)
  private
    FProfiles: TArray<TCpuVisionProfile>;
    FProfile: TComboBox;
    FBundle: TEdit;
    FRuntime: TEdit;
    FBrowseBundle: TButton;
    FBrowseRuntime: TButton;
    FOpen: TButton;
    FRun: TButton;
    FSave: TButton;
    FPreview: TImage;
    FOutput: TMemo;
    FStatus: TLabel;
    FTimer: TTimer;
    FWorker: TVisionWorker;
    FImage: IMat;
    FImagePath: string;
    FImageSHA256: string;
    FLastJSON: string;
    FAuditDirectory: string;
    procedure BrowseBundle(Sender: TObject);
    procedure BrowseRuntime(Sender: TObject);
    procedure OpenImage(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure WorkerTick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure SetRunning(const Value: Boolean);
    procedure ShowImage(const Detections: TDetectionArray);
    procedure ShowResult(const Value: TCpuVisionResult);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property AuditDirectory: string read FAuditDirectory write FAuditDirectory;
  end;

function FindDeliveredPath(const RelativePath: string; const IsDirectory: Boolean): string;
function DefaultCatalogPath: string;
function DefaultRuntimeDirectory: string;
function DecodeVisionImage(const Path: string; out SHA256: string): IMat;

implementation

uses
  {$IFDEF FPC}Math, Types, Dialogs, IntfGraphics, FPImage, {$ELSE}
  System.Math, System.Types, Vcl.Dialogs, Vcl.FileCtrl, {$ENDIF} CrossPascal.SHA256,
  OpenCVTypes, OpenCVConsts, OpenCV;

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

function FindDeliveredPath(const RelativePath: string; const IsDirectory: Boolean): string;
var
  Current, Parent, Candidate: string;
  I: Integer;
begin
  Result := '';
  Current := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  for I := 0 to 9 do
  begin
    Candidate := ExpandFileName(IncludeTrailingPathDelimiter(Current) + RelativePath);
    if (IsDirectory and DirectoryExists(Candidate)) or
      (not IsDirectory and FileExists(Candidate)) then Exit(Candidate);
    Parent := ExtractFileDir(Current);
    if SameText(Parent, Current) then Break;
    Current := Parent;
  end;
end;

function DefaultCatalogPath: string;
begin
  Result := FindDeliveredPath('models.json', False);
  if Result = '' then
    Result := FindDeliveredPath('crosspascal\examples\vision-models\models.json', False);
end;

function DefaultRuntimeDirectory: string;
begin
  Result := FindDeliveredPath('crosspascal-tvm\runtime\windows-x64-cuda', True);
end;

function DecodeVisionImage(const Path: string; out SHA256: string): IMat;
var
  Stream: TFileStream;
  Bytes: TBytes;
  Raw: TMat;
begin
  Result := nil;
  SHA256 := '';
  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size <= 0) or (Stream.Size > Int64(64) * 1024 * 1024) then
      raise Exception.Create('The selected image must be between 1 byte and 64 MiB.');
    SetLength(Bytes, Integer(Stream.Size));
    Stream.ReadBuffer(Bytes[0], Length(Bytes));
    SHA256 := SHA256Bytes(Bytes);
    Raw := nil;
    try
      if not CV.ImgCodecs.ImDecode(@Bytes[0], Length(Bytes), IMREAD_COLOR, @Raw) then
        raise Exception.Create('Cannot decode the image: ' + CV.GetError);
      if Raw = nil then raise Exception.Create('The image decoder returned no image.');
      Result := WrapMat(Raw, True);
      Raw := nil;
      if Result.IsEmpty or (Result.Channels <> 3) or
        (Int64(Result.Width) * Result.Height > 40000000) then
          raise Exception.Create('The image must be a color image of at most 40 megapixels.');
    finally
      if Raw <> nil then CV.Core.DeleteMat(@Raw);
    end;
  finally
    Stream.Free;
  end;
end;

constructor TVisionWorker.Create(const Profile: TCpuVisionProfile;
  const Bundle, Runtime, ImagePath, ImageSHA256: string; const Image: IMat;
  const AuditDirectory: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FProfile := Profile;
  FBundle := Bundle;
  FRuntime := Runtime;
  FImagePath := ImagePath;
  FImageSHA256 := ImageSHA256;
  FImage := Image;
  FAuditDirectory := AuditDirectory;
end;

procedure TVisionWorker.Execute;
begin
  try
    FResult := RunCpuVision(FProfile, FBundle, FRuntime, FImagePath, FImageSHA256, FImage,
      nil, FAuditDirectory);
  except
    on E: Exception do FErrorText := E.ClassName + ': ' + E.Message;
  end;
  FImage := nil;
end;

constructor TVisionModelsForm.Create(AOwner: TComponent);
var
  TopPanel, ImagePanel: TPanel;
  Splitter: TSplitter;
  I: Integer;
  CatalogPath: string;

  procedure AddLabel(const Text: string; const X, Y: Integer);
  var
    LabelControl: TLabel;
  begin
    LabelControl := TLabel.Create(Self);
    LabelControl.Parent := TopPanel;
    LabelControl.Caption := Text;
    LabelControl.SetBounds(X, Y, 920, 22);
  end;

  function AddButton(const Text: string; const X, Y, W: Integer;
    const Handler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := TopPanel;
    Result.Caption := Text;
    Result.SetBounds(X, Y, W, 28);
    Result.OnClick := Handler;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal CPU Vision Models';
  Position := poScreenCenter;
  ClientWidth := 1000;
  ClientHeight := 780;
  Constraints.MinWidth := 850;
  Constraints.MinHeight := 650;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  OnCloseQuery := CheckClose;
  CatalogPath := DefaultCatalogPath;
  if CatalogPath = '' then
    raise Exception.Create('models.json was not found. Keep the delivered example folder together.');
  FProfiles := LoadCpuVisionProfiles(CatalogPath);
  TopPanel := TPanel.Create(Self);
  TopPanel.Parent := Self;
  TopPanel.Align := alTop;
  TopPanel.Height := 240;
  TopPanel.BevelOuter := bvNone;
  AddLabel('Model profile (CPU / float32 / batch 1)', 16, 12);
  FProfile := TComboBox.Create(Self);
  FProfile.Parent := TopPanel;
  FProfile.Style := csDropDownList;
  FProfile.SetBounds(16, 36, 390, 28);
  for I := 0 to High(FProfiles) do FProfile.Items.Add(FProfiles[I].Title);
  FProfile.ItemIndex := 0;
  FOpen := AddButton('Open image...', 422, 36, 120, OpenImage);
  FRun := AddButton('Run on CPU', 554, 36, 120, RunClick);
  FSave := AddButton('Save result...', 686, 36, 120, SaveClick);
  FSave.Enabled := False;
  AddLabel('Converted model bundle (manifest.json, model DLL and DLL.inputs)', 16, 80);
  FBundle := TEdit.Create(Self);
  FBundle.Parent := TopPanel;
  FBundle.SetBounds(16, 104, 852, 27);
  FBundle.Anchors := [akLeft, akTop, akRight];
  FBrowseBundle := AddButton('Browse...', 880, 104, 104, BrowseBundle);
  FBrowseBundle.Anchors := [akTop, akRight];
  AddLabel('Pinned TVM runtime directory (the CPU loader uses three of the supplied DLLs)', 16, 144);
  FRuntime := TEdit.Create(Self);
  FRuntime.Parent := TopPanel;
  FRuntime.SetBounds(16, 168, 852, 27);
  FRuntime.Anchors := [akLeft, akTop, akRight];
  FRuntime.Text := DefaultRuntimeDirectory;
  FBrowseRuntime := AddButton('Browse...', 880, 168, 104, BrowseRuntime);
  FBrowseRuntime.Anchors := [akTop, akRight];
  FStatus := TLabel.Create(Self);
  FStatus.Parent := TopPanel;
  FStatus.AutoSize := False;
  FStatus.SetBounds(16, 204, 968, 32);
  FStatus.Anchors := [akLeft, akTop, akRight];
  FStatus.WordWrap := True;
  FStatus.Caption := 'Select a profile and converted bundle, then open an image.';
  FOutput := TMemo.Create(Self);
  FOutput.Parent := Self;
  FOutput.Align := alBottom;
  FOutput.Height := 220;
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssBoth;
  FOutput.WordWrap := False;
  FOutput.Font.Name := 'Consolas';
  FOutput.Font.Size := 10;
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Self;
  Splitter.Align := alBottom;
  Splitter.Height := 5;
  ImagePanel := TPanel.Create(Self);
  ImagePanel.Parent := Self;
  ImagePanel.Align := alClient;
  ImagePanel.BevelOuter := bvNone;
  FPreview := TImage.Create(Self);
  FPreview.Parent := ImagePanel;
  FPreview.Align := alClient;
  FPreview.Proportional := True;
  FPreview.Stretch := True;
  FPreview.Center := True;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 100;
  FTimer.OnTimer := WorkerTick;
  SetRunning(False);
end;

destructor TVisionModelsForm.Destroy;
begin
  if FWorker <> nil then
  begin
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
  FImage := nil;
  inherited Destroy;
end;

procedure TVisionModelsForm.BrowseBundle(Sender: TObject);
var
  Directory: string;
begin
  Directory := FBundle.Text;
  if ChooseBundleDirectory('Select a converted CPU model bundle', Directory, Self) then
    FBundle.Text := Directory;
end;

procedure TVisionModelsForm.BrowseRuntime(Sender: TObject);
var
  Directory: string;
begin
  Directory := FRuntime.Text;
  if ChooseBundleDirectory('Select the pinned TVM runtime directory', Directory, Self) then
    FRuntime.Text := Directory;
end;

procedure TVisionModelsForm.OpenImage(Sender: TObject);
var
  Dialog: TOpenDialog;
  Loaded: IMat;
  Hash: string;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Open an image for CPU inference';
    Dialog.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.webp|All files|*.*';
    Dialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    if not Dialog.Execute then Exit;
    Loaded := DecodeVisionImage(Dialog.FileName, Hash);
    FImage := Loaded;
    FImagePath := ExpandFileName(Dialog.FileName);
    FImageSHA256 := Hash;
    FLastJSON := '';
    FOutput.Clear;
    ShowImage(nil);
    FStatus.Caption := Format('%s: %d x %d. Select a matching bundle and click Run on CPU.',
      [ExtractFileName(FImagePath), FImage.Width, FImage.Height]);
    SetRunning(False);
  finally
    Dialog.Free;
  end;
end;

procedure TVisionModelsForm.SetRunning(const Value: Boolean);
begin
  FProfile.Enabled := not Value;
  FBundle.Enabled := not Value;
  FRuntime.Enabled := not Value;
  FBrowseBundle.Enabled := not Value;
  FBrowseRuntime.Enabled := not Value;
  FOpen.Enabled := not Value;
  FRun.Enabled := not Value and (FImage <> nil);
  FSave.Enabled := not Value and (FLastJSON <> '');
end;

procedure TVisionModelsForm.RunClick(Sender: TObject);
begin
  if FWorker <> nil then Exit;
  if (FProfile.ItemIndex < 0) or (FImage = nil) then Exit;
  if not DirectoryExists(FBundle.Text) then
    raise Exception.Create('Select an existing converted bundle directory.');
  if not DirectoryExists(FRuntime.Text) then
    raise Exception.Create('Select the supplied TVM runtime directory.');
  FLastJSON := '';
  FOutput.Clear;
  ShowImage(nil);
  FWorker := TVisionWorker.Create(FProfiles[FProfile.ItemIndex],
    ExpandFileName(FBundle.Text), ExpandFileName(FRuntime.Text), FImagePath, FImageSHA256,
    FImage, FAuditDirectory);
  SetRunning(True);
  FStatus.Caption := 'Checking inputs and running on CPU. Close is available after the worker exits.';
  FTimer.Enabled := True;
  FWorker.Start;
end;

procedure TVisionModelsForm.WorkerTick(Sender: TObject);
var
  ErrorText: string;
begin
  if (FWorker = nil) or (WaitForSingleObject(FWorker.Handle, 0) <> WAIT_OBJECT_0) then Exit;
  FTimer.Enabled := False;
  FWorker.WaitFor;
  ErrorText := FWorker.FErrorText;
  try
    if ErrorText = '' then
    begin
      FLastJSON := FWorker.FResult.JSONText;
      ShowResult(FWorker.FResult);
      FStatus.Caption := 'CPU inference completed; model resources were released. Save the result if needed.';
    end
    else begin
      FOutput.Lines.Text := ErrorText;
      FStatus.Caption := 'The run failed. No successful result was recorded.';
    end;
  finally
    FreeAndNil(FWorker);
    SetRunning(False);
  end;
end;

procedure TVisionModelsForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then
    MessageDlg('The CPU worker is still running. Wait for it to finish before closing.',
      mtInformation, [mbOK], 0);
end;

procedure TVisionModelsForm.ShowImage(const Detections: TDetectionArray);
var
  Bitmap: TBitmap;
  Source: PByte;
  Y: Integer;
  {$IFDEF FPC}
  Surface: TLazIntfImage;
  Pixel: TFPColor;
  X: Integer;
  {$ELSE}
  Destination: PByte;
  {$ENDIF}
  Item: TDetection;
begin
  if (FImage = nil) or FImage.IsEmpty then Exit;
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(FImage.Width, FImage.Height);
    {$IFDEF FPC}
    Surface := Bitmap.CreateIntfImage;
    try
      Pixel.Alpha := High(Word);
      for Y := 0 to FImage.Height - 1 do
      begin
        Source := PByte(NativeUInt(FImage.DataPtr) + NativeUInt(Y) * NativeUInt(FImage.Step));
        for X := 0 to FImage.Width - 1 do
        begin
          Pixel.Blue := Source^ * 257;
          Inc(Source);
          Pixel.Green := Source^ * 257;
          Inc(Source);
          Pixel.Red := Source^ * 257;
          Inc(Source);
          Surface.Colors[X, Y] := Pixel;
        end;
      end;
      Bitmap.LoadFromIntfImage(Surface);
    finally
      Surface.Free;
    end;
    {$ELSE}
    for Y := 0 to FImage.Height - 1 do
    begin
      Source := PByte(NativeUInt(FImage.DataPtr) + NativeUInt(Y) * NativeUInt(FImage.Step));
      Destination := Bitmap.ScanLine[Y];
      System.Move(Source^, Destination^, FImage.Width * 3);
    end;
    {$ENDIF}
    Bitmap.Canvas.Pen.Color := clLime;
    Bitmap.Canvas.Pen.Width := 2;
    Bitmap.Canvas.Brush.Style := bsClear;
    Bitmap.Canvas.Font.Color := clLime;
    Bitmap.Canvas.Font.Size := 12;
    for Item in Detections do
    begin
      Bitmap.Canvas.Rectangle(Item.Box);
      Bitmap.Canvas.TextOut(Max(0, Item.Box.Left), Max(0, Item.Box.Top),
        Format('%d  %.3f', [Item.ClassId, Item.Score]));
    end;
    FPreview.Picture.Assign(Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TVisionModelsForm.ShowResult(const Value: TCpuVisionResult);
var
  Item: TClassification;
  DetectionItem: TDetection;
begin
  FOutput.Lines.BeginUpdate;
  try
    FOutput.Lines.Clear;
    FOutput.Lines.Add(Format('%s | CPU | %d ms | image %d x %d',
      [Value.ProfileID, Value.ElapsedMilliseconds, Value.Width, Value.Height]));
    if Length(Value.Classifications) > 0 then
    begin
      FOutput.Lines.Add('Top five class IDs and unmodified model scores:');
      for Item in Value.Classifications do
        FOutput.Lines.Add(Format('class %d    score %.8g', [Item.ClassId, Item.Score]));
    end
    else begin
      FOutput.Lines.Add(Format('%d detections above the profile threshold:', [Length(Value.Detections)]));
      for DetectionItem in Value.Detections do
        FOutput.Lines.Add(Format('class %d    score %.6f    [%d, %d, %d, %d]',
          [DetectionItem.ClassId, DetectionItem.Score, DetectionItem.Box.Left,
          DetectionItem.Box.Top, DetectionItem.Box.Right, DetectionItem.Box.Bottom]));
    end;
    FOutput.Lines.Add('Model SHA-256: ' + Value.ModelSHA256);
    FOutput.Lines.Add('Image SHA-256: ' + Value.InputSHA256);
    FOutput.Lines.Add('Class IDs follow the selected source model. No class-name mapping is guessed.');
  finally
    FOutput.Lines.EndUpdate;
  end;
  ShowImage(Value.Detections);
end;

procedure TVisionModelsForm.SaveClick(Sender: TObject);
var
  Dialog: TSaveDialog;
begin
  if FLastJSON = '' then Exit;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := 'Save a new CPU inference result';
    Dialog.Filter := 'JSON files|*.json';
    Dialog.DefaultExt := 'json';
    Dialog.FileName := 'cpu-vision-result.json';
    Dialog.Options := [ofPathMustExist, ofEnableSizing];
    if Dialog.Execute then
    begin
      WriteCpuVisionReport(Dialog.FileName, FLastJSON);
      FStatus.Caption := 'Saved ' + ExpandFileName(Dialog.FileName);
    end;
  finally
    Dialog.Free;
  end;
end;

end.
