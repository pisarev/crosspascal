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
    procedure FitOnScreen(Sender: TObject);
    procedure BrowseBundle(Sender: TObject);
    procedure BrowseRuntime(Sender: TObject);
    procedure OpenImage(Sender: TObject);
    procedure LoadImage(const Path: string);
    procedure SelectProfile(Sender: TObject);
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
  OpenCVTypes, OpenCVConsts, OpenCV, ExampleDefaults;

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
    if FAuditDirectory = '' then
      FResult := RunVision(FProfile, FBundle, FRuntime, FImagePath, FImageSHA256, FImage)
    else
      FResult := RunCpuVision(FProfile, FBundle, FRuntime, FImagePath, FImageSHA256, FImage,
        nil, FAuditDirectory);
  except
    on E: Exception do FErrorText := E.ClassName + ': ' + E.Message;
  end;
  FImage := nil;
end;

procedure TVisionModelsForm.FitOnScreen(Sender: TObject);
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
  GetWindowRect(FProfile.Handle, Area);
  FProfile.Top := (FProfile.Parent.ClientHeight - (Area.Bottom - Area.Top)) div 2;
end;

constructor TVisionModelsForm.Create(AOwner: TComponent);
var
  Content, Header, Row, ImagePanel, ResultsPanel, Footer: TPanel;
  Splitter: TSplitter;
  ProfileField: TPanel;
  I: Integer;
  CatalogPath: string;

  function Panel(Parent: TWinControl; Alignment: TAlign; Height: Integer): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.BevelOuter := bvNone;
    Result.Caption := '';
    if Alignment = alTop then Result.Top := 30000;
    if Alignment in [alTop, alBottom] then Result.Height := Height;
    if Alignment in [alLeft, alRight] then Result.Width := Height;
    Result.Align := Alignment;
    Result.Parent := Parent;
  end;

  procedure LabelOn(Parent: TWinControl; const Text: string);
  var
    Heading: TLabel;
  begin
    Heading := TLabel.Create(Self);
    Heading.Parent := Parent;
    Heading.AutoSize := False;
    Heading.Align := alTop;
    Heading.Height := 24;
    Heading.Caption := Text;
    Heading.Layout := tlCenter;
  end;

  function ButtonOn(Parent: TWinControl; const Text: string; Width: Integer;
    const Handler: TNotifyEvent): TButton;
  var
    Cell: TPanel;
  begin
    Cell := Panel(Parent, alRight, Width);
    Cell.BorderWidth := 0;
    Cell.Width := 128;
    Cell.TabStop := False;
    Result := TButton.Create(Self);
    Result.Parent := Cell;
    Result.SetBounds(4, 2, 120, 32);
    Result.TabOrder := 0;
    Result.Caption := Text;
    Result.OnClick := Handler;
  end;

  function FolderRow(const Title, Value: string; Handler: TNotifyEvent; out Browse: TButton): TEdit;
  var
    Field, Line: TPanel;
  begin
    Field := Panel(Header, alTop, 64);
    Field.Top := (Header.ControlCount - 1) * 64;
    LabelOn(Field, Title);
    Line := Panel(Field, alTop, 36);
    Line.Top := 24;
    Browse := ButtonOn(Line, 'Browse...', 100, Handler);
    Field := Panel(Line, alClient, 0);
    Field.BorderWidth := 2;
    Result := TEdit.Create(Self);
    Result.Parent := Field;
    Result.Align := alClient;
    Result.AutoSize := False;
    Result.Text := Value;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal Vision Models';
  Position := poScreenCenter;
  OnShow := FitOnScreen;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 1080;
  ClientHeight := 740;
  Constraints.MinWidth := 800;
  Constraints.MinHeight := 600;
  OnCloseQuery := CheckClose;
  CatalogPath := DefaultCatalogPath;
  if CatalogPath = '' then
    raise Exception.Create('models.json was not found. Keep the delivered example folder together.');
  FProfiles := LoadCpuVisionProfiles(CatalogPath);
  Content := Panel(Self, alClient, 0);
  Content.DisableAlign;
  Content.BorderWidth := 12;
  Header := Panel(Content, alTop, 196);
  Header.DisableAlign;
  Row := Panel(Header, alTop, 64);
  Row.Top := 0;
  LabelOn(Row, 'Model profile');
  Row := Panel(Row, alClient, 0);
  Row.DisableAlign;
  Row.BorderWidth := 2;
  FSave := ButtonOn(Row, 'Save result...', 124, SaveClick);
  FRun := ButtonOn(Row, 'Run inference', 124, RunClick);
  FOpen := ButtonOn(Row, 'Open image...', 124, OpenImage);
  ProfileField := Panel(Row, alClient, 0);
  FProfile := TComboBox.Create(Self);
  FProfile.Parent := ProfileField;
  FProfile.SetBounds(0, 0, ProfileField.ClientWidth, 24);
  FProfile.Anchors := [akLeft, akTop, akRight];
  FProfile.Style := csDropDownList;
  for I := 0 to High(FProfiles) do FProfile.Items.Add(FProfiles[I].Title);
  FProfile.ItemIndex := 0;
  FProfile.OnChange := SelectProfile;
  FOpen.Parent.Left := 0;
  FRun.Parent.Left := 128;
  FSave.Parent.Left := 256;
  Row.EnableAlign;
  FBundle := FolderRow('Converted model folder', '', BrowseBundle, FBrowseBundle);
  FRuntime := FolderRow('TVM runtime folder', DefaultRuntimeDirectory,
    BrowseRuntime, FBrowseRuntime);
  Header.EnableAlign;
  Footer := Panel(Content, alBottom, 40);
  Footer.Top := 30000;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.Align := alClient;
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;
  FStatus.Layout := tlCenter;
  FStatus.Caption := 'Choose a model and open an image to begin.';
  ResultsPanel := Panel(Content, alBottom, 180);
  ResultsPanel.Top := 20000;
  LabelOn(ResultsPanel, 'Result');
  FOutput := TMemo.Create(Self);
  FOutput.Parent := ResultsPanel;
  FOutput.Align := alClient;
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssBoth;
  FOutput.WordWrap := False;
  FOutput.Font.Name := 'Consolas';
  FOutput.Font.Size := 10;
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Content;
  Splitter.Align := alBottom;
  Splitter.Height := 8;
  Splitter.Top := 10000;
  ImagePanel := Panel(Content, alClient, 0);
  LabelOn(ImagePanel, 'Image');
  FPreview := TImage.Create(Self);
  FPreview.Parent := ImagePanel;
  FPreview.Align := alClient;
  FPreview.Proportional := True;
  FPreview.Stretch := True;
  FPreview.Center := True;
  Content.EnableAlign;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 100;
  FTimer.OnTimer := WorkerTick;
  if HasPreparedExample then
  begin
    for I := 0 to High(FProfiles) do
      if FProfiles[I].ID = PreparedValue('profile', 'resnet50') then FProfile.ItemIndex := I;
    SelectProfile(nil);
    if PreparedPath('image') <> '' then LoadImage(PreparedPath('image'));
  end;
  Header.TabOrder := 0;
  ResultsPanel.TabOrder := 1;
  ImagePanel.TabOrder := 2;
  Footer.TabOrder := 3;
  ProfileField.TabOrder := 0;
  FProfile.TabOrder := 0;
  FOpen.Parent.TabOrder := 1;
  FRun.Parent.TabOrder := 2;
  FSave.Parent.TabOrder := 3;
  FBundle.Parent.TabOrder := 0;
  FBundle.TabOrder := 0;
  FBrowseBundle.Parent.TabOrder := 1;
  FRuntime.Parent.TabOrder := 0;
  FRuntime.TabOrder := 0;
  FBrowseRuntime.Parent.TabOrder := 1;
  FOutput.TabOrder := 0;
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
  if ChooseBundleDirectory('Select a converted CPU or CUDA model bundle', Directory, Self) then
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
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Open an image for inference';
    Dialog.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.webp|All files|*.*';
    Dialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    if not Dialog.Execute then Exit;
    LoadImage(Dialog.FileName);
  finally
    Dialog.Free;
  end;
