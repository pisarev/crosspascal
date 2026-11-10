unit MarkerLiteForm;

interface

uses
  {$IFDEF FPC}
  Windows, SysUtils, Classes, Interfaces, Graphics, Controls, Forms, ExtCtrls, StdCtrls,
  Dialogs,
  {$ELSE}
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Dialogs,
  {$ENDIF}
  OpenCVTypes, OpenCVConsts, OpenCV, CrossVision.Mat, CrossVision.Image, CrossVision.Binarize,
  CrossVision.Image.OpenCV, ExampleDefaults;

type
  TMarkerLiteForm = class(TForm)
  private
    FImage: TImage;
    FMat: IMat;
    FStatus: TLabel;
    FGray: TButton;
    FSauvola: TButton;
    FCanny: TButton;
    FSave: TButton;
    procedure FitOnScreen(Sender: TObject);
    function AddButton(const ACaption: string; AHandler: TNotifyEvent; AParent: TWinControl;
      ALeft: Integer): TButton;
    procedure ShowMat(const M: IMat);
    procedure DoOpen(Sender: TObject);
    procedure LoadImage(const Path: string);
    procedure DoGray(Sender: TObject);
    procedure DoSauvola(Sender: TObject);
    procedure DoCanny(Sender: TObject);
    procedure DoSave(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

procedure TMarkerLiteForm.FitOnScreen(Sender: TObject);
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

constructor TMarkerLiteForm.Create(AOwner: TComponent);
var
  Content, Toolbar, Preview, Footer: TPanel;
begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal MarkerLite';
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 960;
  ClientHeight := 680;
  Constraints.MinWidth := 680;
  Constraints.MinHeight := 400;
  Position := poScreenCenter;
  OnShow := FitOnScreen;
  Content := TPanel.Create(Self);
  Content.Parent := Self;
  Content.Align := alClient;
  Content.BevelOuter := bvNone;
  Content.BorderWidth := 12;
  Toolbar := TPanel.Create(Self);
  Toolbar.Parent := Content;
  Toolbar.Align := alTop;
  Toolbar.Height := 44;
  Toolbar.BevelOuter := bvNone;
  AddButton('Open image...', DoOpen, Toolbar, 0);
  FGray := AddButton('Grayscale', DoGray, Toolbar, 1);
  FSauvola := AddButton('Sauvola', DoSauvola, Toolbar, 2);
  FCanny := AddButton('Canny edges', DoCanny, Toolbar, 3);
  FSave := AddButton('Save PNG...', DoSave, Toolbar, 4);
  FGray.Enabled := False;
  FSauvola.Enabled := False;
  FCanny.Enabled := False;
  FSave.Enabled := False;
  Footer := TPanel.Create(Self);
  Footer.Parent := Content;
  Footer.Align := alBottom;
  Footer.Height := 36;
  Footer.BevelOuter := bvNone;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.Align := alClient;
  FStatus.AutoSize := False;
  FStatus.Layout := tlCenter;
  FStatus.Caption := 'Open an image, choose an operation, then save the result.';
  Preview := TPanel.Create(Self);
  Preview.Parent := Content;
  Preview.Align := alClient;
  Preview.BevelOuter := bvNone;
  Preview.BorderWidth := 4;
  FImage := TImage.Create(Self);
  FImage.Parent := Preview;
  FImage.Align := alClient;
  FImage.Proportional := True;
  FImage.Stretch := True;
  FImage.Center := True;
  Toolbar.TabOrder := 0;
  Preview.TabOrder := 1;
  Footer.TabOrder := 2;
  if PreparedPath('image') <> '' then LoadImage(PreparedPath('image'));
end;

destructor TMarkerLiteForm.Destroy;
begin
  FMat := nil;
  inherited Destroy;
end;

function TMarkerLiteForm.AddButton(const ACaption: string; AHandler: TNotifyEvent;
  AParent: TWinControl; ALeft: Integer): TButton;
var
  Cell: TPanel;
begin
  Cell := TPanel.Create(Self);
  Cell.Parent := AParent;
  Cell.BevelOuter := bvNone;
  Cell.BorderWidth := 0;
  Cell.Left := ALeft * 128;
  Cell.Width := 128;
  Cell.TabOrder := ALeft;
  Cell.TabStop := False;
  Cell.Align := alLeft;
  Result := TButton.Create(Self);
  Result.Parent := Cell;
  Result.SetBounds(4, 2, 120, 32);
  Result.TabOrder := 0;
  Result.Caption := ACaption;
  Result.OnClick := AHandler;
end;

procedure TMarkerLiteForm.ShowMat(const M: IMat);
var
  Bmp: TBitmap;
  X, Y, W, H, Step, Ch: Integer;
  P: Pointer;
  Src, Dst: PByte;
begin
  if (M = nil) or M.IsEmpty then
    raise Exception.Create('The image operation returned an empty result.');
  W := M.Width;
  H := M.Height;
  Ch := M.Channels;
  Step := M.Step;
  P := M.DataPtr;
  if P = nil then
    raise Exception.Create('The image has no pixel data.');
  if (Ch <> 1) and (Ch <> 3) and (Ch <> 4) then
    raise Exception.Create('The image viewer requires one, three, or four channels.');
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(W, H);
    for Y := 0 to H - 1 do
    begin
      Dst := Bmp.ScanLine[Y];
      Src := PByte(NativeUInt(P) + NativeUInt(Y) * NativeUInt(Step));
      for X := 0 to W - 1 do
        if Ch = 1 then
        begin
          Dst[X * 3 + 0] := Src[X];
          Dst[X * 3 + 1] := Src[X];
          Dst[X * 3 + 2] := Src[X];
        end
        else begin
          Dst[X * 3 + 0] := Src[X * Ch + 0];
          Dst[X * 3 + 1] := Src[X * Ch + 1];
          Dst[X * 3 + 2] := Src[X * Ch + 2];
        end;
    end;
    FImage.Picture.Assign(Bmp);
    FStatus.Caption := Format('%d x %d pixels. Preview fitted to the window.', [W, H]);
    FGray.Enabled := True;
    FSauvola.Enabled := True;
    FCanny.Enabled := True;
    FSave.Enabled := True;
  finally
    Bmp.Free;
  end;
end;

procedure TMarkerLiteForm.DoOpen(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Open an image';
    Dlg.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.webp|All files|*.*';
    Dlg.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    if Dlg.Execute then LoadImage(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TMarkerLiteForm.LoadImage(const Path: string);
var
  InputStream: TFileStream;
  InputBytes: TBytes;
  RawMat: TMat;
  Loaded: IMat;
begin
  InputStream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    if (InputStream.Size <= 0) or (InputStream.Size > High(Integer)) then
      raise Exception.Create('The selected image file is empty or too large to decode.');
    SetLength(InputBytes, Integer(InputStream.Size));
    InputStream.ReadBuffer(InputBytes[0], Length(InputBytes));
  finally
    InputStream.Free;
  end;
  RawMat := nil;
  try
    if not CV.ImgCodecs.ImDecode(@InputBytes[0], Length(InputBytes), IMREAD_COLOR, @RawMat) then
      raise Exception.Create('Cannot decode the selected image: ' + CV.GetError);
    if RawMat = nil then
      raise Exception.Create('The image decoder returned no image.');
    Loaded := WrapMat(RawMat, True);
    RawMat := nil;
    ShowMat(Loaded);
    FMat := Loaded;
  finally
    if RawMat <> nil then
      CV.Core.DeleteMat(@RawMat);
  end;
end;

procedure TMarkerLiteForm.DoGray(Sender: TObject);
var
  Gray: IMat;
begin
  if (FMat = nil) or FMat.IsEmpty then Exit;
  Gray := FMat.ToGray;
  ShowMat(Gray);
  FMat := Gray;
end;

procedure TMarkerLiteForm.DoSauvola(Sender: TObject);
var
  Gray: IMat;
  Acc: IImageAccessor;
  Bin: IImageBuffer;
begin
  if (FMat = nil) or FMat.IsEmpty then Exit;
  Gray := FMat.ToGray;
  if Gray.IsEmpty then
    raise Exception.Create('Could not convert the image to grayscale.');
  Acc := GrayMatAccessor(Gray.Raw);
  Bin := BinarizeSauvola(Acc, 15, 0.2, 128);
  if not WriteToGrayMat(Bin, Gray.Raw) then
    raise Exception.Create('Could not write the binarized pixels into the image.');
  ShowMat(Gray);
  FMat := Gray;
end;

procedure TMarkerLiteForm.DoCanny(Sender: TObject);
var
  Edges: IMat;
begin
  if (FMat = nil) or FMat.IsEmpty then Exit;
  Edges := FMat.ToGray.Canny(50, 150);
  ShowMat(Edges);
  FMat := Edges;
end;

procedure TMarkerLiteForm.DoSave(Sender: TObject);
var
  Dlg: TSaveDialog;
  Encoded: Pointer;
  EncodedSize: Integer;
  OutputStream: TFileStream;
begin
  if (FMat = nil) or FMat.IsEmpty then Exit;
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Save the displayed image';
    Dlg.Filter := 'PNG image|*.png';
    Dlg.DefaultExt := 'png';
    Dlg.FileName := 'marker-lite.png';
    Dlg.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
    if not Dlg.Execute then Exit;
    Encoded := nil;
    EncodedSize := 0;
    try
      if not CV.ImgCodecs.ImEncode('.png', FMat.Raw, @Encoded, @EncodedSize, -1) then
        raise Exception.Create('Cannot encode the PNG image: ' + CV.GetError);
      if (Encoded = nil) or (EncodedSize <= 0) then
        raise Exception.Create('The PNG encoder returned an empty result.');
      OutputStream := TFileStream.Create(Dlg.FileName, fmCreate);
      try
        OutputStream.WriteBuffer(Encoded^, EncodedSize);
      finally
        OutputStream.Free;
      end;
    finally
      if Encoded <> nil then
        CV.ImgCodecs.FreeBuf(Encoded);
    end;
    FStatus.Caption := 'Saved ' + ExtractFileName(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

end.
