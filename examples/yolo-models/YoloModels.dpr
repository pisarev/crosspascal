program YoloModels;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$APPTYPE GUI}
{$IFNDEF TVM_LAZY_INIT}
  {$MESSAGE ERROR 'Open the YoloModels project with its TVM_LAZY_INIT define'}
{$ENDIF}

uses
  {$IFDEF FPC}Interfaces, Windows, SysUtils, Forms, Dialogs{$ELSE}
  Winapi.Windows, System.SysUtils, Vcl.Forms, Vcl.Dialogs{$ENDIF},
  OpenCV, TVM.CpuGraph, TVM.NativeFiles, CrossPascal.NativeIO,
  YoloModels.Defaults in 'YoloModels.Defaults.pas',
  YoloModels.Config in 'YoloModels.Config.pas',
  YoloModels.Main in 'YoloModels.Main.pas',
  YoloModels.Run in 'YoloModels.Run.pas',
  YoloModels.Render in 'YoloModels.Render.pas',
  YoloModels.WindowsText in 'YoloModels.WindowsText.pas',
  YoloModels.Export in 'YoloModels.Export.pas',
  YoloModels.Worker in 'YoloModels.Worker.pas';

function Option(const Name: string): string;
var
  I: Integer;
  Prefix: string;
begin
  Result := '';
  Prefix := Name + '=';
  for I := 1 to NativeParamCount do
    if Copy(NativeParamStr(I), 1, Length(Prefix)) = Prefix then
      Exit(Copy(NativeParamStr(I), Length(Prefix) + 1, MaxInt));
end;

function PreparedDirectory: string;
var
  Directory, Parent: string;
  I: Integer;
  Dialog: TOpenDialog;
begin
  Result := Option('--prepared');
  if Result <> '' then Exit;
  Directory := ExtractFilePath(NativeParamStr(0));
  for I := 0 to 6 do
  begin
    if FileExists(IncludeTrailingPathDelimiter(Directory) + 'index.json') then Exit(Directory);
    Parent := ExtractFileDir(ExcludeTrailingPathDelimiter(Directory));
    if Parent = Directory then Break;
    Directory := Parent;
  end;
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Open the prepared YOLO index';
    Dialog.Filter := 'Prepared model index|index.json';
    Dialog.Options := [ofFileMustExist, ofPathMustExist, ofNoChangeDir];
    if Dialog.Execute then
      Result := ExtractFilePath({$IFDEF FPC}UTF8Decode{$ENDIF}(Dialog.FileName));
  finally
    Dialog.Free;
  end;
end;

procedure Run;
var
  Config: TYoloExampleConfig;
  Lease: INativeFileLease;
  Window: TYoloModelsForm;
  Directory, ErrorText: string;
begin
  Application.Initialize;
  {$IFNDEF FPC}Application.MainFormOnTaskbar := True;{$ENDIF}
  Application.Title := 'CrossPascal YOLO';
  Directory := PreparedDirectory;
  if Directory = '' then Exit;
  Config := CreateYoloPreparedConfig(Directory);
  try
    Lease := Config.HoldOpenCV;
    RequireCpu(CVInitialize(Lease.FileName), 'OpenCV initialization failed.');
    try
      RequireCpu(CVLibraryAbiVersion = CVSupportedAbiVersion,
        'The image runtime and Pascal bindings use different ABI versions.');
      Window := nil;
      try
        Application.CreateForm(TYoloModelsForm, Window);
        Window.Configure(Config, Lease.FileName);
        if Option('--image') <> '' then Window.LoadImage(Option('--image'));
        Application.Run;
        Window.CloseSession;
        ErrorText := Window.SessionError;
      finally
        Window.Free;
      end;
      RequireCpu(ErrorText = '', ErrorText);
    finally
      RequireCpu(CVLiveObjects = 0, 'Image objects remain alive before OpenCV finalization.');
      RequireCpu(CVFinalize, 'OpenCV release failed.');
    end;
  finally
    Lease := nil;
    Config.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      MessageBoxW(0, PWideChar(E.ClassName + ': ' + E.Message), 'CrossPascal YOLO', MB_OK or MB_ICONERROR);
      ExitCode := 1;
    end;
  end;
end.
