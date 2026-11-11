{ ************************************************************************** }
{                                                                            }
{ CrossPascalConvert.Form                                                    }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossPascalConvert.Form;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Windows, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls
  {$ELSE}Winapi.Windows, System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls{$ENDIF},
  CrossPascalConvert.Native;

type
  TConverterForm = class(TForm)
  private
    FProfile: TComboBox;
    FSourceLabel: TLabel;
    FSource: TEdit;
    FProjector: TEdit;
    FOutput: TEdit;
    FArchitecture: TEdit;
    FContext: TEdit;
    FChunk: TEdit;
    FProjectorBrowse: TButton;
    FPreview: TButton;
    FBuild: TButton;
    FOpenOutput: TButton;
    FReport: TMemo;
    FTimer: TTimer;
    FProcess: THandle;
    FLogFile: string;
    FLogSize: Int64;
    FDestination: string;
    function Selected: TConverterProfile;
    function AddLabel(const CaptionText: string; const Left, Top: Integer): TLabel;
    function AddEdit(const Left, Top, Width: Integer; const Stretch: Boolean): TEdit;
    function AddButton(const CaptionText: string; const Left, Top: Integer;
      const OnPressed: TNotifyEvent; const OnRight: Boolean = False): TButton;
    function Request: TConversionCommand;
    procedure ProfileChanged(Sender: TObject);
    procedure BrowseSource(Sender: TObject);
    procedure BrowseProjector(Sender: TObject);
    procedure BrowseOutput(Sender: TObject);
    procedure Preview(Sender: TObject);
    procedure Build(Sender: TObject);
    procedure ShowOutput(Sender: TObject);
    procedure UpdateProgress(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  ConverterForm: TConverterForm;

implementation

uses
  {$IFDEF FPC}Dialogs, ShellAPI{$ELSE}Vcl.Dialogs, Vcl.FileCtrl, Winapi.ShellAPI{$ENDIF};

const
  Margin = 16;
  ButtonWidth = 112;
  ControlHeight = 30;
  FieldWidth = 482;
  RightButton = Margin + FieldWidth + 8;

function UIString(const Value: UnicodeString): {$IFDEF FPC}UTF8String{$ELSE}string{$ENDIF};
begin
  {$IFDEF FPC}Result := UTF8Encode(Value);
  {$ELSE}Result := Value;{$ENDIF}
end;

function EditText(const Edit: TEdit): string;
begin
  {$IFDEF FPC}Result := UTF8Decode(Edit.Text);
  {$ELSE}Result := Edit.Text;{$ENDIF}
end;

function SelectFolder(const Title: string; var Folder: string): Boolean;
{$IFDEF FPC}
var
  Dialog: TSelectDirectoryDialog;
{$ENDIF}
begin
  {$IFDEF FPC}
  Dialog := TSelectDirectoryDialog.Create(nil);
  try
    Dialog.Title := UIString(Title);
    if DirectoryExists(Folder) then Dialog.InitialDir := UIString(Folder);
    Result := Dialog.Execute;
    if Result then Folder := UTF8Decode(Dialog.FileName);
  finally
    Dialog.Free;
  end;
  {$ELSE}
  Result := Vcl.FileCtrl.SelectDirectory(Title, '', Folder);
  {$ENDIF}
end;

function SelectFile(const Title, Filter: string; var FileName: string): Boolean;
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := UIString(Title);
    Dialog.Filter := UIString(Filter);
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofPathMustExist, ofNoChangeDir];
    Dialog.FileName := UIString(FileName);
    Result := Dialog.Execute;
    if Result then
      {$IFDEF FPC}FileName := UTF8Decode(Dialog.FileName);
      {$ELSE}FileName := Dialog.FileName;{$ENDIF}
  finally
    Dialog.Free;
  end;
end;

function TConverterForm.AddLabel(const CaptionText: string; const Left, Top: Integer): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := Self;
  Result.Caption := UIString(CaptionText);
  Result.Left := Left;
  Result.Top := Top;
end;

function TConverterForm.AddEdit(const Left, Top, Width: Integer; const Stretch: Boolean): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := Self;
  Result.AutoSize := False;
  Result.SetBounds(Left, Top, Width, ControlHeight);
  if Stretch then Result.Anchors := [akLeft, akTop, akRight];
end;

function TConverterForm.AddButton(const CaptionText: string; const Left, Top: Integer;
  const OnPressed: TNotifyEvent; const OnRight: Boolean): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Self;
  Result.Caption := UIString(CaptionText);
  Result.SetBounds(Left, Top, ButtonWidth, ControlHeight);
  if OnRight then Result.Anchors := [akTop, akRight];
  Result.OnClick := OnPressed;
end;

constructor TConverterForm.Create(AOwner: TComponent);
var
  Profile: TConverterProfile;
