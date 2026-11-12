unit PaddleOcr.Main;

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Windows, Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls,
  {$ELSE}
  Winapi.Windows, System.Classes, System.SysUtils, System.UITypes, Vcl.Controls,
  Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls,
  {$ENDIF}
  CrossVision.Mat, TVM.PaddleOcr, PaddleOcr.Run;

type
  TPaddleWorker = class(TThread)
  private
    FDetector: string;
    FRecognizer: string;
    FRuntime: string;
    FClipper: string;
    FDigest: string;
    FImage: IMat;
    function Stopping: Boolean;
  protected
    procedure Execute; override;
  public
    Value: TPaddleResult;
    ErrorText: string;
    constructor Create(const Detector, Recognizer, Runtime, Clipper, Digest: string; const Image: IMat);
  end;

  TPaddleOcrForm = class(TForm)
  private
    FDetector: TEdit;
    FRecognizer: TEdit;
    FRuntime: TEdit;
    FOpen: TButton;
    FRead: TButton;
    FStop: TButton;
    FSave: TButton;
    FBrowse: array[0..2] of TButton;
    FPreview: TImage;
    FText: TMemo;
    FStatus: TLabel;
    FTimer: TTimer;
    FWorker: TPaddleWorker;
    FImage: IMat;
    FDigest: string;
    FCVLibrary: string;
    FClipper: string;
    FJSON: string;
    procedure Browse(Sender: TObject);
    procedure OpenImage(Sender: TObject);
    procedure LoadImage(const FileName: string);
    procedure ReadImage(Sender: TObject);
    procedure StopReading(Sender: TObject);
    procedure SaveResult(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure FitOnScreen(Sender: TObject);
    procedure SetRunning(const Value: Boolean);
    procedure DrawImage(const Lines: TPaddleTextLines);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  {$IFDEF FPC}
  Math, Types, Dialogs, IntfGraphics, FPImage,
  {$ELSE}
  System.Math, System.Types, Vcl.Dialogs, Vcl.FileCtrl,
  {$ENDIF}
  ExampleDefaults, TVM.CpuGraph;

function UI(const Value: string): {$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};
begin
  {$IFDEF FPC}
  Result := UTF8Encode(Value);
  {$ELSE}
  Result := Value;
  {$ENDIF}
end;

function EditValue(const Edit: TEdit): string;
begin
  {$IFDEF FPC}
  Result := UTF8Decode(Edit.Text);
  {$ELSE}
  Result := Edit.Text;
  {$ENDIF}
end;

constructor TPaddleWorker.Create(const Detector, Recognizer, Runtime, Clipper, Digest: string;
  const Image: IMat);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FDetector := Detector;
  FRecognizer := Recognizer;
  FRuntime := Runtime;
  FClipper := Clipper;
  FDigest := Digest;
  FImage := Image;
end;

function TPaddleWorker.Stopping: Boolean;
begin
  Result := Terminated;
end;

procedure TPaddleWorker.Execute;
begin
  try
    Value := RunPaddle(FDetector, FRecognizer, FRuntime, FClipper, FDigest, FImage, Stopping);
  except
    on E: Exception do ErrorText := E.ClassName + ': ' + E.Message;
  end;
  FImage := nil;
end;

constructor TPaddleOcrForm.Create(AOwner: TComponent);
var
  Content, Header, Toolbar, Row, Field, ResultPanel, Footer: TPanel;
  Splitter: TSplitter;
  LabelControl: TLabel;
  I: Integer;
  Edits: array[0..2] of TEdit;
const Labels: array[0..2] of string = ('Text detector folder', 'Text recognizer folder', 'TVM runtime folder');
  ActionWidth = 120;
  ActionHeight = 32;
  ActionCellWidth = ActionWidth + 8;

  function Panel(const Parent: TWinControl; const Align: TAlign; const Size: Integer): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Caption := '';
    Result.BevelOuter := bvNone;
    if Align = alTop then Result.Top := 30000;
    if Align in [alTop, alBottom] then Result.Height := Size;
    if Align in [alLeft, alRight] then Result.Width := Size;
    Result.Align := Align;
    Result.Parent := Parent;
  end;

  function Button(const Text: string; const Handler: TNotifyEvent): TButton;
  var
    Cell: TPanel;
  begin
    Cell := Panel(Toolbar, alLeft, ActionCellWidth);
    Cell.Left := 30000;
    Result := TButton.Create(Self);
    Result.Parent := Cell;
    Result.SetBounds(0, 4, ActionWidth, ActionHeight);
    Result.Caption := UI(Text);
    Result.OnClick := Handler;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal PaddleOCR';
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 1080;
  ClientHeight := 760;
  Position := poScreenCenter;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 580;
  OnShow := FitOnScreen;
  OnCloseQuery := CheckClose;
  FCVLibrary := FindPaddlePath('crosspascal-opencv\bin\crosscv.dll', False);
  FClipper := PreparedPath('clipper',
    FindPaddlePath('crosspascal-tvm\runtime\paddleocr\ppocr_db_jt_round.dll', False));
  Content := Panel(Self, alClient, 0);
  Content.BorderWidth := 12;
  Content.DisableAlign;
  Header := Panel(Content, alTop, 178);
  Header.DisableAlign;
  Toolbar := Panel(Header, alTop, 44);
  Toolbar.Top := 0;
  Toolbar.DisableAlign;
  FOpen := Button('Open image...', OpenImage);
  FRead := Button('Read text', ReadImage);
  FStop := Button('Stop', StopReading);
  FSave := Button('Save result...', SaveResult);
  FOpen.Parent.Left := 0;
  FRead.Parent.Left := ActionCellWidth;
  FStop.Parent.Left := 2 * ActionCellWidth;
  FSave.Parent.Left := 3 * ActionCellWidth;
  Toolbar.EnableAlign;
  for I := 0 to 2 do
  begin
    Row := Panel(Header, alTop, 42);
    Row.Top := 44 + I * 42;
    Row.DisableAlign;
    LabelControl := TLabel.Create(Self);
    LabelControl.Parent := Row;
    LabelControl.AutoSize := False;
    LabelControl.Align := alLeft;
    LabelControl.Width := 165;
    LabelControl.Layout := tlCenter;
    LabelControl.Caption := UI(Labels[I]);
    Field := Panel(Row, alRight, 128);
    FBrowse[I] := TButton.Create(Self);
    FBrowse[I].Parent := Field;
    FBrowse[I].SetBounds(4, 5, ActionWidth, ActionHeight);
    FBrowse[I].Caption := 'Browse...';
    FBrowse[I].Tag := I;
    FBrowse[I].OnClick := Browse;
    Field := Panel(Row, alClient, 0);
    Field.BorderWidth := 5;
    Edits[I] := TEdit.Create(Self);
    Edits[I].Parent := Field;
    Edits[I].AutoSize := False;
    Edits[I].Align := alClient;
    Row.EnableAlign;
  end;
  FDetector := Edits[0];
  FRecognizer := Edits[1];
  FRuntime := Edits[2];
  FDetector.Text := UI(PreparedPath('detector'));
  FRecognizer.Text := UI(PreparedPath('recognizer'));
  FRuntime.Text := UI(PreparedPath('runtime',
    FindPaddlePath('crosspascal-tvm\runtime\windows-x64-cuda', True)));
  Header.EnableAlign;
  Footer := Panel(Content, alBottom, 38);
  Footer.Top := 30000;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.Align := alClient;
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;
  FStatus.Layout := tlCenter;
  FStatus.Caption := 'Open an image, then read its text.';
  ResultPanel := Panel(Content, alBottom, 190);
  ResultPanel.Top := 20000;
  FText := TMemo.Create(Self);
  FText.Parent := ResultPanel;
  FText.Align := alClient;
  FText.ReadOnly := True;
  FText.ScrollBars := ssBoth;
  FText.WordWrap := False;
  FText.Font.Name := 'Segoe UI';
  FText.Font.Size := 11;
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Content;
  Splitter.Align := alBottom;
  Splitter.Height := 8;
  Splitter.Top := 10000;
  FPreview := TImage.Create(Self);
  FPreview.Parent := Content;
  FPreview.Align := alClient;
  FPreview.Stretch := True;
  FPreview.Proportional := True;
  FPreview.Center := True;
  Content.EnableAlign;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.Enabled := False;
  FTimer.OnTimer := Tick;
  if PreparedPath('image') <> '' then LoadImage(PreparedPath('image'));
  SetRunning(False);
end;

destructor TPaddleOcrForm.Destroy;
begin
  if FWorker <> nil then
  begin
    FWorker.Terminate;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
  FImage := nil;
  inherited;
end;

procedure TPaddleOcrForm.FitOnScreen(Sender: TObject);
var
  Area: TRect;
begin
  Area := Monitor.WorkareaRect;
  Constraints.MinWidth := Min(Constraints.MinWidth, Area.Right - Area.Left);
  Constraints.MinHeight := Min(Constraints.MinHeight, Area.Bottom - Area.Top);
  Width := Min(Width, Area.Right - Area.Left);
  Height := Min(Height, Area.Bottom - Area.Top);
  Left := Max(Area.Left, Min(Left, Area.Right - Width));
  Top := Max(Area.Top, Min(Top, Area.Bottom - Height));
end;

procedure TPaddleOcrForm.Browse(Sender: TObject);
var
  Edit: TEdit;
  Path: string;
  {$IFDEF FPC}
  Dialog: TSelectDirectoryDialog;
  {$ENDIF}
begin
  case TButton(Sender).Tag of
    0: Edit := FDetector;
    1: Edit := FRecognizer;
  else
    Edit := FRuntime;
  end;
  Path := EditValue(Edit);
  {$IFDEF FPC}
  Dialog := TSelectDirectoryDialog.Create(Self);
  try
    Dialog.InitialDir := UI(Path);
    if Dialog.Execute then Path := UTF8Decode(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  {$ELSE}
  if not SelectDirectory('Select a model or runtime folder', '', Path, [sdNewUI, sdNewFolder], Self) then
    Exit;
  {$ENDIF}
  Edit.Text := UI(Path);
end;

procedure TPaddleOcrForm.LoadImage(const FileName: string);
begin
  FImage := ReadPaddleImage(FileName, FCVLibrary, FDigest);
  FJSON := '';
  FText.Clear;
  DrawImage(nil);
  FStatus.Caption := UI(Format('%s  |  %d × %d', [ExtractFileName(FileName), FImage.Width, FImage.Height]));
  SetRunning(False);
end;

procedure TPaddleOcrForm.OpenImage(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.webp|All files|*.*';
    Dialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    if Dialog.Execute then LoadImage({$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName));
  finally
    Dialog.Free;
  end;
end;

procedure TPaddleOcrForm.SetRunning(const Value: Boolean);
var
  I: Integer;
begin
  FOpen.Enabled := not Value;
  FRead.Enabled := not Value and (FImage <> nil);
  FStop.Enabled := Value;
  FSave.Enabled := not Value and (FJSON <> '');
  FDetector.Enabled := not Value;
  FRecognizer.Enabled := not Value;
  FRuntime.Enabled := not Value;
  for I := 0 to 2 do FBrowse[I].Enabled := not Value;
end;

procedure TPaddleOcrForm.ReadImage(Sender: TObject);
begin
  if (FWorker <> nil) or (FImage = nil) then Exit;
  RequireCpu(DirectoryExists(EditValue(FDetector)) and DirectoryExists(EditValue(FRecognizer)),
    'Select the converted detector and recognizer folders.');
  FJSON := '';
  FText.Clear;
  DrawImage(nil);
  FWorker := TPaddleWorker.Create(EditValue(FDetector), EditValue(FRecognizer), EditValue(FRuntime),
    FClipper, FDigest, FImage);
  SetRunning(True);
  FStatus.Caption := 'Reading text. CPU inference can take a few minutes.';
  FTimer.Enabled := True;
  FWorker.Start;
end;

procedure TPaddleOcrForm.StopReading(Sender: TObject);
begin
  if FWorker = nil then Exit;
  FWorker.Terminate;
  FStop.Enabled := False;
  FStatus.Caption := 'Stopping after the current native operation...';
end;

procedure TPaddleOcrForm.Tick(Sender: TObject);
begin
  if (FWorker = nil) or (WaitForSingleObject(FWorker.Handle, 0) <> WAIT_OBJECT_0) then Exit;
  FTimer.Enabled := False;
  FWorker.WaitFor;
  try
    if FWorker.ErrorText = '' then
    begin
      FJSON := FWorker.Value.JSON;
      FText.Lines.Text := UI(FWorker.Value.Text);
      DrawImage(FWorker.Value.Lines);
      FStatus.Caption := UI(Format('%d text regions  |  %s  |  %.2f s',
        [Length(FWorker.Value.Lines), FWorker.Value.Device, FWorker.Value.Milliseconds / 1000]));
    end
    else begin
      FText.Lines.Text := UI(FWorker.ErrorText);
      FStatus.Caption := 'Reading did not complete.';
    end;
  finally
    FreeAndNil(FWorker);
    SetRunning(False);
  end;
end;

procedure TPaddleOcrForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then StopReading(nil);
end;

procedure TPaddleOcrForm.SaveResult(Sender: TObject);
var
  Dialog: TSaveDialog;
  Path, Value: string;
begin
  if FJSON = '' then Exit;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Filter := 'Text files|*.txt|JSON with coordinates and scores|*.json';
    Dialog.DefaultExt := 'txt';
    Dialog.FileName := 'recognized-text.txt';
    Dialog.Options := [ofPathMustExist, ofEnableSizing];
    if Dialog.Execute then
    begin
      Path := {$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName);
      if SameText(ExtractFileExt(Path), '.json') then
        Value := FJSON
      else
        Value := {$IFDEF FPC}UTF8Decode{$ENDIF}(FText.Lines.Text);
      SavePaddleText(Path, Value);
      FStatus.Caption := UI('Saved ' + Path);
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TPaddleOcrForm.DrawImage(const Lines: TPaddleTextLines);
var
  Bitmap: TBitmap;
  Source: PByte;
  X, Y, I, J: Integer;
  Points: array[0..4] of TPoint;
  {$IFDEF FPC}
  Surface: TLazIntfImage;
  Pixel: TFPColor;
  {$ELSE}
  Destination: PByte;
  {$ENDIF}
begin
  if FImage = nil then Exit;
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
      Move(Source^, Destination^, FImage.Width * 3);
    end;
    {$ENDIF}
    Bitmap.Canvas.Pen.Color := clLime;
    Bitmap.Canvas.Pen.Width := 2;
    Bitmap.Canvas.Brush.Style := bsClear;
    for I := 0 to High(Lines) do
    begin
      for J := 0 to 3 do
        Points[J] := Point(Round(Lines[I].Detection.Quad[J].X), Round(Lines[I].Detection.Quad[J].Y));
      Points[4] := Points[0];
      Bitmap.Canvas.Polyline(Points);
    end;
    FPreview.Picture.Assign(Bitmap);
  finally
    Bitmap.Free;
  end;
end;

end.
