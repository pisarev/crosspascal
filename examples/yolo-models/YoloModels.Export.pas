{ ************************************************************************** }
{                                                                            }
{ YoloModels.Export                                                          }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                       }
{                                                                            }
{ ************************************************************************** }

unit YoloModels.Export;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  CrossVision.Mat, YoloModels.Run;

{ Creates a new directory. Existing output is never overwritten. result.json
  is written last, after PNGs and lossless maps and their SHA256 descriptors.
  A failed export leaves its incomplete directory available for inspection. }
procedure SaveYoloExampleResult(const Directory: string; const Source, Preview: IMat;
  const Value: TYoloExampleResult);

implementation

uses
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF}, OpenCV,
  OpenCVTypes, OpenCVConsts, CrossPascal.Json, CrossPascal.SHA256, TVM.CpuGraph,
  TVM.Yolo.Profile, CrossVision.ML.Depth, CrossPascal.NativeIO;

function OutputFile(const Directory, Name: string): string;
begin
  Result := IncludeTrailingPathDelimiter(Directory) + Name;
end;

function NewOutputStream(const Name: string): TStream;
begin
  RequireCpu(not FileExists(Name), 'An output file already exists. Choose a new folder.');
  Result := TNativeWriteStream.Create(Name);
end;

procedure WritePNG(const Name: string; const Image: IMat);
var
  Data: Pointer;
  Size: Integer;
  Stream: TStream;
begin
  RequireCpu(Assigned(CV.ImgCodecs.ImEncode) and Assigned(CV.ImgCodecs.FreeBuf),
    'The image runtime does not provide PNG encoding.');
  Data := nil;
  Size := 0;
  try
    RequireCpu(CV.ImgCodecs.ImEncode('.png', Image.Raw, @Data, @Size, 1) and
      (Data <> nil) and (Size > 0), 'PNG encoding failed.');
    Stream := NewOutputStream(Name);
    try
      Stream.WriteBuffer(Data^, Size);
    finally
      Stream.Free;
    end;
  finally
    if Data <> nil then
      RequireCpu(CV.ImgCodecs.FreeBuf(Data), 'PNG encoder buffer release failed.');
  end;
end;

procedure RequirePlane(const Image: IMat; const Width, Height, MatType, BytesPerPixel: Integer);
begin
  RequireCpu((Image <> nil) and not Image.IsEmpty and
    (Image.Width = Width) and (Image.Height = Height) and (Image.MatType = MatType) and
    (Image.DataPtr <> nil) and (Int64(Image.Step) >= Int64(Width) * BytesPerPixel),
    'A saved image or map differs from the result dimensions or type.');
end;

procedure WritePlane(const Name: string; const Image: IMat);
var
  Stream: TStream;
  Y, RowBytes: Integer;
  Row: Pointer;
begin
  RowBytes := Image.Width * Image.ElemSize;
  Stream := NewOutputStream(Name);
  try
    for Y := 0 to Image.Height - 1 do
    begin
      Row := Pointer(NativeUInt(Image.DataPtr) + NativeUInt(Y) * NativeUInt(Image.Step));
      Stream.WriteBuffer(Row^, RowBytes);
    end;
  finally
    Stream.Free;
  end;
end;

procedure DescribeFile(const Files: TJSONArray; const Directory, Name, Kind: string;
  const Width, Height: Integer);
var
  Stream: TStream;
  Item: TJSONObject;
  Shape: TJSONArray;
begin
  Stream := TNativeReadStream.Create(OutputFile(Directory, Name));
  try
    Item := TJSONObject.Create;
    Files.AddElement(Item);
    Item.AddPair('file', Name);
    Item.AddPair('format', Kind);
    Item.AddPair('bytes', JSONInteger(Stream.Size));
    Item.AddPair('sha256', SHA256Stream(Stream));
    Shape := TJSONArray.Create;
    Item.AddPair('shape', Shape);
    Shape.AddElement(JSONInteger(Height));
    Shape.AddElement(JSONInteger(Width));
    if Kind = 'png_bgr8' then Shape.AddElement(JSONInteger(3));
    Item.AddPair('row_order', 'top_down');
    if Kind <> 'png_bgr8' then Item.AddPair('storage', 'contiguous_rows_without_padding');
  finally
    Stream.Free;
  end;
