{ ************************************************************************** }
{                                                                            }
{ CrossPascalConvert.Native                                                  }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossPascalConvert.Native;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}Windows, SysUtils{$ELSE}Winapi.Windows, System.SysUtils{$ENDIF};

type
  TConverterProfile = (cpGemma3nCPU, cpGemma3nCUDA, cpGemma3nVision, cpGemma2, cpQwen2, cpQwenVL,
    cpYoloDetection, cpYoloClassification, cpRtDetr, cpSqueezeNet, cpResNet,
    cpGemma2CUDA, cpQwenVLCUDA, cpYoloDetectionCUDA, cpYoloClassificationCUDA, cpRtDetrCUDA,
    cpSqueezeNetCUDA, cpResNetCUDA, cpPaddleDetection, cpPaddleRecognition,
    cpPaddleDetectionCUDA, cpPaddleRecognitionCUDA);

  TConversionCommand = record
    Executable: string;
    Arguments: TArray<string>;
    Source: string;
    Destination: string;
    Profile: TConverterProfile;
  end;

const
  ProfileIDs: array[TConverterProfile] of string = (
    'gemma3n-cpu', 'gemma3n-cuda', 'gemma3n-add-vision', 'gemma2-cpu', 'qwen2-cuda', 'qwen-vl-cpu',
    'yolo11n', 'yolo11n-cls', 'rtdetr-r18vd', 'squeezenet', 'resnet50', 'gemma2-cuda', 'qwen-vl-cuda',
    'yolo11n-cuda', 'yolo11n-cls-cuda', 'rtdetr-r18vd-cuda', 'squeezenet-cuda', 'resnet50-cuda',
    'ppocrv5-server-det', 'ppocrv5-server-rec', 'ppocrv5-server-det-cuda', 'ppocrv5-server-rec-cuda');
  ProfileTitles: array[TConverterProfile] of string = (
    'Gemma 3n E4B | CPU',
    'Gemma 3n E4B | CUDA',
    'Gemma 3n | Add image support',
    'Gemma 2 | CPU',
    'Qwen2.5 dense text | CUDA',
    'Qwen2.5-VL 3B | CPU',
    'YOLO11n detection | CPU',
    'YOLO11n classification | CPU',
    'RT-DETR R18vd | CPU',
    'SqueezeNet 1.1 | CPU',
    'ResNet50 v1 | CPU',
    'Gemma 2 | CUDA',
    'Qwen2.5-VL 3B | CUDA',
    'YOLO11n detection | CUDA',
    'YOLO11n classification | CUDA',
    'RT-DETR R18vd | CUDA',
    'SqueezeNet 1.1 | CUDA',
    'ResNet50 v1 | CUDA',
    'PP-OCRv5 Server detection | CPU',
    'PP-OCRv5 Server recognition | CPU',
    'PP-OCRv5 Server detection | CUDA',
    'PP-OCRv5 Server recognition | CUDA');

function ExecutableFolder: string;
function UsesCUDA(const Profile: TConverterProfile): Boolean;
function SourceProfile(const Profile: TConverterProfile): TConverterProfile;
function NeedsProjector(const Profile: TConverterProfile): Boolean;
function PrepareConversion(const Root, Source, Projector, Destination, Architecture: string;
  const Profile: TConverterProfile; const Context, Chunk: Integer): TConversionCommand;
function StartConversion(const Command: TConversionCommand; out LogFile: string): THandle;

implementation

function ExecutableFolder: string;
var
  Buffer: array[0..32767] of WideChar;
  Count: DWORD;
begin
  Count := GetModuleFileNameW(0, @Buffer[0], Length(Buffer));
  if Count = 0 then RaiseLastOSError;
  if Count >= Length(Buffer) then raise Exception.Create('The application path is too long.');
  SetString(Result, PWideChar(@Buffer[0]), Count);
  Result := ExtractFilePath(Result);
end;

function UsesCUDA(const Profile: TConverterProfile): Boolean;
begin
  Result := Profile in [cpGemma3nCUDA, cpQwen2, cpGemma2CUDA..cpResNetCUDA,
    cpPaddleDetectionCUDA, cpPaddleRecognitionCUDA];
end;

