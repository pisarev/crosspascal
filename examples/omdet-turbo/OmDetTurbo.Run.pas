unit OmDetTurbo.Run;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}, TVM.CpuGraph, TVM.OmDet, TVM.OmDetModel,
  CrossVision.Mat;

type
  TOmDetResult = record
    Detections: TOmDetDetections;
    Labels: TOmDetLabels;
    TaskText: string;
    Device: string;
    ImageSHA256: string;
    InputSHA256: string;
    TextSHA256: string;
    DetectorSHA256: string;
    ImageWidth: Integer;
    ImageHeight: Integer;
    TaskTokenCount: Integer;
    ClassTokenCounts: TArray<Integer>;
    ScoreThreshold: Single;
    NmsThreshold: Single;
    Truncated: Boolean;
    Milliseconds: UInt64;
    CacheHits: UInt64;
    CacheMisses: UInt64;
  end;

function ReadOmDetImage(const FileName, CVLibrary: string; out Digest: string): IMat;
function InferOmDet(const Model: TOmDetModel; const Image: IMat; const ImageDigest: string;
  const Labels: TOmDetLabels; const Task: UnicodeString; const AllowTruncate: Boolean;
  const ScoreThreshold, NmsThreshold: Single; const ShouldStop: TCpuGraphStop = nil;
  const Progress: TOmDetProgress = nil): TOmDetResult;
function OmDetResultJSON(const Value: TOmDetResult; const Status: string): string;
procedure WriteNewOmDetFile(const FileName: string; const Data: Pointer; const Size: Integer);
procedure SaveOmDetReport(const FileName, Text: string);
function FindOmDetPath(const RelativePath: string; const Directory: Boolean): string;

implementation

uses
  {$IFDEF FPC}Windows, Classes{$ELSE}Winapi.Windows, System.Classes{$ENDIF},
  CrossPascal.Json, CrossPascal.SHA256, TVM.ImageInput;

function ReadOmDetImage(const FileName, CVLibrary: string; out Digest: string): IMat;
var
  Bytes: TBytes;
begin
  Bytes := ReadImageBytes(FileName);
  Digest := SHA256Bytes(Bytes);
  Result := DecodeColorImage(Bytes, CVLibrary);
  RequireCpu((Result.Width <= 4096) and (Result.Height <= 4096),
    'Choose an image no larger than 4096 pixels on either side.');
end;

function ValidThreshold(const Value: Single): Boolean;
var
  Bits: Cardinal;
begin
  Move(Value, Bits, SizeOf(Bits));
  Result := ((Bits and $7F800000) <> $7F800000);
  if Result then Result := (Value >= 0) and (Value <= 1);
end;

function InferOmDet(const Model: TOmDetModel; const Image: IMat; const ImageDigest: string;
  const Labels: TOmDetLabels; const Task: UnicodeString; const AllowTruncate: Boolean;
  const ScoreThreshold, NmsThreshold: Single; const ShouldStop: TCpuGraphStop;
  const Progress: TOmDetProgress): TOmDetResult;
var
  Input: TArray<Single>;
  Raw: TOmDetRaw;
  Stream: TMemoryStream;
  Started, Hits, Misses: UInt64;