end;

procedure SaveYoloExampleResult(const Directory: string; const Source, Preview: IMat;
  const Value: TYoloExampleResult);
var
  Root: TJSONObject;
  Files: TJSONArray;
  Stream: TStream;
  Text: UTF8String;
  Name, Destination: string;
  I: Integer;
  Endian: Word;
begin
  RequireCpu((Directory <> '') and (Pos(#0, Directory) = 0), 'Choose a new output folder.');
  RequirePlane(Source, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 3), 3);
  RequirePlane(Preview, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 3), 3);
  Root := YoloExampleResultObject(Value);
  try
    Files := TJSONArray.Create;
    Root.AddPair('files', Files);
    Destination := ExcludeTrailingPathDelimiter(ExpandFileName(Directory));
    RequireCpu(not DirectoryExists(Destination) and not FileExists(Destination),
      'Choose a new output folder. Existing results are kept.');
    RequireCpu(CreateDir({$IFDEF FPC}{$IFDEF UNIX}UTF8Encode(Destination){$ELSE}Destination{$ENDIF}{$ELSE}Destination{$ENDIF}),
      'Cannot create the output folder.');
    try
      WritePNG(OutputFile(Destination, 'source.png'), Source);
      DescribeFile(Files, Destination, 'source.png', 'png_bgr8', Value.Width, Value.Height);
      WritePNG(OutputFile(Destination, 'preview.png'), Preview);
      DescribeFile(Files, Destination, 'preview.png', 'png_bgr8', Value.Width, Value.Height);
      case Value.Profile.Task of
        ytInstances:
          for I := 0 to High(Value.Instances) do
          begin
            RequirePlane(Value.Instances[I].Mask, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 1), 1);
            Name := 'instance-' + IntToStr(I) + '.u8';
            WritePlane(OutputFile(Destination, Name), Value.Instances[I].Mask);
            DescribeFile(Files, Destination, Name, 'uint8_mask_0_255', Value.Width, Value.Height);
          end;
        ytSemantic:
          for I := 0 to High(Value.Semantic) do
          begin
            RequirePlane(Value.Semantic[I].Mask, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 1), 1);
            Name := 'class-' + IntToStr(I) + '.u8';
            WritePlane(OutputFile(Destination, Name), Value.Semantic[I].Mask);
            DescribeFile(Files, Destination, Name, 'uint8_mask_0_255', Value.Width, Value.Height);
          end;
        ytDepth:
          begin
            Endian := 1;
            RequireCpu(PByte(@Endian)^ = 1, 'Depth export requires little-endian Float32 storage.');
            RequireCpu(Value.Depth.Units = duMeters, 'Unexpected depth units.');
            RequirePlane(Value.Depth.Values, Value.Width, Value.Height, CV_MAKETYPE(CV_32F, 1),
              SizeOf(Single));
            Name := 'depth.f32le';
            WritePlane(OutputFile(Destination, Name), Value.Depth.Values);
            DescribeFile(Files, Destination, Name, 'float32_le_meters', Value.Width, Value.Height);
          end;
      end;
      Text := UTF8Encode(Root.ToJSON + #10);
      Stream := NewOutputStream(OutputFile(Destination, 'result.json'));
      try
        Stream.WriteBuffer(Text[1], Length(Text));
      finally
        Stream.Free;
      end;
    except
      on E: Exception do
        raise ECpuGraph.Create(E.Message + ' Incomplete export folder: ' + Destination);
    end;
  finally
    Root.Free;
  end;
end;

end.
