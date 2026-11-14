unit BiRefNet.Main;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$POINTERMATH ON}

interface

uses
  {$IFDEF FPC}Windows, Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls,
  {$ELSE}Winapi.Windows, System.Classes, System.SysUtils, Vcl.Controls, Vcl.Forms,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, {$ENDIF}
  CrossVision.Mat, BiRefNet.Run;

type
  TBiRefWorker = class(TThread)
  private
    FBundle: string;
    FRuntime: string;
    FDigest: string;
    FImage: IMat;
    function Stopping: Boolean;
  protected
    procedure Execute; override;
  public
    Value: TBiRefResult;
    ErrorText: string;
    RequiresProcessRestart: Boolean;
    CleanupDetail: string;
    constructor Create(const Bundle, Runtime, Digest: string; const Image: IMat);
  end;

  TBiRefNetForm = class(TForm)
  private
    FBundle: TEdit;
    FRuntime: TEdit;
    FBrowse: array[0..1] of TButton;
    FOpen: TButton;
    FRemove: TButton;
    FStop: TButton;
    FSave: TButton;
    FView: TComboBox;
    FOriginal: TImage;
    FResult: TImage;
    FStatus: TLabel;
    FTimer: TTimer;
    FWorker: TBiRefWorker;
    FImage: IMat;
    FValue: TBiRefResult;
    FDigest: string;
    FCVLibrary: string;
    FDisplayValid: Boolean;
    FDisplayedView: Integer;
    FChangingView: Boolean;
    FRequiresRestart: Boolean;
    FRestartDetail: string;
    procedure Browse(Sender: TObject);
    procedure OpenImage(Sender: TObject);
    procedure LoadImage(const FileName: string);
    procedure RemoveBackground(Sender: TObject);
    procedure StopWork(Sender: TObject);
    procedure SaveResult(Sender: TObject);
    procedure ChangeView(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure FitOnScreen(Sender: TObject);
    procedure SetRunning(const Running: Boolean);
    function PrepareImage(const Image: IMat): TPicture;
    function PrepareResult(const Value: TBiRefResult): TPicture;
    procedure PublishPictures(const Source, Value: TPicture; const ReplaceSource: Boolean);
    procedure InvalidateDisplay;
    procedure ReportError(const Operation, Detail: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  {$IFDEF FPC}Math, Dialogs, FPReadPNG, {$ELSE}System.Math, Vcl.Dialogs, Vcl.FileCtrl,
  Vcl.Imaging.pngimage, {$ENDIF}
  ExampleDefaults, TVM.CpuGraph, TVM.BiRefNet, OpenCV, OpenCVTypes, OpenCVConsts;

function UI(const Text: string): {$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};
begin
  {$IFDEF FPC}Result := UTF8Encode(Text);
  {$ELSE}Result := Text;{$ENDIF}
end;

function EditValue(const Edit: TEdit): string;
begin
  {$IFDEF FPC}Result := UTF8Decode(Edit.Text);
  {$ELSE}Result := Edit.Text;{$ENDIF}
end;

function FolderExists(const Path: string): Boolean;
begin
  {$IFDEF FPC}Result := SysUtils.DirectoryExists(Path);
  {$ELSE}Result := System.SysUtils.DirectoryExists(Path);{$ENDIF}
end;

constructor TBiRefWorker.Create(const Bundle, Runtime, Digest: string; const Image: IMat);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FBundle := Bundle;
  FRuntime := Runtime;
  FDigest := Digest;
  FImage := Image;
end;

function TBiRefWorker.Stopping: Boolean;
begin
  Result := Terminated;
end;

procedure TBiRefWorker.Execute;
begin
  try
    try
      Value := RunBiRef(FBundle, FRuntime, FDigest, FImage, Stopping);
    except
      on E: Exception do ErrorText := E.ClassName + ': ' + E.Message;
    end;
  finally
    RequiresProcessRestart := BiRefNetRequiresProcessRestart;
    CleanupDetail := BiRefNetCleanupDiagnostic;
    FImage := nil;
  end;
end;

constructor TBiRefNetForm.Create(AOwner: TComponent);
var
  Content, Header, Toolbar, Row, Field, Preview, SourcePanel, ResultPanel, Footer: TPanel;
  Splitter: TSplitter;
  LabelControl: TLabel;
  Edits: array[0..1] of TEdit;
  I: Integer;
const
  Labels: array[0..1] of string = ('BiRefNet model folder', 'TVM runtime folder');

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

  function Button(const Caption: string; const Handler: TNotifyEvent; const Left: Integer): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Toolbar;
    Result.SetBounds(Left, 4, 148, 32);
    Result.Caption := UI(Caption);
    Result.OnClick := Handler;
  end;

  function Image(const Parent: TWinControl): TImage;
  begin
    Result := TImage.Create(Self);
    Result.Parent := Parent;
    Result.Align := alClient;
    Result.Stretch := True;
    Result.Proportional := True;
    Result.Center := True;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal BiRefNet';
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 1080;
  ClientHeight := 760;
  Constraints.MinWidth := 800;
  Constraints.MinHeight := 540;
  Position := poScreenCenter;
  OnShow := FitOnScreen;
  OnCloseQuery := CheckClose;
  FCVLibrary := FindBiRefPath('crosspascal-opencv\bin\crosscv.dll', False);
  Content := Panel(Self, alClient, 0);
  Content.BorderWidth := 12;
  Content.DisableAlign;
  Header := Panel(Content, alTop, 134);
  Header.DisableAlign;
  Toolbar := Panel(Header, alTop, 44);
  Toolbar.Top := 0;
  FOpen := Button('Open image...', OpenImage, 0);
  FRemove := Button('Remove background', RemoveBackground, 156);
  FStop := Button('Stop', StopWork, 312);
  FSave := Button('Save result...', SaveResult, 468);
  for I := 0 to 1 do
  begin
    Row := Panel(Header, alTop, 42);
    Row.Top := 44 + I * 42;
    Row.DisableAlign;
    LabelControl := TLabel.Create(Self);
    LabelControl.Parent := Row;
    LabelControl.Align := alLeft;
    LabelControl.AutoSize := False;
    LabelControl.Width := 165;
    LabelControl.Layout := tlCenter;
    LabelControl.Caption := UI(Labels[I]);
    Field := Panel(Row, alRight, 128);
    Field.TabOrder := 1;
    FBrowse[I] := TButton.Create(Self);
    FBrowse[I].Parent := Field;
    FBrowse[I].SetBounds(4, 5, 120, 32);
    FBrowse[I].Caption := 'Browse...';
    FBrowse[I].Tag := I;
    FBrowse[I].OnClick := Browse;
    Field := Panel(Row, alClient, 0);
    Field.BorderWidth := 5;
    Field.TabOrder := 0;
    Edits[I] := TEdit.Create(Self);
    Edits[I].Parent := Field;
    Edits[I].AutoSize := False;
    Edits[I].Align := alClient;
    Row.EnableAlign;
  end;
  FBundle := Edits[0];
  FRuntime := Edits[1];
  FBundle.Text := UI(PreparedPath('model'));
  FRuntime.Text := UI(PreparedPath('runtime',
    FindBiRefPath('crosspascal-tvm\runtime\windows-x64-cuda', True)));
  Header.EnableAlign;
  Footer := Panel(Content, alBottom, 46);
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.Align := alClient;
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;
  FStatus.Layout := tlCenter;
  FStatus.Caption := 'Open an image, then remove its background.';
  Preview := Panel(Content, alClient, 0);
  SourcePanel := Panel(Preview, alLeft, 490);
  SourcePanel.BorderWidth := 6;
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := SourcePanel;
  LabelControl.Align := alTop;
  LabelControl.Caption := 'Original';
  FOriginal := Image(SourcePanel);
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Preview;
  Splitter.Left := SourcePanel.Width;
  Splitter.Align := alLeft;
  Splitter.Width := 8;
  ResultPanel := Panel(Preview, alClient, 0);
  ResultPanel.BorderWidth := 6;
  FView := TComboBox.Create(Self);
  FView.Parent := ResultPanel;
  FView.Align := alTop;
  FView.Style := csDropDownList;
  FView.Items.Add('Cutout preview');
  FView.Items.Add('Mask');
  FView.ItemIndex := 0;
  FView.OnChange := ChangeView;
  FResult := Image(ResultPanel);
  Content.EnableAlign;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.Enabled := False;
  FTimer.OnTimer := Tick;
  if PreparedPath('image') <> '' then LoadImage(PreparedPath('image'));
  SetRunning(False);
end;

destructor TBiRefNetForm.Destroy;
begin
  if FWorker <> nil then
  begin
    FWorker.Terminate;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
  FValue := Default(TBiRefResult);
  FImage := nil;
  inherited;
end;

procedure TBiRefNetForm.FitOnScreen(Sender: TObject);
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

procedure TBiRefNetForm.Browse(Sender: TObject);
var
  Edit: TEdit;
  Path: string;
  {$IFDEF FPC}
  Dialog: TSelectDirectoryDialog;{$ENDIF}
begin
  if TButton(Sender).Tag = 0 then
    Edit := FBundle
  else
    Edit := FRuntime;
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

procedure TBiRefNetForm.LoadImage(const FileName: string);
var
  CandidateImage: IMat;
  CandidateDigest, CandidateStatus: string;
  Picture: TPicture;
begin
  RequireCpu(FWorker = nil, 'Wait for the current operation to finish.');
  CandidateImage := ReadBiRefImage(FileName, FCVLibrary, CandidateDigest);
  CandidateStatus := Format('%s  |  %d x %d',
    [ExtractFileName(FileName), CandidateImage.Width, CandidateImage.Height]);
  Picture := PrepareImage(CandidateImage);
  try
    PublishPictures(Picture, nil, True);
    FImage := CandidateImage;
    FDigest := CandidateDigest;
    FValue := Default(TBiRefResult);
    FDisplayedView := FView.ItemIndex;
    FDisplayValid := True;
    FStatus.Caption := UI(CandidateStatus);
    SetRunning(False);
  finally
    Picture.Free;
  end;
end;

procedure TBiRefNetForm.OpenImage(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.webp|All files|*.*';
    Dialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    try
      if Dialog.Execute then LoadImage({$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName));
    except
      on E: Exception do ReportError('Could not open image', E.Message);
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TBiRefNetForm.SetRunning(const Running: Boolean);
var
  I: Integer;
begin
  if BiRefNetRequiresProcessRestart then
  begin
    FRequiresRestart := True;
    if FRestartDetail = '' then FRestartDetail := BiRefNetCleanupDiagnostic;
  end;
  FOpen.Enabled := not Running;
  FRemove.Enabled := not Running and not FRequiresRestart and
    not BiRefNetRequiresProcessRestart and FDisplayValid and (FImage <> nil);
  FStop.Enabled := Running;
  FSave.Enabled := not Running and FDisplayValid and (FValue.Cutout <> nil);
  FBundle.Enabled := not Running;
  FRuntime.Enabled := not Running;
  FView.Enabled := not Running and FDisplayValid and (FValue.Cutout <> nil);
  for I := 0 to 1 do FBrowse[I].Enabled := not Running;
  if not Running and FRequiresRestart then
    FStatus.Caption := UI('Restart the application before running another model. ' + FRestartDetail);
end;

procedure TBiRefNetForm.RemoveBackground(Sender: TObject);
begin
  try
    RequireCpu(not FRequiresRestart and not BiRefNetRequiresProcessRestart,
      'Restart the application before running another model.');
    RequireCpu(FDisplayValid, 'Open an image again to restore the preview before running.');
    if (FWorker <> nil) or (FImage = nil) then Exit;
    RequireCpu(FolderExists(EditValue(FBundle)), 'Select the converted BiRefNet model folder.');
    RequireCpu(FolderExists(EditValue(FRuntime)), 'Select the TVM runtime folder.');
    PublishPictures(nil, nil, False);
    FValue := Default(TBiRefResult);
    FWorker := TBiRefWorker.Create(EditValue(FBundle), EditValue(FRuntime), FDigest, FImage);
    try
      SetRunning(True);
      FStatus.Caption := 'Removing the background. Full CPU inference can take a minute or more.';
      FTimer.Enabled := True;
      FWorker.Start;
    except
      FTimer.Enabled := False;
      FreeAndNil(FWorker);
      SetRunning(False);
      raise;
    end;
  except
    on E: Exception do ReportError('Could not remove background', E.Message);
  end;
end;

procedure TBiRefNetForm.StopWork(Sender: TObject);
begin
  if FWorker = nil then Exit;
  FWorker.Terminate;
  FStop.Enabled := False;
  FStatus.Caption := 'Stopping after the current native operation...';
end;

procedure TBiRefNetForm.Tick(Sender: TObject);
var
  Candidate: TBiRefResult;
  Picture: TPicture;
  Status: string;
begin
  if (FWorker = nil) or (WaitForSingleObject(FWorker.Handle, 0) <> WAIT_OBJECT_0) then Exit;
  FTimer.Enabled := False;
  try
    FWorker.WaitFor;
    if FWorker.RequiresProcessRestart then
    begin
      FRequiresRestart := True;
      FRestartDetail := FWorker.ErrorText + ' ' + FWorker.CleanupDetail;
    end;
    try
      if FRequiresRestart then
        FValue := Default(TBiRefResult)
      else if FWorker.ErrorText <> '' then
          FStatus.Caption := UI(FWorker.ErrorText)
        else begin
          Candidate := FWorker.Value;
          Status := Format('%s  |  %.2f s  |  Save the cutout or mask as PNG.',
            [Candidate.Device, Candidate.Milliseconds / 1000]);
          Picture := PrepareResult(Candidate);
          try
            PublishPictures(nil, Picture, False);
            FValue := Candidate;
            FDisplayedView := FView.ItemIndex;
            FStatus.Caption := UI(Status);
          finally
            Picture.Free;
          end;
        end;
    except
      on E: Exception do
      begin
        FValue := Default(TBiRefResult);
        FStatus.Caption := UI('Result preview failed: ' + E.Message);
      end;
    end;
  finally
    FreeAndNil(FWorker);
    SetRunning(False);
  end;
end;

procedure TBiRefNetForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FWorker = nil;
  if not CanClose then StopWork(nil);
end;

procedure TBiRefNetForm.ChangeView(Sender: TObject);
var
  Picture: TPicture;
  ErrorText: string;
begin
  if FChangingView or (FValue.Cutout = nil) then Exit;
  RequireCpu(FDisplayValid, 'Open an image again to restore the preview.');
  try
    Picture := PrepareResult(FValue);
    try
      PublishPictures(nil, Picture, False);
      FDisplayedView := FView.ItemIndex;
    finally
      Picture.Free;
    end;
  except
    on E: Exception do
    begin
      ErrorText := E.Message;
      FChangingView := True;
      try
        try
          FView.ItemIndex := FDisplayedView;
        except
          on RestoreError: Exception do
          begin
            ErrorText := ErrorText + ' View selection could not be restored: ' +
              RestoreError.Message;
            InvalidateDisplay;
          end;
        end;
      finally
        FChangingView := False;
      end;
      FStatus.Caption := UI('Preview change failed: ' + ErrorText);
    end;
  end;
end;

procedure TBiRefNetForm.SaveResult(Sender: TObject);
var
  Dialog: TSaveDialog;
  Path: string;
  Image: IMat;
begin
  try
    RequireCpu(FDisplayValid, 'Open an image again to restore the preview before saving.');
    if (FWorker <> nil) or (FValue.Cutout = nil) then Exit;
    Dialog := TSaveDialog.Create(Self);
    try
      Dialog.Filter := 'Transparent cutout PNG|*.png|Grayscale mask PNG|*.png|Result report JSON|*.json';
      Dialog.DefaultExt := 'png';
      Dialog.FileName := 'cutout.png';
      Dialog.Options := [ofPathMustExist, ofEnableSizing];
      if Dialog.Execute then
      begin
        Path := {$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName);
        if Dialog.FilterIndex = 3 then
          Path := ChangeFileExt(Path, '.json')
        else
          Path := ChangeFileExt(Path, '.png');
        if Dialog.FilterIndex = 3 then
          SaveBiRefReport(Path, FValue.JSON)
        else begin
          if Dialog.FilterIndex = 2 then
            Image := FValue.Mask.ConvertTo(CV_MAKETYPE(CV_8U, 1), 255, 0)
          else
            Image := FValue.Cutout;
          SaveBiRefPNG(Path, Image);
        end;
        FStatus.Caption := UI('Saved ' + Path);
      end;
    finally
      Dialog.Free;
    end;
  except
    on E: Exception do ReportError('Could not save result', E.Message);
  end;
end;

function TBiRefNetForm.PrepareImage(const Image: IMat): TPicture;
var
  Composite: IMat;
  Source, Destination: PByte;
  Data: Pointer;
  Stream: TMemoryStream;
  Size, X, Y, C, Alpha, Gray: Integer;
begin
  RequireCpu(Image <> nil, 'No image is available for preview.');
  Composite := Image;
  if Image.Channels = 4 then
  begin
    Composite := NewMat(Image.Width, Image.Height, CV_MAKETYPE(CV_8U, 3));
    RequireCpu((Composite <> nil) and not Composite.IsEmpty, 'Preview allocation failed');
    for Y := 0 to Image.Height - 1 do
    begin
      Source := PByte(Image.DataPtr) + NativeInt(Y) * Image.Step;
      Destination := PByte(Composite.DataPtr) + NativeInt(Y) * Composite.Step;
      for X := 0 to Image.Width - 1 do
      begin
        Gray := 250;
        if ((X div 12 + Y div 12) mod 2) <> 0 then Gray := 218;
        Alpha := Source[X * 4 + 3];
        for C := 0 to 2 do
          Destination[X * 3 + C] := (Source[X * 4 + C] * Alpha + Gray * (255 - Alpha) + 127) div
            255;
      end;
    end;
  end;
  Data := nil;
  Size := 0;
  Result := TPicture.Create;
  try
    Stream := TMemoryStream.Create;
    try
      RequireCpu(CV.ImgCodecs.ImEncode('.png', Composite.Raw, @Data, @Size, 1) and
        (Data <> nil) and (Size > 0), 'Preview encoding failed');
      Stream.WriteBuffer(Data^, Size);
      Stream.Position := 0;
      Result.LoadFromStream(Stream);
    finally
      Stream.Free;
      if Data <> nil then RequireCpu(CV.ImgCodecs.FreeBuf(Data), 'Preview buffer release failed');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TBiRefNetForm.PrepareResult(const Value: TBiRefResult): TPicture;
var
  Image: IMat;
begin
  if FView.ItemIndex = 1 then
    Image := Value.Mask.ConvertTo(CV_MAKETYPE(CV_8U, 1), 255, 0)
  else
    Image := Value.Cutout;
  Result := PrepareImage(Image);
end;

procedure TBiRefNetForm.ReportError(const Operation, Detail: string);
var
  Text: string;
begin
  Text := Operation + ': ' + Detail;
  FStatus.Caption := UI(Text);
  MessageDlg(UI(Text), mtError, [mbOK], 0);
end;

procedure TBiRefNetForm.InvalidateDisplay;
begin
  FDisplayValid := False;
  SetRunning(FWorker <> nil);
end;

procedure TBiRefNetForm.PublishPictures(const Source, Value: TPicture;
  const ReplaceSource: Boolean);
var
  OldSource, OldResult: TPicture;
  ErrorText, RestoreText: string;
begin
  OldSource := nil;
  OldResult := TPicture.Create;
  try
    OldResult.Assign(FResult.Picture);
    if ReplaceSource then
    begin
      OldSource := TPicture.Create;
      OldSource.Assign(FOriginal.Picture);
    end;
    try
      if ReplaceSource then FOriginal.Picture.Assign(Source);
      FResult.Picture.Assign(Value);
    except
      on E: Exception do
      begin
        ErrorText := E.ClassName + ': ' + E.Message;
        RestoreText := '';
        if ReplaceSource then
        begin
          try
            FOriginal.Picture.Assign(OldSource);
          except
            on RestoreError: Exception do RestoreText := ' Original: ' + RestoreError.Message;
          end;
        end;
        try
          FResult.Picture.Assign(OldResult);
        except
          on RestoreError:
            Exception do RestoreText := RestoreText + ' Result: ' + RestoreError.Message;
        end;
        if RestoreText <> '' then
        begin
          InvalidateDisplay;
          ErrorText := ErrorText + ' Preview could not be restored.' + RestoreText +
            ' Open an image again before running or saving.';
        end;
        raise ECpuGraph.Create(ErrorText);
      end;
    end;
  finally
    OldSource.Free;
    OldResult.Free;
  end;
end;

end.