begin
  inherited CreateNew(AOwner);
  Caption := 'CrossPascal Converter';
  Position := poScreenCenter;
  ClientWidth := RightButton + ButtonWidth + Margin;
  ClientHeight := 542;
  Constraints.MinWidth := ClientWidth;
  Constraints.MinHeight := 450;
  AddLabel('Model profile', Margin, 12);
  FProfile := TComboBox.Create(Self);
  FProfile.Parent := Self;
  FProfile.Style := csDropDownList;
  FProfile.SetBounds(Margin, 32, FieldWidth, ControlHeight);
  FProfile.Anchors := [akLeft, akTop, akRight];
  for Profile := Low(TConverterProfile) to High(TConverterProfile) do
    FProfile.Items.Add(UIString(ProfileTitles[Profile]));
  FProfile.ItemIndex := 0;
  FProfile.OnChange := ProfileChanged;
  FSourceLabel := AddLabel('Original checkpoint', Margin, 72);
  FSource := AddEdit(Margin, 92, FieldWidth, True);
  AddButton('Browse...', RightButton, 92, BrowseSource, True);
  AddLabel('Image projector (optional)', Margin, 134);
  FProjector := AddEdit(Margin, 154, FieldWidth, True);
  FProjectorBrowse := AddButton('Browse...', RightButton, 154, BrowseProjector, True);
  AddLabel('New output folder', Margin, 196);
  FOutput := AddEdit(Margin, 216, FieldWidth, True);
  AddButton('Choose parent...', RightButton, 216, BrowseOutput, True);
  AddLabel('CUDA target', Margin, 258);
  FArchitecture := AddEdit(Margin, 278, ButtonWidth, False);
  FArchitecture.Text := 'sm_89';
  AddLabel('Context tokens', Margin + 128, 258);
  FContext := AddEdit(Margin + 128, 278, ButtonWidth, False);
  FContext.Text := '2048';
  AddLabel('Prefill tokens', Margin + 256, 258);
  FChunk := AddEdit(Margin + 256, 278, ButtonWidth, False);
  FChunk.Text := '16';
  FPreview := AddButton('Preview', Margin, 324, Preview);
  FBuild := AddButton('Build', Margin + 120, 324, Build);
  FOpenOutput := AddButton('Open output', Margin + 240, 324, ShowOutput);
  FOpenOutput.Enabled := False;
  FReport := TMemo.Create(Self);
  FReport.Parent := Self;
  FReport.SetBounds(Margin, 366, ClientWidth - 2 * Margin, ClientHeight - 382);
  FReport.Anchors := [akLeft, akTop, akRight, akBottom];
  FReport.ReadOnly := True;
  FReport.ScrollBars := ssBoth;
  FReport.WordWrap := False;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 300;
  FTimer.Enabled := False;
  FTimer.OnTimer := UpdateProgress;
  ProfileChanged(nil);
end;

destructor TConverterForm.Destroy;
begin
  if FProcess <> 0 then CloseHandle(FProcess);
  inherited;
end;

function TConverterForm.Selected: TConverterProfile;
begin
  Result := TConverterProfile(FProfile.ItemIndex);
end;

procedure TConverterForm.ProfileChanged(Sender: TObject);
var
  Profile: TConverterProfile;
begin
  Profile := SourceProfile(Selected);
  if Profile = cpGemma3nVision then
    FSourceLabel.Caption := 'Existing Gemma 3n text bundle'
  else if NeedsProjector(Profile) then
      FSourceLabel.Caption := 'Original GGUF checkpoint'
    else if Profile in [cpGemma2, cpQwen2, cpQwenVL] then
        FSourceLabel.Caption := 'Original Safetensors folder'
      else if Profile in [cpYoloDetection, cpYoloClassification] then
          FSourceLabel.Caption := 'Original YOLO checkpoint or ONNX file'
        else if Profile = cpRtDetr then
            FSourceLabel.Caption := 'Original RT-DETR Safetensors or ONNX file'
          else
            FSourceLabel.Caption := 'Original ONNX file or source-pack folder';
  FProjector.Enabled := NeedsProjector(Profile);
  FProjectorBrowse.Enabled := FProjector.Enabled;
  FArchitecture.Enabled := UsesCUDA(Selected);
  FContext.Enabled := Profile in [cpGemma3nCPU, cpGemma3nCUDA, cpGemma2, cpQwen2];
  FChunk.Enabled := Profile in [cpGemma3nCPU, cpGemma2, cpQwen2];
  if Profile in [cpGemma3nCPU, cpGemma3nCUDA] then
    FContext.Text := '1024'
  else if FContext.Enabled then
      FContext.Text := '2048';
end;

procedure TConverterForm.BrowseSource(Sender: TObject);
var
  Path: string;
  Profile: TConverterProfile;
