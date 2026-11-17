unit OmDetTurbo.Main;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  {$IFDEF FPC}Windows, Classes, SysUtils, Controls, Forms, Graphics, StdCtrls,
  ExtCtrls, Grids{$ELSE}Winapi.Windows, System.Classes, System.SysUtils,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids{$ENDIF},
  CrossVision.Mat, OmDetTurbo.Run, OmDetTurbo.Worker;

type
  TOmDetForm = class(TForm)
  private
    FScroll: TScrollBox;
    FContent: TPanel;
    FPreview: TPanel;
    FSourcePanel: TPanel;
    FBundle: TEdit;
    FRuntime: TEdit;
    FConfidence: TEdit;
    FNMS: TEdit;
    FBrowse: array[0..1] of TButton;
    FOpen: TButton;
    FDetect: TButton;
    FStop: TButton;
    FUnload: TButton;
    FSave: TButton;
    FClasses: TMemo;
    FTask: TMemo;
    FTruncate: TCheckBox;
    FOriginal: TImage;
    FResult: TImage;
    FGrid: TStringGrid;
    FStatus: TLabel;
    FTimer: TTimer;
    FWorker: TOmDetWorker;
    FImage: IMat;
    FValue: TOmDetResult;
    FDigest: string;
    FCVLibrary: string;
    FSessionError: string;
    FHasResult: Boolean;
    FRequiresRestart: Boolean;
    FStopRequested: Boolean;
    FClosePending: Boolean;
    FClosing: Boolean;
    procedure Browse(Sender: TObject);
    procedure OpenImage(Sender: TObject);
    procedure LoadImage(const FileName: string);
    procedure Detect(Sender: TObject);
    procedure Stop(Sender: TObject);
    procedure Unload(Sender: TObject);
    procedure Save(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure FitOnScreen(Sender: TObject);
    procedure ResizeContent(Sender: TObject);
    procedure UpdateControls;
    procedure ClearResult;
    procedure ReportError(const Detail: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Configure(const CVLibrary, Bundle, Runtime, ImagePath: string);
    procedure CloseSession;
    property SessionError: string read FSessionError;
  end;

implementation

uses
  {$IFDEF FPC}Math, Dialogs{$ELSE}System.Math, Vcl.Dialogs, Vcl.FileCtrl{$ENDIF},
  ExampleDefaults, CrossPascal.Json, TVM.CpuGraph, TVM.OmDetModel, OmDetTurbo.Render;

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

function MemoText(const Memo: TMemo): string;
begin
  {$IFDEF FPC}Result := UTF8Decode(Memo.Text);
  {$ELSE}Result := Memo.Text;{$ENDIF}
end;

function ReadThreshold(const Edit: TEdit): Single;
var
  Value: Double;
  Bits: UInt64;
begin
  RequireCpu(TryStrToFloat(EditText(Edit), Value, JSONInvariantFormat),
    'Enter a threshold between 0 and 1, using a decimal point.');
  Move(Value, Bits, SizeOf(Bits));
  RequireCpu((Bits and $7FF0000000000000) <> $7FF0000000000000, 'Enter a finite threshold.');
  RequireCpu((Value >= 0) and (Value <= 1), 'Thresholds must be between 0 and 1.');
  Result := Value;
end;

constructor TOmDetForm.Create(AOwner: TComponent);
var
  Header, Paths, Row, Field, Query, ClassPanel, TaskPanel, Options, Toolbar,
    Footer, ResultPanel: TPanel;
  LabelControl: TLabel;
  Splitter: TSplitter;
  Edits: array[0..1] of TEdit;
  I: Integer;
const
  PathLabels: array[0..1] of string = ('OmDet model folder', 'TVM runtime folder');
  Columns: array[0..5] of string = ('Class', 'Confidence', 'Left', 'Top', 'Right', 'Bottom');

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

  function Button(const Text: string; const Handler: TNotifyEvent; const Left: Integer): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Toolbar;
    Result.SetBounds(Left, 4, 140, 32);
    Result.Caption := UI(Text);
    Result.OnClick := Handler;
  end;

  procedure LabelFor(const Parent: TWinControl; const Text: string);
  var
    Control: TLabel;
  begin
    Control := TLabel.Create(Self);
    Control.Parent := Parent;
    Control.Align := alTop;
    Control.Caption := UI(Text);
  end;

  function ImageFor(const Parent: TWinControl): TImage;
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
  Caption := 'CrossPascal OmDet-Turbo';
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  ClientWidth := 1160;
  ClientHeight := 860;
  Position := poScreenCenter;
  OnShow := FitOnScreen;
  OnCloseQuery := CheckClose;
  FCVLibrary := FindOmDetPath('crosspascal-opencv\bin\crosscv.dll', False);
  FWorker := TOmDetWorker.Create;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FContent := Panel(FScroll, alNone, 0);
  FContent.SetBounds(0, 0, 1140, 820);
  FContent.BorderWidth := 12;
  FContent.DisableAlign;
  Header := Panel(FContent, alTop, 304);
  Header.DisableAlign;
  Paths := Panel(Header, alTop, 88);
  Paths.Top := 0;
  Paths.TabOrder := 0;
  for I := 0 to 1 do
  begin
    Row := Panel(Paths, alTop, 42);
    Row.Top := I * 42;
    Row.TabOrder := I;
    Row.DisableAlign;
    LabelControl := TLabel.Create(Self);
    LabelControl.Parent := Row;
    LabelControl.Align := alLeft;
    LabelControl.AutoSize := False;
    LabelControl.Width := 160;
    LabelControl.Layout := tlCenter;
    LabelControl.Caption := UI(PathLabels[I]);
    Field := Panel(Row, alRight, 124);
    Field.TabOrder := 1;
    FBrowse[I] := TButton.Create(Self);
    FBrowse[I].Parent := Field;
    FBrowse[I].SetBounds(4, 5, 116, 32);
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
  FRuntime.Text := UI(PreparedPath('runtime'));
  Query := Panel(Header, alTop, 170);
  Query.Top := 88;
  Query.TabOrder := 1;
  Query.BorderWidth := 5;
  ClassPanel := Panel(Query, alLeft, 310);
  ClassPanel.BorderWidth := 4;
  LabelFor(ClassPanel, 'Classes: one per line, 1-16');
  FClasses := TMemo.Create(Self);
  FClasses.Parent := ClassPanel;
  FClasses.Align := alClient;
  FClasses.ScrollBars := ssVertical;
  FClasses.WantTabs := False;
  FClasses.Text := 'person' + #13#10 + 'helmet' + #13#10 + 'flag' + #13#10 + 'space shuttle';
  TaskPanel := Panel(Query, alClient, 0);
  TaskPanel.BorderWidth := 4;
  LabelFor(TaskPanel, 'Task: leave blank to use the class names');
  Options := Panel(TaskPanel, alBottom, 68);
  Options.TabOrder := 1;
  FTruncate := TCheckBox.Create(Self);
  FTruncate.Parent := Options;
  FTruncate.Align := alBottom;
  FTruncate.Height := 30;
  FTruncate.Caption := 'Allow truncating text to 77 tokens';
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Options;
  LabelControl.SetBounds(0, 7, 78, 24);
  LabelControl.Caption := 'Confidence';
  FConfidence := TEdit.Create(Self);
  FConfidence.Parent := Options;
  FConfidence.SetBounds(84, 4, 54, 28);
  FConfidence.Text := '0.3';
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Options;
  LabelControl.SetBounds(150, 7, 38, 24);
  LabelControl.Caption := 'NMS';
  FNMS := TEdit.Create(Self);
  FNMS.Parent := Options;
  FNMS.SetBounds(194, 4, 54, 28);
  FNMS.Text := '0.3';
  FTruncate.TabOrder := 2;
  FConfidence.TabOrder := 0;
  FNMS.TabOrder := 1;
  FTask := TMemo.Create(Self);
  FTask.Parent := TaskPanel;
  FTask.Align := alClient;
  FTask.ScrollBars := ssVertical;
  FTask.WantTabs := False;
  FTask.TabOrder := 0;
  Toolbar := Panel(Header, alTop, 44);
  Toolbar.Top := 258;
  Toolbar.TabOrder := 2;
  FOpen := Button('Open image...', OpenImage, 0);
  FDetect := Button('Detect objects', Detect, 148);
  FStop := Button('Stop', Stop, 296);
  FUnload := Button('Unload model', Unload, 444);
  FSave := Button('Save result...', Save, 592);
  FDetect.Default := True;
  FStop.Cancel := True;
  Header.EnableAlign;
  Footer := Panel(FContent, alBottom, 54);
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.Align := alClient;
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;
  FStatus.Layout := tlCenter;
  FStatus.Caption := 'Open an image, choose class names, then detect objects.';
  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := FContent;
  FGrid.Align := alBottom;
  FGrid.Height := 146;
  FGrid.ColCount := 6;
  FGrid.RowCount := 2;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.DefaultColWidth := 100;
  FGrid.ColWidths[0] := 220;
  FGrid.ColWidths[1] := 110;
  FGrid.TabStop := False;
  for I := 0 to 5 do FGrid.Cells[I, 0] := UI(Columns[I]);
  FPreview := Panel(FContent, alClient, 0);
  FSourcePanel := Panel(FPreview, alLeft, 540);
  FSourcePanel.BorderWidth := 5;
  LabelFor(FSourcePanel, 'Original');
  FOriginal := ImageFor(FSourcePanel);
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := FPreview;
  Splitter.Left := FSourcePanel.Width;
  Splitter.Align := alLeft;
  Splitter.Width := 8;
  ResultPanel := Panel(FPreview, alClient, 0);
  ResultPanel.BorderWidth := 5;
  LabelFor(ResultPanel, 'Detected objects');
  FResult := ImageFor(ResultPanel);
  FContent.EnableAlign;
  FBundle.OnChange := Changed;
  FRuntime.OnChange := Changed;
  FClasses.OnChange := Changed;
  FTask.OnChange := Changed;
  FConfidence.OnChange := Changed;
  FNMS.OnChange := Changed;
  FTruncate.OnClick := Changed;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.OnTimer := Tick;
  FWorker.Start;
  OnResize := ResizeContent;
  ResizeContent(nil);
  UpdateControls;
end;

procedure TOmDetForm.Configure(const CVLibrary, Bundle, Runtime, ImagePath: string);
begin
  FCVLibrary := CVLibrary;
  FBundle.Text := UI(Bundle);
  FRuntime.Text := UI(Runtime);
  if ImagePath <> '' then
  begin
    try
      LoadImage(ImagePath);
    except
      on E: Exception do FStatus.Caption := UI('Prepared image: ' + E.Message);
    end;
  end;
  UpdateControls;
end;

destructor TOmDetForm.Destroy;
begin
  CloseSession;
  if FWorker <> nil then
  begin
    FreeAndNil(FWorker);
  end;
  FValue := Default(TOmDetResult);
  FImage := nil;
  inherited;
end;

procedure TOmDetForm.CloseSession;
begin
  FClosing := True;
  if FTimer <> nil then FTimer.Enabled := False;
  if FWorker <> nil then
  begin
    FWorker.Shutdown;
    FSessionError := FWorker.ShutdownError;
  end;
end;

procedure TOmDetForm.ResizeContent(Sender: TObject);
begin
  if (csDestroying in ComponentState) or (FContent = nil) or (FScroll = nil) then Exit;
  FContent.Width := Max(820, FScroll.ClientWidth - 2);
  FContent.Height := Max(820, FScroll.ClientHeight - 2);
  if FSourcePanel <> nil then FSourcePanel.Width := Max(100, (FPreview.ClientWidth - 8) div 2);
end;

procedure TOmDetForm.FitOnScreen(Sender: TObject);
var
  Area: TRect;
begin
  Area := Monitor.WorkareaRect;
  Width := Min(Width, Area.Right - Area.Left);
  Height := Min(Height, Area.Bottom - Area.Top);
  Left := Max(Area.Left, Min(Left, Area.Right - Width));
  Top := Max(Area.Top, Min(Top, Area.Bottom - Height));
  ResizeContent(nil);
end;

procedure TOmDetForm.UpdateControls;
var
  Running: Boolean;
  I: Integer;
begin
  Running := FWorker.Busy;
  FOpen.Enabled := not Running and not FClosing;
  FDetect.Enabled := not Running and not FClosing and not FRequiresRestart and (FImage <> nil);
  FStop.Enabled := Running and not FStopRequested;
  FUnload.Enabled := not Running and not FClosing and not FRequiresRestart;
  FSave.Enabled := not Running and FHasResult;
  FBundle.Enabled := not Running;
  FRuntime.Enabled := not Running;
  FClasses.Enabled := not Running;
  FTask.Enabled := not Running;
  FConfidence.Enabled := not Running;
  FNMS.Enabled := not Running;
  FTruncate.Enabled := not Running;
  for I := 0 to 1 do FBrowse[I].Enabled := not Running;
end;

procedure TOmDetForm.ClearResult;
var
  I: Integer;
begin
  FHasResult := False;
  FValue := Default(TOmDetResult);
  FResult.Picture.Assign(nil);
  FGrid.RowCount := 2;
  for I := 0 to 5 do FGrid.Cells[I, 1] := '';
end;

procedure TOmDetForm.Changed(Sender: TObject);
begin
  ClearResult;
  UpdateControls;
end;

procedure TOmDetForm.ReportError(const Detail: string);
begin
  FStatus.Caption := UI(Detail);
  MessageDlg(UI(Detail), mtError, [mbOK], 0);
end;

procedure TOmDetForm.Browse(Sender: TObject);
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
  Path := EditText(Edit);
  {$IFDEF FPC}
  Dialog := TSelectDirectoryDialog.Create(Self);
  try
    Dialog.InitialDir := UI(Path);
    if Dialog.Execute then Path := UTF8Decode(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  {$ELSE}
  if not SelectDirectory('Select the model or runtime folder', '', Path, [sdNewUI, sdNewFolder], Self) then
    Exit;
  {$ENDIF}
  Edit.Text := UI(Path);
end;

procedure TOmDetForm.LoadImage(const FileName: string);
var
  Image: IMat;
  Digest: string;
  Picture: TPicture;
begin
  RequireCpu(not FWorker.Busy, 'Wait for inference to finish.');
  Image := ReadOmDetImage(FileName, FCVLibrary, Digest);
  Picture := OmDetPicture(Image);
  try
    try
      FOriginal.Picture.Assign(Picture);
    except
      FImage := nil;
      FOriginal.Picture.Assign(nil);
      ClearResult;
      raise;
    end;
    FImage := Image;
    FDigest := Digest;
    ClearResult;
    FStatus.Caption := UI(Format('%s  |  %d x %d', [ExtractFileName(FileName), Image.Width, Image.Height]));
  finally
    Picture.Free;
    UpdateControls;
  end;
end;

procedure TOmDetForm.OpenImage(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.webp|All files|*.*';
    if Dialog.Execute then
    begin
      try
        LoadImage({$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName));
      except
        on E: Exception do ReportError('Could not open image: ' + E.Message);
      end;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TOmDetForm.Detect(Sender: TObject);
var
  Job: TOmDetJob;
  Labels: TOmDetLabels;
  Text: string;
  I, Count: Integer;
begin
  try
    RequireCpu(not FRequiresRestart, 'Restart the application before running another model.');
    RequireCpu(FImage <> nil, 'Open an image first.');
    Job := Default(TOmDetJob);
    Job.Bundle := EditText(FBundle);
    Job.Runtime := EditText(FRuntime);
    RequireCpu(DirectoryExists(Job.Bundle) and DirectoryExists(Job.Runtime),
      'Select the model and TVM runtime folders.');
    SetLength(Labels, FClasses.Lines.Count);
    Count := 0;
    for I := 0 to FClasses.Lines.Count - 1 do
    begin
      Text := Trim({$IFDEF FPC}UTF8Decode{$ENDIF}(FClasses.Lines[I]));
      if Text = '' then Continue;
      Labels[Count] := Text;
      Inc(Count);
    end;
    RequireCpu((Count >= 1) and (Count <= 16), 'Enter 1 to 16 class names, one per line.');
    SetLength(Labels, Count);
    Job.Labels := Labels;
    Job.Task := MemoText(FTask);
    if Trim(Job.Task) = '' then Job.Task := '';
    Job.Image := FImage;
    Job.ImageDigest := FDigest;
    Job.AllowTruncate := FTruncate.Checked;
    Job.ScoreThreshold := ReadThreshold(FConfidence);
    Job.NmsThreshold := ReadThreshold(FNMS);
    FWorker.Submit(Job);
    ClearResult;
    FStopRequested := False;
    FStatus.Caption := 'Starting inference...';
    UpdateControls;
  except
    on E: Exception do ReportError(E.Message);
  end;
end;

procedure TOmDetForm.Stop(Sender: TObject);
begin
  FStopRequested := True;
  FWorker.Stop;
  FStatus.Caption := 'Stopping after the current native operation...';
  UpdateControls;
end;

procedure TOmDetForm.Unload(Sender: TObject);
var
  Job: TOmDetJob;
begin
  Job := Default(TOmDetJob);
  Job.Kind := ojUnload;
  FWorker.Submit(Job);
  UpdateControls;
end;

procedure TOmDetForm.Tick(Sender: TObject);
var
  Outcome: TOmDetOutcome;
  Bitmap: TBitmap;
  I: Integer;
  Status: string;
begin
  if FWorker.Collect(Outcome) then
  begin
    try
      FRequiresRestart := FRequiresRestart or Outcome.RequiresRestart;
      if Outcome.ErrorText <> '' then
        ReportError(Outcome.ErrorText)
      else if Outcome.Stopped then
        FStatus.Caption := 'Stopped. You can start again.'
      else if Outcome.Kind = ojUnload then
        FStatus.Caption := 'Model unloaded.'
      else begin
        Bitmap := OmDetOverlay(FImage, Outcome.Value);
        try
          FResult.Picture.Assign(Bitmap);
        finally
          Bitmap.Free;
        end;
        FGrid.RowCount := Max(2, Length(Outcome.Value.Detections) + 1);
        for I := 0 to High(Outcome.Value.Detections) do
        begin
          FGrid.Cells[0, I + 1] := UI(Outcome.Value.Labels[Outcome.Value.Detections[I].ClassIndex]);
          FGrid.Cells[1, I + 1] := UI(Format('%.3f', [Outcome.Value.Detections[I].Score],
            JSONInvariantFormat));
          FGrid.Cells[2, I + 1] := UI(Format('%.1f', [Outcome.Value.Detections[I].Left],
            JSONInvariantFormat));
          FGrid.Cells[3, I + 1] := UI(Format('%.1f', [Outcome.Value.Detections[I].Top],
            JSONInvariantFormat));
          FGrid.Cells[4, I + 1] := UI(Format('%.1f', [Outcome.Value.Detections[I].Right],
            JSONInvariantFormat));
          FGrid.Cells[5, I + 1] := UI(Format('%.1f', [Outcome.Value.Detections[I].Bottom],
            JSONInvariantFormat));
        end;
        FValue := Outcome.Value;
        FHasResult := True;
        Status := Format('%d objects  |  %s  |  %.2f s',
          [Length(FValue.Detections), FValue.Device, FValue.Milliseconds / 1000]);
        if FValue.Truncated then Status := Status + '  |  Text was truncated to 77 tokens.';
        FStatus.Caption := UI(Status);
      end;
    except
      on E: Exception do
      begin
        ClearResult;
        ReportError('Result preview: ' + E.Message);
      end;
    end;
    FStopRequested := False;
    UpdateControls;
    if FClosePending then Close;
  end
  else if FWorker.Busy and not FStopRequested then
    FStatus.Caption := UI(FWorker.Stage + '...');
end;

procedure TOmDetForm.Save(Sender: TObject);
var
  Dialog: TSaveDialog;
  Path: string;
begin
  if not FHasResult or FWorker.Busy then Exit;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Filter := 'Annotated image PNG|*.png|Result report JSON|*.json';
    Dialog.DefaultExt := 'png';
    Dialog.FileName := 'detections.png';
    Dialog.Options := [ofPathMustExist, ofEnableSizing];
    if Dialog.Execute then
    begin
      try
        Path := {$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName);
        if Dialog.FilterIndex = 2 then
        begin
          Path := ChangeFileExt(Path, '.json');
          SaveOmDetReport(Path, OmDetResultJSON(FValue, 'INFERRED'));
        end
        else begin
          Path := ChangeFileExt(Path, '.png');
          SaveOmDetPNG(Path, FResult.Picture.Bitmap);
        end;
        FStatus.Caption := UI('Saved ' + Path);
      except
        on E: Exception do ReportError('Could not save result: ' + E.Message);
      end;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TOmDetForm.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FWorker.Busy;
  if not CanClose then
  begin
    FClosePending := True;
    Stop(nil);
  end
  else begin
    CloseSession;
  end;
end;

end.
