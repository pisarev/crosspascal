unit PaddleOcr.Run;

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils,
  {$ELSE}
  System.SysUtils,
  {$ENDIF}
  TVM.PaddleOcr, TVM.CpuGraph, CrossVision.Mat;

type
  TPaddleResult = record
    Lines: TPaddleTextLines;
    Text: string;
    JSON: string;
    Device: string;
    Milliseconds: UInt64;
  end;

function ReadPaddleImage(const FileName, CVLibrary: string; out Digest: string): IMat;
function RunPaddle(const DetectionFolder, RecognitionFolder, RuntimeFolder, ClipperLibrary, ImageDigest: string;
  const Image: IMat; const ShouldStop: TCpuGraphStop = nil): TPaddleResult;
procedure SavePaddleText(const FileName, Text: string);
function FindPaddlePath(const RelativePath: string; const Directory: Boolean): string;

implementation

uses
  {$IFDEF FPC}
  Windows, Classes,
  {$ELSE}
  Winapi.Windows, System.Classes,
  {$ENDIF}
  CrossPascal.Json, CrossPascal.SHA256, TVM.ImageInput;

function ReadPaddleImage(const FileName, CVLibrary: string; out Digest: string): IMat;
var
  Bytes: TBytes;
begin
  Bytes := ReadImageBytes(FileName);
  Digest := SHA256Bytes(Bytes);
  Result := DecodeColorImage(Bytes, CVLibrary);
  RequireCpu((Result.Width <= 4096) and (Result.Height <= 4096),
    'Choose an image no larger than 4096 pixels on either side.');
end;

function RunPaddle(const DetectionFolder, RecognitionFolder, RuntimeFolder, ClipperLibrary, ImageDigest: string;
  const Image: IMat; const ShouldStop: TCpuGraphStop): TPaddleResult;
var
  Detector, Recognizer: TPaddleOcrModel;
  Postprocess: TPaddleDbPostprocess;
  Root, Row: TJSONObject;
  Lines, Quad, Point: TJSONArray;
  I, J: Integer;
  Started: UInt64;
begin
  Detector := nil;
  Recognizer := nil;
  Postprocess := nil;
  Root := nil;
  Result.Lines := nil;
  Result.Text := '';
  Result.JSON := '';
  Result.Device := '';
  Started := GetTickCount64;
  try
    Detector := TPaddleOcrModel.Create(DetectionFolder, RuntimeFolder);
    Recognizer := TPaddleOcrModel.Create(RecognitionFolder, RuntimeFolder);
    Postprocess := TPaddleDbPostprocess.Create(ClipperLibrary);
    Result.Lines := PaddleRead(Detector, Recognizer, Postprocess, Image, nil, ShouldStop);
    Result.Device := Detector.DeviceName;
    Result.Milliseconds := GetTickCount64 - Started;
    Root := TJSONObject.Create;
    Root.AddPair('schema', 'crosspascal.paddleocr-result.v1');
    Root.AddPair('status', 'PASS');
    Root.AddPair('image_sha256', ImageDigest);
    Root.AddPair('image_width', JSONInteger(Image.Width));
    Root.AddPair('image_height', JSONInteger(Image.Height));
    Root.AddPair('detector', Detector.DeviceName);
    Root.AddPair('recognizer', Recognizer.DeviceName);
    Root.AddPair('milliseconds', JSONUnsigned(Result.Milliseconds));
    Lines := TJSONArray.Create;
    Root.AddPair('lines', Lines);
    for I := 0 to High(Result.Lines) do
    begin
      if I > 0 then Result.Text := Result.Text + sLineBreak;
      Result.Text := Result.Text + Result.Lines[I].Text;
      Row := TJSONObject.Create;
      Lines.AddElement(Row);
      Row.AddPair('text', Result.Lines[I].Text);
      Row.AddPair('score', JSONFloat(Result.Lines[I].Score));
      Row.AddPair('detection_score', JSONFloat(Result.Lines[I].Detection.Score));
      Quad := TJSONArray.Create;
      Row.AddPair('quad', Quad);
      for J := 0 to 3 do
      begin
        Point := TJSONArray.Create;
        Quad.AddElement(Point);
        Point.AddElement(JSONFloat(Result.Lines[I].Detection.Quad[J].X));
        Point.AddElement(JSONFloat(Result.Lines[I].Detection.Quad[J].Y));
      end;
    end;
    Result.JSON := Root.ToJSON;
  finally
    Root.Free;
    Postprocess.Free;
    Recognizer.Free;
    Detector.Free;
  end;
end;

procedure SavePaddleText(const FileName, Text: string);
var
  Stream: TFileStream;
  Bytes: UTF8String;
begin
  RequireCpu(not FileExists(FileName), 'Choose a new output file.');
  Bytes := UTF8Encode(Text + #10);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(Bytes[1], Length(Bytes));
  finally
    Stream.Free;
  end;
end;

function FindPaddlePath(const RelativePath: string; const Directory: Boolean): string;
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
