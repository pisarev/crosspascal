unit YoloModels.Config;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  TVM.Yolo.Profile, TVM.NativeFiles;

type
  TYoloExampleBundle = record
    ProfileID: string;
    Target: string;
    Directory: string;
    ManifestSHA256: string;
    ManifestBytes: Int64;
  end;

  { The caller supplies the trusted index digest. Digests read from an
    untrusted index do not authenticate that index. A release generates its
    Defaults unit from the exact prepared candidate, before compilation. }
  TYoloExampleConfig = class
  private
    FRoot: string;
    FCatalogFile: string;
    FCatalogSHA256: string;
    FCatalogBytes: Int64;
    FProfiles: TYoloProfiles;
    FBundles: TArray<TYoloExampleBundle>;
    FRuntimeDirectory: string;
    FCVDirectory: string;
    FCVMember: string;
    FCVSHA256: string;
    FCVBytes: Int64;
  public
    constructor Create(const Directory, IndexSHA256: string; const IndexBytes: Int64;
      const IndexMember: string = 'index.json');
    function ProfileCount: Integer;
    function Profile(const Index: Integer): TYoloProfile;
    function FindBundle(const ProfileID, Target: string): TYoloExampleBundle;
    function HoldOpenCV: INativeFileLease;
    property Root: string read FRoot;
    property CatalogFile: string read FCatalogFile;
    property CatalogSHA256: string read FCatalogSHA256;
    property CatalogBytes: Int64 read FCatalogBytes;
    property RuntimeDirectory: string read FRuntimeDirectory;
  end;

function YoloPreparedPath(const Root, RelativeName: string): string;

implementation

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}, CrossPascal.Json, TVM.Yolo.Native;

function YoloPreparedPath(const Root, RelativeName: string): string;
var
  Start, I: Integer;
  Part: string;