function SourceProfile(const Profile: TConverterProfile): TConverterProfile;
begin
  case Profile of
    cpGemma2CUDA: Result := cpGemma2;
    cpQwenVLCUDA: Result := cpQwenVL;
    cpYoloDetectionCUDA: Result := cpYoloDetection;
    cpYoloClassificationCUDA: Result := cpYoloClassification;
    cpRtDetrCUDA: Result := cpRtDetr;
    cpSqueezeNetCUDA: Result := cpSqueezeNet;
    cpResNetCUDA: Result := cpResNet;
    cpPaddleDetectionCUDA: Result := cpPaddleDetection;
    cpPaddleRecognitionCUDA: Result := cpPaddleRecognition;
  else
    Result := Profile;
  end;
end;

function NeedsProjector(const Profile: TConverterProfile): Boolean;
begin
  Result := Profile in [cpGemma3nCPU, cpGemma3nCUDA, cpGemma3nVision];
end;

function Unquoted(const Input: string): string;
begin
  Result := Trim(Input);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
  if Pos('"', Result) <> 0 then raise Exception.Create('A file path contains a quotation mark.');
end;

function RequireFile(const Name, Description: string): string;
var
  Attr: DWORD;
begin
  Attr := GetFileAttributesW(PWideChar(Name));
  if (Attr = INVALID_FILE_ATTRIBUTES) or ((Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0) then
    raise Exception.Create(Description + ' was not found at ' + Name);
  Result := Name;
end;

function ReadToolPath(const Kit, Key, Fallback: string): string;
var
  Buffer: array[0..32767] of WideChar;
  Value, Ini: string;
  Count: DWORD;
begin
  Value := GetEnvironmentVariable('CROSSPASCAL_NATIVE_' + UpperCase(Key));
  if Value = '' then
  begin
    Ini := Kit + 'toolchain.ini';
    Count := GetPrivateProfileStringW('toolchain', PWideChar(Key), PWideChar(Fallback), @Buffer[0],
      Length(Buffer), PWideChar(Ini));
    SetString(Value, PWideChar(@Buffer[0]), Count);
  end;
  Value := Unquoted(Value);
  if (Value <> '') and (ExtractFileDrive(Value) = '') then Value := Kit + Value;
  Result := ExcludeTrailingPathDelimiter(Value);
end;

function NewestVersionDirectory(const Root, RequiredFile: string): string;
var
  Item: TSearchRec;
  Candidate: string;
  Status: Integer;
begin
  Result := '';
  Status := FindFirst(IncludeTrailingPathDelimiter(Root) + '*', faDirectory, Item);
  if Status <> 0 then Exit;
  try
    repeat
      Candidate := IncludeTrailingPathDelimiter(Root) + Item.Name + '\';
      if ((Item.Attr and faDirectory) <> 0) and (Item.Name <> '.') and (Item.Name <> '..') and
        FileExists(Candidate + RequiredFile) and (CompareText(Candidate, Result) > 0) then
          Result := Candidate;
      Status := FindNext(Item);
    until Status <> 0;
  finally
    FindClose(Item);
  end;
end;

function MsvcRoot: string;
const
  Editions: array[0..3] of string = ('BuildTools', 'Community', 'Professional', 'Enterprise');
  Years: array[0..1] of string = ('2022', '2019');
var
  ProgramFiles, Edition, Year: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('VCToolsInstallDir'));
  if FileExists(Result + 'bin\Hostx64\x64\link.exe') then Exit;
  for Year in Years do
  begin
    if Year = '2022' then
      ProgramFiles := GetEnvironmentVariable('ProgramFiles')
    else
      ProgramFiles := GetEnvironmentVariable('ProgramFiles(x86)');
    for Edition in Editions do
    begin
      Result := NewestVersionDirectory(
        IncludeTrailingPathDelimiter(ProgramFiles) + 'Microsoft Visual Studio\' + Year + '\' + Edition + '\VC\Tools\MSVC',
        'bin\Hostx64\x64\link.exe'
      );
      if Result <> '' then Exit;
    end;
  end;
  Result := '';
end;

function CompilerArguments(const Kit: string): TArray<string>;
var
  Compiler, Linker, Ffi, Msvc, SDK, UCRT, WindowsLib: string;
