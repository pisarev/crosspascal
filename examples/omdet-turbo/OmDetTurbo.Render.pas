unit OmDetTurbo.Render;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils, Graphics{$ELSE}System.SysUtils, Vcl.Graphics{$ENDIF},
  CrossVision.Mat, OmDetTurbo.Run;

type
  TOmDetBitmap = {$IFDEF FPC}Graphics{$ELSE}Vcl.Graphics{$ENDIF}.TBitmap;

function OmDetPicture(const Image: IMat): TPicture;
function OmDetOverlay(const Image: IMat; const Value: TOmDetResult): TOmDetBitmap;
procedure SaveOmDetPNG(const FileName: string; const Image: TOmDetBitmap);

implementation

uses
  {$IFDEF FPC}Windows, Classes, Math, FPReadPNG, FPWritePNG{$ELSE}
  Winapi.Windows, System.Classes, System.Math, Vcl.Imaging.pngimage{$ENDIF},
  CrossPascal.Json, TVM.CpuGraph, OpenCV, OpenCVTypes, OpenCVConsts;

function OmDetPicture(const Image: IMat): TPicture;
var
  Data: Pointer;
  Size: Integer;
  Stream: TMemoryStream;
begin
  RequireCpu((Image <> nil) and not Image.IsEmpty and (Image.Channels = 3) and
    (Image.Depth = CV_8U), 'No color image is available for preview.');
  Data := nil;
  Size := 0;
  Result := TPicture.Create;
  try
    Stream := TMemoryStream.Create;
    try
      RequireCpu(CV.ImgCodecs.ImEncode('.png', Image.Raw, @Data, @Size, 1) and
        (Data <> nil) and (Size > 0), 'Preview encoding failed');
      Stream.WriteBuffer(Data^, Size);
      Stream.Position := 0;
      Result.LoadFromStream(Stream);
    finally
      Stream.Free;
      if Data <> nil then RequireCpu(CV.ImgCodecs.FreeBuf(Data), 'Preview buffer release failed');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function OmDetOverlay(const Image: IMat; const Value: TOmDetResult): TOmDetBitmap;
const
  Colors: array[0..4] of TColor = (clRed, clBlue, clGreen, clFuchsia, clTeal);
var
  Picture: TPicture;
  Text: UnicodeString;
  Box, LabelBox: TRect;
  Labels: TArray<TRect>;
  I, J, Attempt, Width, Height, LabelWidth, LabelHeight, LabelX, LabelY, Scale: Integer;
  Overlap: Boolean;
begin
  Picture := OmDetPicture(Image);
  Result := TOmDetBitmap.Create;
  try
    try
      Result.PixelFormat := pf24bit;
      Result.SetSize(Picture.Width, Picture.Height);
      Result.Canvas.Draw(0, 0, Picture.Graphic);
      Width := Result.Width;
      Height := Result.Height;
      Scale := Max(1, Max(Width, Height) div 640);
      Result.Canvas.Font.Name := 'Segoe UI';
      Result.Canvas.Font.Height := -14 * Scale;
      Result.Canvas.Font.Color := clBlack;
      Result.Canvas.Pen.Width := 2 * Scale;
      SetLength(Labels, Length(Value.Detections));
      for I := 0 to High(Value.Detections) do
      begin
        RequireCpu((Value.Detections[I].ClassIndex >= 0) and
          (Value.Detections[I].ClassIndex < Length(Value.Labels)), 'Invalid detection class');
        Box := Rect(Max(0, Round(Value.Detections[I].Left)),
          Max(0, Round(Value.Detections[I].Top)), Min(Width - 1, Round(Value.Detections[I].Right)),
          Min(Height - 1, Round(Value.Detections[I].Bottom)));
        Result.Canvas.Brush.Style := bsClear;
        Result.Canvas.Pen.Color := Colors[Value.Detections[I].ClassIndex mod Length(Colors)];
        Result.Canvas.Rectangle(Box.Left, Box.Top, Box.Right + 1, Box.Bottom + 1);
      end;
      for I := 0 to High(Value.Detections) do
      begin
        Box := Rect(Max(0, Round(Value.Detections[I].Left)),
          Max(0, Round(Value.Detections[I].Top)), Min(Width - 1, Round(Value.Detections[I].Right)),
          Min(Height - 1, Round(Value.Detections[I].Bottom)));
        Text := Value.Labels[Value.Detections[I].ClassIndex] + ' ' +
          Format('%.2f', [Value.Detections[I].Score], JSONInvariantFormat);
        LabelBox := Rect(0, 0, Width, Height);
        DrawTextW(Result.Canvas.Handle, PWideChar(Text), Length(Text), LabelBox,
          DT_CALCRECT or DT_NOPREFIX or DT_SINGLELINE);
        LabelWidth := Min(Width, LabelBox.Right - LabelBox.Left + 6 * Scale);
        LabelHeight := Min(Height, LabelBox.Bottom - LabelBox.Top + 4 * Scale);
        LabelX := Max(0, Min(Box.Left, Width - LabelWidth));
        LabelY := Box.Top - LabelHeight;
        if LabelY < 0 then LabelY := Min(Height - LabelHeight, Box.Top + 2 * Scale);
        for Attempt := 0 to Min(I, Height div Max(1, LabelHeight) + 1) do
        begin
          LabelBox := Rect(LabelX, LabelY, LabelX + LabelWidth, LabelY + LabelHeight);
          Overlap := False;
          for J := 0 to I - 1 do
            if (LabelBox.Left < Labels[J].Right) and (LabelBox.Right > Labels[J].Left) and
              (LabelBox.Top < Labels[J].Bottom) and (LabelBox.Bottom > Labels[J].Top) then
              begin
                Overlap := True;
                Break;
              end;
          if not Overlap then Break;
          Inc(LabelY, LabelHeight + 2 * Scale);
          if LabelY + LabelHeight > Height then LabelY := 0;
        end;
        Labels[I] := LabelBox;
        Result.Canvas.Brush.Style := bsSolid;
        Result.Canvas.Brush.Color := clWhite;
        Result.Canvas.FillRect(LabelBox);
        InflateRect(LabelBox, -2 * Scale, 0);
        DrawTextW(Result.Canvas.Handle, PWideChar(Text), Length(Text), LabelBox,
          DT_END_ELLIPSIS or DT_NOPREFIX or DT_SINGLELINE or DT_VCENTER);
      end;
    finally
      Picture.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure SaveOmDetPNG(const FileName: string; const Image: TOmDetBitmap);
var
  PNG: {$IFDEF FPC}TPortableNetworkGraphic{$ELSE}TPngImage{$ENDIF};
  Stream: TMemoryStream;
begin
  RequireCpu((Image <> nil) and not Image.Empty and not FileExists(FileName),
    'Choose a new PNG output file.');
  PNG := {$IFDEF FPC}TPortableNetworkGraphic{$ELSE}TPngImage{$ENDIF}.Create;
  try
    PNG.Assign(Image);
    Stream := TMemoryStream.Create;
    try
      PNG.SaveToStream(Stream);
      RequireCpu((Stream.Size > 0) and (Stream.Size <= MaxInt), 'Invalid PNG size');
      WriteNewOmDetFile(FileName, Stream.Memory, Stream.Size);
    finally
      Stream.Free;
    end;
  finally
    PNG.Free;
  end;
end;

end.