end;

procedure TVisionModelsForm.LoadImage(const Path: string);
var
  Loaded: IMat;
  Hash: string;
begin
  Loaded := DecodeVisionImage(Path, Hash);
  FImage := Loaded;
  FImagePath := ExpandFileName(Path);
  FImageSHA256 := Hash;
  FLastJSON := '';
  FOutput.Clear;
  ShowImage(nil);
  FStatus.Caption := Format('%s: %d x %d. Select a matching bundle and click Run inference.',
    [ExtractFileName(FImagePath), FImage.Width, FImage.Height]);
  SetRunning(False);
end;

procedure TVisionModelsForm.SelectProfile(Sender: TObject);
var
  Directory: string;
begin
  if not HasPreparedExample or (FProfile.ItemIndex < 0) then Exit;
  Directory := PreparedPath('model_' + FProfiles[FProfile.ItemIndex].ID);
  if Directory <> '' then FBundle.Text := Directory;
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
  FStatus.Caption := 'Checking inputs and running inference. Wait for the run to finish before closing.';
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
      FStatus.Caption := 'Inference completed on ' + UpperCase(FWorker.FResult.Device) + '.';
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
    MessageDlg('Inference is still running. Wait for it to finish before closing.',
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
    FOutput.Lines.Add(Format('%s | %s | %d ms | image %d x %d',
      [Value.ProfileID, UpperCase(Value.Device), Value.ElapsedMilliseconds, Value.Width, Value.Height]));
    if Value.Device = 'cuda' then
      FOutput.Lines.Add(Value.DeviceName + ' (' + Value.CudaArchitecture + ')');
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
    Dialog.Title := 'Save an inference result';
    Dialog.Filter := 'JSON files|*.json';
    Dialog.DefaultExt := 'json';
    Dialog.FileName := 'vision-result.json';
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