begin
  Compiler := ReadToolPath(Kit, 'COMPILER', 'compiler');
  RequireFile(IncludeTrailingPathDelimiter(Compiler) + 'tvm_compiler.dll', 'The native TVM compiler');
  Ffi := RequireFile(ReadToolPath(Kit, 'FFI_LIB', 'compiler\tvm_ffi.lib'), 'The TVM import library');
  Msvc := MsvcRoot;
  Linker := RequireFile(ReadToolPath(Kit, 'LINKER', Msvc + 'bin\Hostx64\x64\link.exe'), 'The x64 linker');
  Msvc := ReadToolPath(Kit, 'MSVC_LIB', Msvc + 'lib\x64');
  RequireFile(IncludeTrailingPathDelimiter(Msvc) + 'libcmt.lib', 'The x64 MSVC runtime library');
  SDK := NewestVersionDirectory(IncludeTrailingPathDelimiter(GetEnvironmentVariable('ProgramFiles(x86)')) + 'Windows Kits\10\Lib',
    'ucrt\x64\libucrt.lib');
  UCRT := ReadToolPath(Kit, 'UCRT_LIB', SDK + 'ucrt\x64');
  WindowsLib := ReadToolPath(Kit, 'WINDOWS_LIB', SDK + 'um\x64');
  RequireFile(IncludeTrailingPathDelimiter(UCRT) + 'libucrt.lib', 'The x64 Windows SDK UCRT library');
  RequireFile(IncludeTrailingPathDelimiter(WindowsLib) + 'kernel32.lib',
    'The x64 Windows SDK import library');
  Result := [Compiler, Linker, Ffi, Msvc, UCRT, WindowsLib];
end;

function SelectOnnx(const Source: string): string;
var
  Item: TSearchRec;
  Status: Integer;
begin
  if not DirectoryExists(Source) then Exit(RequireFile(Source, 'The source model'));
  Result := '';
  Status := FindFirst(IncludeTrailingPathDelimiter(Source) + '*.onnx', faAnyFile, Item);
  if Status <> 0 then raise Exception.Create('The selected source directory has no ONNX model.');
  try
    repeat
      if (Item.Attr and faDirectory) = 0 then
      begin
        if Result <> '' then raise Exception.Create('Select the ONNX file in the source folder.');
        Result := IncludeTrailingPathDelimiter(Source) + Item.Name;
      end;
      Status := FindNext(Item);
    until Status <> 0;
  finally
    FindClose(Item);
  end;
  if Result = '' then raise Exception.Create('The selected source directory has no ONNX model.');
end;

function DefaultNvrtc: string;
var
  CudaRoot: string;
begin
  CudaRoot := GetEnvironmentVariable('CUDA_PATH_V12_8');
  if CudaRoot = '' then CudaRoot := GetEnvironmentVariable('CUDA_PATH');
  Result := IncludeTrailingPathDelimiter(CudaRoot) + 'bin\nvrtc64_120_0.dll';
end;

function PrepareConversion(const Root, Source, Projector, Destination, Architecture: string;
  const Profile: TConverterProfile; const Context, Chunk: Integer): TConversionCommand;
const
  VisionIDs: array[cpYoloDetection..cpResNet] of string = ('yolo11n', 'yolo11n-cls', 'rtdetr-r18vd', 'squeezenet', 'resnet50');
var
  Kit, Tool, InputPath, Output, CUDA, Arch, VisionFile, Recipe, Ggml, SentencePiece: string;
  Args, LinkArgs: TArray<string>;
  I: Integer;
  Kind: TConverterProfile;