begin
  RequireCpu(Model <> nil, 'Choose an OmDet model.');
  RequireCpu(ValidThreshold(ScoreThreshold) and ValidThreshold(NmsThreshold),
    'Confidence and NMS thresholds must be between 0 and 1.');
  Result := Default(TOmDetResult);
  Started := GetTickCount64;
  if Assigned(ShouldStop) and ShouldStop() then raise ECpuGraphStopped.Create('OmDet stopped');
  if Assigned(Progress) then Progress('Prepare image');
  Input := OmDetImageInput(Image);
  Stream := TMemoryStream.Create;
  try
    Stream.WriteBuffer(Input[0], Length(Input) * SizeOf(Single));
    Stream.Position := 0;
    Result.InputSHA256 := SHA256Stream(Stream);
  finally
    Stream.Free;
  end;
  Hits := Model.CacheHits;
  Misses := Model.CacheMisses;
  Raw := Model.Run(Input, Labels, Task, AllowTruncate, ShouldStop, Progress);
  if Assigned(ShouldStop) and ShouldStop() then raise ECpuGraphStopped.Create('OmDet stopped');
  if Assigned(Progress) then Progress('Postprocess results');
  Result.Detections := OmDetDecode(Raw.Boxes, Raw.Logits, Length(Labels), Image.Width,
    Image.Height, ScoreThreshold, NmsThreshold);
  Result.Labels := Copy(Labels, 0, Length(Labels));
  Result.TaskText := Raw.ResolvedTask;
  Result.ClassTokenCounts := Raw.ClassTokenCounts;
  Result.TaskTokenCount := Raw.TaskTokenCount;
  Result.Truncated := Raw.Truncated;
  Result.Device := Model.DeviceName;
  Result.ImageSHA256 := ImageDigest;
  Result.ImageWidth := Image.Width;
  Result.ImageHeight := Image.Height;
  Result.TextSHA256 := Model.TextSHA256;
  Result.DetectorSHA256 := Model.DetectorSHA256;
  Result.ScoreThreshold := ScoreThreshold;
  Result.NmsThreshold := NmsThreshold;
  Result.CacheHits := Model.CacheHits - Hits;
  Result.CacheMisses := Model.CacheMisses - Misses;
  Result.Milliseconds := GetTickCount64 - Started;
end;

function OmDetResultJSON(const Value: TOmDetResult; const Status: string): string;
var
  Root, Item: TJSONObject;
  Labels, Counts, Detections, Box: TJSONArray;
  I: Integer;
begin
  RequireCpu((Status = 'INFERRED') or (Status = 'PASS'), 'Invalid result status');
  Root := TJSONObject.Create;
  try
    Root.AddPair('schema', 'crosspascal.omdet-result.v1');
    Root.AddPair('status', Status);
    Root.AddPair('profile', 'omdet-turbo-tiny16');
    Root.AddPair('checkpoint_sha256', OmDetCheckpointSHA256);
    Root.AddPair('image_sha256', Value.ImageSHA256);
    Root.AddPair('input_sha256', Value.InputSHA256);
    Root.AddPair('text_sha256', Value.TextSHA256);
    Root.AddPair('detector_sha256', Value.DetectorSHA256);
    Root.AddPair('image_width', JSONInteger(Value.ImageWidth));
    Root.AddPair('image_height', JSONInteger(Value.ImageHeight));
    Root.AddPair('device', Value.Device);
    Root.AddPair('milliseconds', JSONUnsigned(Value.Milliseconds));
    Root.AddPair('task', Value.TaskText);
    Root.AddPair('task_token_count', JSONInteger(Value.TaskTokenCount));
    Root.AddPair('text_truncated', JSONBoolean(Value.Truncated));
    Root.AddPair('confidence_threshold', JSONFloat(Value.ScoreThreshold));
    Root.AddPair('nms_threshold', JSONFloat(Value.NmsThreshold));
    Root.AddPair('cache_hits', JSONUnsigned(Value.CacheHits));
    Root.AddPair('cache_misses', JSONUnsigned(Value.CacheMisses));
    Labels := TJSONArray.Create;
    Root.AddPair('classes', Labels);
    Counts := TJSONArray.Create;
    Root.AddPair('class_token_counts', Counts);
    for I := 0 to High(Value.Labels) do Labels.AddElement(TJSONString.Create(Value.Labels[I]));
    for I := 0 to High(Value.ClassTokenCounts) do
      Counts.AddElement(JSONInteger(Value.ClassTokenCounts[I]));
    Detections := TJSONArray.Create;
    Root.AddPair('detections', Detections);
    for I := 0 to High(Value.Detections) do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('class_index', JSONInteger(Value.Detections[I].ClassIndex));
      Item.AddPair('label', Value.Labels[Value.Detections[I].ClassIndex]);
      Item.AddPair('score', JSONFloat(Value.Detections[I].Score));
      Box := TJSONArray.Create;
      Item.AddPair('box', Box);
      Box.AddElement(JSONFloat(Value.Detections[I].Left));
      Box.AddElement(JSONFloat(Value.Detections[I].Top));
      Box.AddElement(JSONFloat(Value.Detections[I].Right));
      Box.AddElement(JSONFloat(Value.Detections[I].Bottom));
      Detections.AddElement(Item);
    end;
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