begin
  NativeRequire((RelativeName <> '') and (RelativeName[Length(RelativeName)] <> '/'),
    'Expected a relative prepared path.');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(Root));
  Start := 1;
  for I := 1 to Length(RelativeName) + 1 do
    if (I > Length(RelativeName)) or (RelativeName[I] = '/') then
    begin
      Part := Copy(RelativeName, Start, I - Start);
      NativeRequire((Part <> '') and (Part <> '.') and (Part <> '..') and
        (Part[Length(Part)] <> '.'), 'Invalid prepared path component.');
      Result := IncludeTrailingPathDelimiter(Result) + Part;
      Start := I + 1;
    end
    else
      NativeRequire(CharInSet(RelativeName[I], ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.']),
        'Prepared paths use ASCII names and forward slashes.');
end;

constructor TYoloExampleConfig.Create(const Directory, IndexSHA256: string; const IndexBytes: Int64;
  const IndexMember: string);
var
  Lease: INativeFileLease;
  Index, Catalog, Spec, Row: TJSONObject;
  Rows: TJSONArray;
  I, J, ProfileIndex, TargetIndex: Integer;
  Bundle: TYoloExampleBundle;
  Found: Boolean;
const
  Targets: array[0..4] of string = ('cpu', 'sm_75', 'sm_86', 'sm_89', 'sm_120');
begin
  inherited Create;
  FRoot := ExpandFileName(Directory);
  Lease := HoldNativeFile(FRoot, IndexMember, IndexSHA256, IndexBytes);
  Index := ReadNativeObject(Lease);
  try
    NativeUniqueKeys(Index);
    NativeRequire(NativeText(Index, 'schema') = 'crosspascal.yolo-examples.v1',
      'Unsupported prepared YOLO index.');
    NativeRequire((NativeText(Index, 'os') = 'windows') and
      (NativeText(Index, 'arch') = 'x86_64'), 'Expected a Windows x64 example kit.');
    Spec := NativeObject(NativeField(Index, 'profiles'));
    FCatalogFile := NativeMember(FRoot, NativeText(Spec, 'file'));
    FCatalogSHA256 := NativeText(Spec, 'sha256');
    FCatalogBytes := NativeInteger(Spec, 'bytes');
    Lease := HoldNativeFile(FRoot, NativeText(Spec, 'file'),
      NativeText(Spec, 'sha256'), NativeInteger(Spec, 'bytes'));
    Catalog := ReadNativeObject(Lease, 8 * 1024 * 1024);
    try
      FProfiles := ParseYoloProfiles(Catalog.ToJSON);
    finally
      Catalog.Free;
    end;
    FRuntimeDirectory := YoloPreparedPath(FRoot, NativeText(Index, 'runtime'));
    Spec := NativeObject(NativeField(Index, 'opencv'));
    FCVDirectory := YoloPreparedPath(FRoot, NativeText(Spec, 'directory'));
    FCVMember := NativeText(Spec, 'file');
    NativeRequire(YoloPreparedPath(FCVDirectory, FCVMember) = IncludeTrailingPathDelimiter(FCVDirectory) + FCVMember,
      'Expected an OpenCV leaf filename.');
    FCVSHA256 := NativeText(Spec, 'sha256');
    NativeRequireSHA256(FCVSHA256);
    FCVBytes := NativeInteger(Spec, 'bytes');
    NativeRequire(FCVBytes > 0, 'Invalid OpenCV file size.');
    Rows := NativeArray(NativeField(Index, 'bundles'));
    NativeRequire(Rows.Count = Length(FProfiles) * Length(Targets),
      'The prepared index must cover every model on CPU and all supported CUDA targets.');
    SetLength(FBundles, Rows.Count);
    for I := 0 to Rows.Count - 1 do
    begin
      Row := NativeObject(Rows.Items[I]);
      Bundle.ProfileID := NativeText(Row, 'profile');
      Bundle.Target := NativeText(Row, 'target');
      Found := False;
      for J := 0 to High(FProfiles) do
        if FProfiles[J].ID = Bundle.ProfileID then Found := True;
      NativeRequire(Found, 'Unknown model in the prepared index.');
      Found := False;
      for J := Low(Targets) to High(Targets) do
        if Bundle.Target = Targets[J] then Found := True;
      NativeRequire(Found, 'Unknown target in the prepared index.');
      for J := 0 to I - 1 do
        NativeRequire((FBundles[J].ProfileID <> Bundle.ProfileID) or
          (FBundles[J].Target <> Bundle.Target), 'Duplicate prepared model and target.');
      Bundle.Directory := YoloPreparedPath(FRoot, NativeText(Row, 'directory'));
      Bundle.ManifestSHA256 := NativeText(Row, 'manifest_sha256');
      NativeRequireSHA256(Bundle.ManifestSHA256);
      Bundle.ManifestBytes := NativeInteger(Row, 'manifest_bytes');
      NativeRequire(Bundle.ManifestBytes > 0, 'Invalid model manifest size.');
      FBundles[I] := Bundle;
    end;
    for ProfileIndex := 0 to High(FProfiles) do
      for TargetIndex := Low(Targets) to High(Targets) do
        FindBundle(FProfiles[ProfileIndex].ID, Targets[TargetIndex]);
  finally
    Index.Free;
  end;
end;

function TYoloExampleConfig.ProfileCount: Integer;
begin
  Result := Length(FProfiles);
end;

function TYoloExampleConfig.Profile(const Index: Integer): TYoloProfile;
begin
  NativeRequire((Index >= 0) and (Index < Length(FProfiles)), 'Choose a YOLO model.');
  Result := CopyYoloProfile(FProfiles[Index]);
end;

function TYoloExampleConfig.FindBundle(const ProfileID, Target: string): TYoloExampleBundle;
var
  I: Integer;
begin
  for I := 0 to High(FBundles) do
    if (FBundles[I].ProfileID = ProfileID) and (FBundles[I].Target = Target) then
      Exit(FBundles[I]);
  raise ENativePackage.Create('This prepared kit has no bundle for ' + ProfileID + ' / ' + Target + '.');
end;

function TYoloExampleConfig.HoldOpenCV: INativeFileLease;
begin
  Result := HoldNativeFile(FCVDirectory, FCVMember, FCVSHA256, FCVBytes);
  RequireNativeX64LibraryForOS(Result, 'windows');
end;

end.