begin
  if (Unquoted(Source) = '') or (Unquoted(Destination) = '') then
    raise Exception.Create('Enter the original model path and a new output folder.');
  InputPath := ExpandFileName(Unquoted(Source));
  Output := ExcludeTrailingPathDelimiter(ExpandFileName(Unquoted(Destination)));
  if DirectoryExists(Output) or FileExists(Output) or not DirectoryExists(ExtractFileDir(Output)) then
    raise Exception.Create('Choose a new output folder in an existing directory.');
  Kit := IncludeTrailingPathDelimiter(Root) + 'runtime\converter\';
  LinkArgs := CompilerArguments(Kit);
  if UsesCUDA(Profile) then
  begin
    Arch := Trim(Architecture);
    if (Copy(Arch, 1, 3) <> 'sm_') or not (Length(Arch) in [5, 6]) then
      raise Exception.Create('Enter a CUDA architecture such as sm_89.');
    for I := 4 to Length(Arch) do
      if not CharInSet(Arch[I], ['0'..'9']) then
        raise Exception.Create('The CUDA architecture must contain a numeric compute capability.');
    CUDA := RequireFile(
      ReadToolPath(
        Kit,
        'NVRTC',
        DefaultNvrtc
      ),
      'NVIDIA NVRTC'
    );
  end;
  Kind := SourceProfile(Profile);
  case Kind of
    cpGemma3nCPU, cpGemma3nCUDA, cpGemma3nVision:
      begin
        Tool := 'ConvertGemma3n.exe';
        VisionFile := Unquoted(Projector);
        if VisionFile = '' then
          VisionFile := '-'
        else
          VisionFile := RequireFile(ExpandFileName(VisionFile), 'The Gemma 3n projector GGUF');
        Recipe := ReadToolPath(Kit, 'GEMMA3N_PROFILE', 'profiles\gemma3n');
        RequireFile(IncludeTrailingPathDelimiter(Recipe) + 'recipe.json', 'The Gemma 3n recipe');
        Ggml := RequireFile(ReadToolPath(Kit, 'GGML', 'ggml-base.dll'), 'The GGML reader');
        SentencePiece := RequireFile(ReadToolPath(Kit, 'SENTENCEPIECE', '..\gemma-native\crosspascal_sentencepiece.dll'),
          'SentencePiece');
        if Profile = cpGemma3nVision then
        begin
          RequireFile(IncludeTrailingPathDelimiter(InputPath) + 'model.json', 'The Gemma 3n text manifest');
          if VisionFile = '-' then raise Exception.Create('Select the projector GGUF.');
          Args := ['--attach-vision', InputPath, VisionFile, Recipe, Output, Ggml, SentencePiece] +
            LinkArgs;
          CUDA := ReadToolPath(Kit, 'NVRTC', DefaultNvrtc);
          if FileExists(CUDA) then Args := Args + [CUDA];
        end
        else begin
          Args := [RequireFile(InputPath, 'The Gemma 3n checkpoint GGUF'), VisionFile, Recipe, Output, Ggml, SentencePiece] + LinkArgs;
          if UsesCUDA(Profile) then Args := Args + ['--cuda', CUDA, Arch];
          if Context <> 0 then
          begin
            if (Context < 2) or ((Profile = cpGemma3nCPU) and ((Chunk < 2) or
              (Chunk > Context))) then
                raise Exception.Create('Enter a valid context and prefill size.');
            Args := Args + ['--context', IntToStr(Context), IntToStr(Chunk)];
          end;
        end;
      end;
    cpGemma2, cpQwen2:
      begin
        RequireFile(IncludeTrailingPathDelimiter(InputPath) + 'config.json', 'The checkpoint configuration');
        if (Context < 2) or (Chunk < 2) or (Chunk > Context) then
          raise Exception.Create('Enter a prefill size from 2 to the requested context size.');
        Args := [InputPath, Output, IntToStr(Context), IntToStr(Chunk)] + LinkArgs;
        if Kind = cpGemma2 then
        begin
          Tool := 'ConvertGemma2.exe';
          if UsesCUDA(Profile) then Args := Args + ['--cuda', CUDA, Arch];
        end
        else begin
          Tool := 'ConvertQwen2.exe';
          Args := Args + [CUDA, Arch];
        end;
      end;
    cpQwenVL:
      begin
        Tool := 'ConvertQwenVLProfile.exe';
        RequireFile(IncludeTrailingPathDelimiter(InputPath) + 'config.json', 'The checkpoint configuration');
        Recipe := ReadToolPath(Kit, 'QWEN_VL_PROFILE', 'profiles\qwen-vl');
        RequireFile(IncludeTrailingPathDelimiter(Recipe) + 'model.json', 'The Qwen2.5-VL recipe');
        Args := [InputPath, Recipe, Output] + LinkArgs;
        if UsesCUDA(Profile) then Args := Args + ['--cuda', CUDA, Arch];
      end;
    cpPaddleDetection, cpPaddleRecognition:
      begin
        Tool := 'ConvertVisionOnnx.exe';
        InputPath := SelectOnnx(InputPath);
        Recipe := RequireFile(IncludeTrailingPathDelimiter(Root) +
          'crosspascal\examples\paddle-ocr\models.json', 'The PaddleOCR profile catalog');
        if Kind = cpPaddleRecognition then
          RequireFile(ExtractFilePath(InputPath) + 'ppocrv5_dict.txt',
            'The PaddleOCR dictionary beside the ONNX model');
        Args := [InputPath, Recipe, ProfileIDs[Kind], Output] + LinkArgs;
        if UsesCUDA(Profile) then Args := Args + ['--cuda', CUDA, Arch];
      end;
  else begin
      Tool := 'ConvertVisionOnnx.exe';
      if (Kind = cpRtDetr) and DirectoryExists(InputPath) and
        FileExists(IncludeTrailingPathDelimiter(InputPath) + 'model.safetensors') then
          InputPath := IncludeTrailingPathDelimiter(InputPath) + 'model.safetensors'
      else
        InputPath := SelectOnnx(InputPath);
      Recipe := RequireFile(IncludeTrailingPathDelimiter(Root) +
        'crosspascal\examples\vision-models\models.json', 'The vision profile catalog');
      Args := [InputPath, Recipe, VisionIDs[Kind], Output] + LinkArgs;
      if SameText(ExtractFileExt(InputPath), '.pt') and
        (Kind in [cpYoloDetection, cpYoloClassification]) then
          Args := Args + [RequireFile(Kit + 'profiles\' + VisionIDs[Kind] + '\model.onnx',
            'The YOLO graph recipe')];
      if SameText(ExtractFileExt(InputPath), '.safetensors') and (Kind = cpRtDetr) then
      begin
        Recipe := Kit + 'profiles\rtdetr-r18vd\';
        RequireFile(Recipe + 'bindings.json', 'The RT-DETR weight bindings');
        Args := Args + [RequireFile(Recipe + 'model.onnx', 'The RT-DETR graph recipe')];
      end;
      if UsesCUDA(Profile) then Args := Args + ['--cuda', CUDA, Arch];
    end;
  end;
  Result.Executable := RequireFile(Kit + Tool, 'The conversion executable');
  Result.Arguments := Args;
  Result.Source := InputPath;
  Result.Destination := Output;
  Result.Profile := Profile;
