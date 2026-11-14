unit BiRefNet.Run;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}, TVM.CpuGraph, CrossVision.Mat;

type
  TBiRefResult = record
    Mask: IMat;
    Cutout: IMat;
    Device: string;
    JSON: string;
    Milliseconds: UInt64;
  end;

function ReadBiRefImage(const FileName, CVLibrary: string; out Digest: string): IMat;
function RunBiRef(const Bundle, Runtime, ImageDigest: string; const Image: IMat;
  const ShouldStop: TCpuGraphStop = nil): TBiRefResult;
procedure SaveBiRefPNG(const FileName: string; const Image: IMat);
procedure SaveBiRefReport(const FileName, Text: string);
function FindBiRefPath(const RelativePath: string; const Directory: Boolean): string;

implementation

uses
  {$IFDEF FPC}Windows, Classes{$ELSE}Winapi.Windows, System.Classes{$ENDIF},
  CrossPascal.Json, CrossPascal.SHA256, TVM.BiRefNet, TVM.ImageInput, OpenCV, OpenCVConsts;

function ReadBiRefImage(const FileName, CVLibrary: string; out Digest: string): IMat;
var
  Bytes: TBytes;
begin
  Bytes := ReadImageBytes(FileName);
  Digest := SHA256Bytes(Bytes);
  Result := DecodeColorImage(Bytes, CVLibrary);
  RequireCpu((Result.Width <= 4096) and (Result.Height <= 4096),
    'Choose an image no larger than 4096 pixels on either side.');
end;

function RunBiRef(const Bundle, Runtime, ImageDigest: string; const Image: IMat;
  const ShouldStop: TCpuGraphStop): TBiRefResult;
var
  Model: TBiRefNetModel;
  Root: TJSONObject;
  Input, Logits: TArray<Single>;
  Stream: TMemoryStream;
  InputDigest, ModelDigest: string;
  Started: UInt64;
begin
  Result := Default(TBiRefResult);
  Model := nil;
  Root := nil;
  Started := GetTickCount64;
  try
    Model := TBiRefNetModel.Create(Bundle, Runtime);
    Input := BiRefNetInput(Image);
    Stream := TMemoryStream.Create;
    try
      Stream.WriteBuffer(Input[0], Int64(Length(Input)) * SizeOf(Single));
      Stream.Position := 0;
      InputDigest := SHA256Stream(Stream);
    finally
      Stream.Free;
    end;
    Logits := Model.Run(Input, ShouldStop);
    if Assigned(ShouldStop) and ShouldStop() then raise ECpuGraphStopped.Create('BiRefNet stopped');
    Result.Mask := BiRefNetMask(Logits, Image.Width, Image.Height);
    Result.Cutout := BiRefNetCutout(Image, Result.Mask);
    Result.Device := Model.DeviceName;
    ModelDigest := Model.ModelSHA256;
    FreeAndNil(Model);
    Result.Milliseconds := GetTickCount64 - Started;
    Root := TJSONObject.Create;
    Root.AddPair('schema', 'crosspascal.birefnet-result.v1');
    Root.AddPair('status', 'PASS');
    Root.AddPair('profile', 'birefnet-hr800');
    Root.AddPair('image_sha256', ImageDigest);
    Root.AddPair('input_sha256', InputDigest);
    Root.AddPair('source_sha256', BiRefNetSourceSHA256);
    Root.AddPair('model_sha256', ModelDigest);
    Root.AddPair('image_width', JSONInteger(Image.Width));
    Root.AddPair('image_height', JSONInteger(Image.Height));
    Root.AddPair('device', Result.Device);
    Root.AddPair('milliseconds', JSONUnsigned(Result.Milliseconds));
    Result.JSON := Root.ToJSON;
  finally
    Root.Free;
    Model.Free;
  end;
end;

procedure WriteNewBiRefFile(const FileName: string; const Data: Pointer; const Size: Integer);
var
  Handle: THandle;
  Stream: THandleStream;
  Code: DWORD;
begin
  RequireCpu((FileName <> '') and (Pos(#0, FileName) = 0) and (Data <> nil) and (Size > 0),
    'Choose a new output file.');
  Handle := CreateFileW(PWideChar(FileName), GENERIC_WRITE, FILE_SHARE_READ, nil,
    CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then
  begin
    Code := GetLastError;
    if Code in [ERROR_FILE_EXISTS, ERROR_ALREADY_EXISTS] then
      raise ECpuGraph.Create('Choose a new output file.');
    raise ECpuGraph.Create('The output file could not be created. Choose a writable folder. Windows error ' + IntToStr(Code));
  end;
  Stream := nil;
  try
    Stream := THandleStream.Create(Handle);
    Stream.WriteBuffer(Data^, Size);
  finally
    Stream.Free;
    CloseHandle(Handle);
  end;
end;

procedure SaveBiRefPNG(const FileName: string; const Image: IMat);
var
  Data: Pointer;
  Size: Integer;
begin
  RequireCpu(not FileExists(FileName), 'Choose a new output file.');
  RequireCpu((Image <> nil) and not Image.IsEmpty and (Image.Depth = CV_8U) and
    (Image.Channels in [1, 3, 4]), 'Expected an 8-bit PNG image');
  Data := nil;
  Size := 0;
  try
    RequireCpu(CV.ImgCodecs.ImEncode('.png', Image.Raw, @Data, @Size, 3) and
      (Data <> nil) and (Size > 0), 'PNG encoding failed: ' + CV.Module.Error);
    WriteNewBiRefFile(FileName, Data, Size);
  finally
    if Data <> nil then RequireCpu(CV.ImgCodecs.FreeBuf(Data), 'PNG buffer release failed');
  end;
end;

procedure SaveBiRefReport(const FileName, Text: string);
var
  Bytes: UTF8String;
begin
  RequireCpu(not FileExists(FileName), 'Choose a new output file.');
  Bytes := UTF8Encode(Text + #10);
  RequireCpu(Length(Bytes) <= MaxInt, 'The report is too large.');
  WriteNewBiRefFile(FileName, @Bytes[1], Length(Bytes));
end;

function FindBiRefPath(const RelativePath: string; const Directory: Boolean): string;
var
  Current, Parent, Candidate: string;
  I: Integer;
begin
  Result := '';
  Current := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  for I := 0 to 10 do
  begin
    Candidate := ExpandFileName(IncludeTrailingPathDelimiter(Current) + RelativePath);
    if (Directory and DirectoryExists(Candidate)) or
      (not Directory and FileExists(Candidate)) then Exit(Candidate);
    Parent := ExtractFileDir(Current);
    if SameText(Parent, Current) then Break;
    Current := Parent;
  end;
end;

end.