procedure WriteNewOmDetFile(const FileName: string; const Data: Pointer; const Size: Integer);
var
  Handle: THandle;
  Code, Written: DWORD;
  Identifier: TGUID;
  Destination, Temporary, ErrorText: string;
  OwnTemporary: Boolean;

  procedure WindowsFailure(const Operation: string; const ErrorCode: DWORD);
  begin
    raise ECpuGraph.Create(Operation + ' Windows error ' + IntToStr(ErrorCode) + '.');
  end;

begin
  RequireCpu((FileName <> '') and (Pos(#0, FileName) = 0) and (Data <> nil) and (Size > 0),
    'Choose a new output file.');
  Destination := ExpandFileName(FileName);
  RequireCpu(CreateGUID(Identifier) = 0, 'A temporary output name could not be generated.');
  Temporary := ExtractFilePath(Destination) + '.crosspascal-' + GUIDToString(Identifier) + '.tmp';
  Handle := CreateFileW(PWideChar(Temporary), GENERIC_WRITE, 0, nil,
    CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then
    WindowsFailure('The temporary output file could not be created. Choose a writable folder.', GetLastError);
  OwnTemporary := True;
  try
    Written := 0;
    if not WriteFile(Handle, Data^, DWORD(Size), Written, nil) then
      WindowsFailure('The output file could not be written.', GetLastError);
    RequireCpu(Written = DWORD(Size), 'The output file was not written completely.');
    if not FlushFileBuffers(Handle) then
      WindowsFailure('The output file could not be flushed.', GetLastError);
    if not CloseHandle(Handle) then
    begin
      Code := GetLastError;
      WindowsFailure('The output file could not be closed.', Code);
    end;
    Handle := INVALID_HANDLE_VALUE;
    if not MoveFileExW(PWideChar(Temporary), PWideChar(Destination), 0) then
    begin
      Code := GetLastError;
      if Code in [ERROR_FILE_EXISTS, ERROR_ALREADY_EXISTS] then
        raise ECpuGraph.Create('Choose a new output file.');
      WindowsFailure('The completed output file could not be published.', Code);
    end;
    OwnTemporary := False;
  except
    on E: Exception do
    begin
      ErrorText := E.ClassName + ': ' + E.Message;
      if Handle <> INVALID_HANDLE_VALUE then
      begin
        if not CloseHandle(Handle) then
          ErrorText := ErrorText + ' Temporary file close failed: Windows error ' +
            IntToStr(GetLastError) + '.';
        Handle := INVALID_HANDLE_VALUE;
      end;
      if OwnTemporary and not DeleteFileW(PWideChar(Temporary)) then
        ErrorText := ErrorText + ' Temporary file cleanup failed: ' + Temporary +
          '. Windows error ' + IntToStr(GetLastError) + '.';
      raise ECpuGraph.Create(ErrorText);
    end;
  end;
end;

procedure SaveOmDetReport(const FileName, Text: string);
var
  Bytes: UTF8String;
begin
  RequireCpu(not FileExists(FileName), 'Choose a new output file.');
  Bytes := UTF8Encode(Text + #10);
  RequireCpu(Length(Bytes) <= MaxInt, 'The report is too large.');
  WriteNewOmDetFile(FileName, @Bytes[1], Length(Bytes));
end;

function FindOmDetPath(const RelativePath: string; const Directory: Boolean): string;
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