end;

function QuoteArgument(const Value: string): string;
var
  I: Integer;
begin
  I := Length(Value);
  while (I > 0) and (Value[I] = '\') do Dec(I);
  Result := '"' + Value + StringOfChar('\', Length(Value) - I) + '"';
end;

function StartConversion(const Command: TConversionCommand; out LogFile: string): THandle;
var
  Startup: TStartupInfoW;
  ProcessInfo: TProcessInformation;
  Security: TSecurityAttributes;
  FileHandle: THandle;
  Argument, CommandLine, Folder: string;
  ID: TGUID;
begin
  if CreateGUID(ID) <> 0 then raise Exception.Create('Could not name the conversion log.');
  Folder := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
    'CrossPascal\Convert\logs';
  if not ForceDirectories(Folder) then
    raise Exception.Create('Could not create the conversion log folder.');
  LogFile := IncludeTrailingPathDelimiter(Folder) + GUIDToString(ID) + '.log';
  FillChar(Security, SizeOf(Security), 0);
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;
  FileHandle := CreateFileW(PWideChar(LogFile), GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE,
    @Security, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
  if FileHandle = INVALID_HANDLE_VALUE then RaiseLastOSError;
  try
    CommandLine := QuoteArgument(Command.Executable);
    for Argument in Command.Arguments do CommandLine := CommandLine + ' ' + QuoteArgument(Argument);
    UniqueString(CommandLine);
    Folder := ExtractFileDir(Command.Executable);
    FillChar(Startup, SizeOf(Startup), 0);
    Startup.cb := SizeOf(Startup);
    Startup.dwFlags := STARTF_USESTDHANDLES;
    Startup.hStdOutput := FileHandle;
    Startup.hStdError := FileHandle;
    FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
    if not CreateProcessW(PWideChar(Command.Executable), PWideChar(CommandLine), nil, nil, True,
      CREATE_NO_WINDOW, nil, PWideChar(Folder), Startup, ProcessInfo) then RaiseLastOSError;
    CloseHandle(ProcessInfo.hThread);
    Result := ProcessInfo.hProcess;
  finally
    CloseHandle(FileHandle);
  end;
end;

end.
