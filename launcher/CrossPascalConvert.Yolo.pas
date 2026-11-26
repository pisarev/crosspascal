unit CrossPascalConvert.Yolo;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  CrossPascalConvert.Native, YoloModels.Config;

type
  { Optional additive catalog. Legacy language profiles and their ordinal
    values are unchanged. Conversion uses the complete trusted catalog. }
  TYoloConverter = class
  private
    FConfig: TYoloExampleConfig;
  public
    constructor Create(const Root: string);
    destructor Destroy; override;
    function Count: Integer;
    function Find(const ProfileID, Device: string): Integer;
    function Title(const Index: Integer): string;
    function UsesCUDA(const Index: Integer): Boolean;
    function Prepare(const Index: Integer;
      const Source, Destination, Architecture: string): TConversionCommand;
  end;

implementation

uses
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF}, CrossPascal.Json,
  TVM.NativeFiles, TVM.Yolo.Profile, YoloModels.Defaults, CrossPascal.NativeIO;

function TaskTitle(const Task: TYoloTask): string;
begin
  case Task of
    ytClassification: Result := 'classification';
    ytDetection: Result := 'detection';
    ytInstances: Result := 'instance segmentation';
    ytPose: Result := 'pose';
    ytOriented: Result := 'oriented detection';
    ytSemantic: Result := 'semantic segmentation';
    ytDepth: Result := 'depth';
  end;
end;

constructor TYoloConverter.Create(const Root: string);
begin
  inherited Create;
  FConfig := CreateYoloPreparedConfig(Root, True);
end;

destructor TYoloConverter.Destroy;
begin
  FConfig.Free;
  inherited;
end;

function TYoloConverter.Count: Integer;
begin
  Result := FConfig.ProfileCount * 2;
end;

function TYoloConverter.Find(const ProfileID, Device: string): Integer;
var
  I: Integer;
begin
  NativeRequire((Device = 'cpu') or (Device = 'cuda'), 'Choose the CPU or CUDA conversion target.');
  for I := 0 to FConfig.ProfileCount - 1 do
    if FConfig.Profile(I).ID = ProfileID then
    begin
      Result := I * 2;
      if Device = 'cuda' then Inc(Result);
      Exit;
    end;
  raise ENativePackage.Create('Unknown YOLO conversion profile: ' + ProfileID);
end;

function TYoloConverter.UsesCUDA(const Index: Integer): Boolean;
begin
  NativeRequire((Index >= 0) and (Index < Count), 'Choose a YOLO conversion profile.');
  Result := Odd(Index);
end;

function TYoloConverter.Title(const Index: Integer): string;
var
  Profile: TYoloProfile;
begin
  Profile := FConfig.Profile(Index div 2);
  Result := Profile.ID + ' ' + TaskTitle(Profile.Task) + ' | ';
  if UsesCUDA(Index) then
    Result := Result + 'CUDA'
  else
    Result := Result + 'CPU';
end;

function TYoloConverter.Prepare(const Index: Integer;
  const Source, Destination, Architecture: string): TConversionCommand;
var
  Profile: TYoloProfile;
  Bundle: TYoloExampleBundle;
  Manifest, Runtime, Request, Compiler, Cuda: TJSONObject;
  Lease: INativeFileLease;
  Paths: TArray<string>;
  Checkpoint, Output, Target, Recipe, Tool, Folder, Name: string;
  ID: TGUID;
  Stream: TStream;
  Bytes: TBytes;