begin
  Path := EditText(FSource);
  Profile := SourceProfile(Selected);
  if Profile = cpGemma3nVision then
  begin
    if not SelectFolder('Select the Gemma 3n text bundle', Path) then Exit;
  end
  else if NeedsProjector(Profile) then
    begin
      if not SelectFile('Select the original GGUF checkpoint', 'GGUF models (*.gguf)|*.gguf', Path) then
        Exit;
    end
    else if Profile in [cpGemma2, cpQwen2, cpQwenVL] then
      begin
        if not SelectFolder('Select the original Safetensors folder', Path) then Exit;
      end
      else if Profile in [cpYoloDetection, cpYoloClassification] then
        begin
          if not SelectFile('Select the original YOLO checkpoint',
            'YOLO models (*.pt;*.onnx)|*.pt;*.onnx', Path) then
              Exit;
        end
        else if Profile = cpRtDetr then
          begin
            if not SelectFile('Select the original RT-DETR checkpoint',
              'RT-DETR models (*.safetensors;*.onnx)|*.safetensors;*.onnx', Path) then Exit;
          end
          else if not SelectFile('Select the original ONNX file', 'ONNX models (*.onnx)|*.onnx', Path) then
              Exit;
  FSource.Text := UIString(Path);
end;

procedure TConverterForm.BrowseProjector(Sender: TObject);
var
  Path: string;
begin
  Path := EditText(FProjector);
  if SelectFile('Select the image projector GGUF', 'GGUF models (*.gguf)|*.gguf', Path) then
    FProjector.Text := UIString(Path);
end;

procedure TConverterForm.BrowseOutput(Sender: TObject);
var
  Path: string;
begin
  Path := ExtractFileDir(EditText(FOutput));
  if SelectFolder('Select the parent of the new bundle directory', Path) then
    FOutput.Text := UIString(IncludeTrailingPathDelimiter(Path) + 'tvm-model');
end;

function TConverterForm.Request: TConversionCommand;
begin
  Result := PrepareConversion(
    ExecutableFolder,
    EditText(FSource),
    EditText(FProjector),
    EditText(FOutput),
    EditText(FArchitecture),
    Selected,
    StrToIntDef(
      EditText(FContext),
      0
    ),
    StrToIntDef(
      EditText(FChunk),
      0
    )
  );
end;

procedure TConverterForm.Preview(Sender: TObject);
var
  Command: TConversionCommand;
begin
  try
    Command := Request;
    FReport.Text := UIString(ProfileTitles[Command.Profile] + sLineBreak + sLineBreak +
      'Source  ' + Command.Source + sLineBreak + 'Output  ' + Command.Destination + sLineBreak +
      'Compiler  ' + ExtractFileName(Command.Executable));
  except
    on E: Exception do FReport.Text := UIString(E.Message);
  end;
end;

procedure TConverterForm.Build(Sender: TObject);
var
  Command: TConversionCommand;
begin
  if FProcess <> 0 then Exit;
  try
    Command := Request;
    FProcess := StartConversion(Command, FLogFile);
    FDestination := Command.Destination;
    FLogSize := -1;
    FBuild.Enabled := False;
    FPreview.Enabled := False;
    FOpenOutput.Enabled := False;
    FReport.Text := UIString('Building ' + ProfileTitles[Command.Profile] + sLineBreak + 'Log  ' + FLogFile);
    FTimer.Enabled := True;
  except
    on E: Exception do FReport.Text := UIString(E.Message);
  end;
end;

procedure TConverterForm.UpdateProgress(Sender: TObject);
const
  MaxVisibleBytes = 128 * 1024;
var
  Stream: TFileStream;
  Raw: UTF8String;
  Size: Int64;
  Status: DWORD;
begin
  try
    Stream := TFileStream.Create(FLogFile, fmOpenRead or fmShareDenyNone);
    try
      Size := Stream.Size;
      if (Size > 0) and (Size <> FLogSize) then
      begin
        if Size > MaxVisibleBytes then Stream.Position := Size - MaxVisibleBytes;
        SetLength(Raw, Size - Stream.Position);
        Stream.ReadBuffer(Raw[1], Length(Raw));
        FReport.Text := UIString(UTF8Decode(Raw));
        FReport.SelStart := Length(FReport.Text);
        FLogSize := Size;
      end;
    finally
      Stream.Free;
    end;
  except
    on EFOpenError do;
  end;
  if WaitForSingleObject(FProcess, 0) <> WAIT_OBJECT_0 then Exit;
  if not GetExitCodeProcess(FProcess, Status) then Status := DWORD(-1);
  CloseHandle(FProcess);
  FProcess := 0;
  FTimer.Enabled := False;
  FBuild.Enabled := True;
  FPreview.Enabled := True;
  FOpenOutput.Enabled := (Status = 0) and DirectoryExists(FDestination);
  if FOpenOutput.Enabled then
    FReport.Lines.Add(UIString('Bundle ready  ' + FDestination))
  else
    FReport.Lines.Add(UIString('Conversion ended with exit code ' + IntToStr(Status) + '. Log  ' + FLogFile));
end;

procedure TConverterForm.ShowOutput(Sender: TObject);
begin
  if DirectoryExists(FDestination) then
    ShellExecuteW(Handle, 'open', PWideChar(FDestination), nil, nil, SW_SHOWNORMAL);
end;

end.