begin
  Profile := FConfig.Profile(Index div 2);
  NativeRequire((Trim(Source) <> '') and (Trim(Destination) <> ''),
    'Choose the original checkpoint and a new output folder.');
  Checkpoint := ExpandFileName(Source);
  Output := ExcludeTrailingPathDelimiter(ExpandFileName(Destination));
  NativeRequire(FileExists(Checkpoint) and SameText(ExtractFileExt(Checkpoint), '.pt'),
    'Choose the original trained .pt checkpoint for this model.');
  NativeRequire(not DirectoryExists(Output) and not FileExists(Output) and
    DirectoryExists(ExtractFileDir(Output)), 'Choose a new output folder in an existing parent.');
  Recipe := YoloPreparedPath(FConfig.Root, Profile.RecipeFile);
  NativeRequire(FileExists(Recipe), 'The YOLO graph recipe was not prepared.');
  Tool := IncludeTrailingPathDelimiter(FConfig.Root) + 'runtime\converter\ConvertYolo.exe';
  NativeRequire(FileExists(Tool), 'Prepare the native YOLO converter before conversion.');
  Paths := NativeYoloToolchain(FConfig.Root);
  NativeRequire(Length(Paths) = 6, 'The native Windows compiler kit is incomplete.');
  Target := Trim(Architecture);
  if UsesCUDA(Index) then
    NativeRequire((Target = 'sm_75') or (Target = 'sm_86') or (Target = 'sm_89') or
      (Target = 'sm_120'), 'Choose CUDA compute capability sm_75, sm_86, sm_89 or sm_120.');
  Bundle := FConfig.FindBundle(Profile.ID, 'cpu');
  Lease := HoldNativeFile(Bundle.Directory, 'manifest.json', Bundle.ManifestSHA256, Bundle.ManifestBytes);
  Manifest := ReadNativeObject(Lease);
  try
    Runtime := NativeObject(NativeField(Manifest, 'runtime'));
    Request := TJSONObject.Create;
    try
      Request.AddPair('schema', 'crosspascal.yolo-convert.v1');
      Request.AddPair('target_os', 'windows');
      Request.AddPair('catalog', FConfig.CatalogFile);
      Request.AddPair('catalog_sha256', FConfig.CatalogSHA256);
      Request.AddPair('catalog_bytes', JSONInteger(FConfig.CatalogBytes));
      Request.AddPair('profile', Profile.ID);
      Request.AddPair('checkpoint', Checkpoint);
      Request.AddPair('recipe', Recipe);
      Request.AddPair('destination', Output);
      if UsesCUDA(Index) then
        Request.AddPair('device', 'cuda')
      else
        Request.AddPair('device', 'cpu');
      Compiler := TJSONObject.Create;
      Request.AddPair('compiler', Compiler);
      Compiler.AddPair('directory', Paths[0]);
      Compiler.AddPair('linker', Paths[1]);
      Compiler.AddPair('ffi_library', Paths[2]);
      Compiler.AddPair('msvc_libraries', Paths[3]);
      Compiler.AddPair('ucrt_libraries', Paths[4]);
      Compiler.AddPair('windows_libraries', Paths[5]);
      Request.AddPair('runtime', ParseCrossJSON(Runtime.ToJSON));
      NativeObject(Request.GetValue('runtime')).AddPair('directory', FConfig.RuntimeDirectory);
      if UsesCUDA(Index) then
      begin
        Cuda := TJSONObject.Create;
        Request.AddPair('cuda', Cuda);
        Cuda.AddPair('architecture', Target);
        Cuda.AddPair('nvrtc', NativeYoloNvrtc(FConfig.Root));
      end;
      Folder := NativeEnvironmentVariable('LOCALAPPDATA');
      NativeRequire(Folder <> '', 'The user application-data folder is unavailable.');
      Folder := IncludeTrailingPathDelimiter(Folder) + 'CrossPascal\Convert\requests';
      NativeRequire(ForceDirectories(Folder), 'Could not create the native request folder.');
      NativeRequire(CreateGUID(ID) = 0, 'Could not name the native conversion request.');
      Name := IncludeTrailingPathDelimiter(Folder) + GUIDToString(ID) + '.json';
      NativeRequire(not FileExists(Name), 'The native request file already exists.');
      Bytes := TEncoding.UTF8.GetBytes(Request.ToJSON + #10);
      Stream := TNativeWriteStream.Create(Name);
      try
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
      finally
        Stream.Free;
      end;
    finally
      Request.Free;
    end;
  finally
    Manifest.Free;
  end;
  Result := Default(TConversionCommand);
  Result.Executable := Tool;
  Result.Arguments := [Name];
  Result.Source := Checkpoint;
  Result.Destination := Output;
  if UsesCUDA(Index) then
    Result.Profile := cpYoloDetectionCUDA
  else
    Result.Profile := cpYoloDetection;
end;

end.
