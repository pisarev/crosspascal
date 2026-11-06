{ ************************************************************************** }
{                                                                            }
{ CrossVision.MatPix                                                         }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.MatPix;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF},
  OpenCVTypes,
  OpenCVConsts,
  CrossVision.Mat,
  CrossVision.Pix;

function PixToMat(const Source: IPix): IMat;

function MatToPix(const Source: IMat): IPix;

function CenteredCropRect(const SrcW, SrcH, W, H: Integer): TRect;

function ScaleToSize(const Source: IMat; const W, H: Integer): IMat;

function CropCentered(const Source: IMat; const W, H: Integer): IMat; overload;
function CropCentered(const Source: IPix; const W, H: Integer): IPix; overload;

implementation

const
  RED_SHIFT = 24;
  GREEN_SHIFT = 16;
  BLUE_SHIFT = 8;
  ALPHA_SHIFT = 0;

function PixToMat(const Source: IPix): IMat;
var
  W, H, X, Y, Depth: Integer;
  Word32: Cardinal;
  Row: PByte;
begin
  Result := WrapMat(nil, False);
  if (Source = nil) or Source.IsEmpty then Exit;
  Depth := Source.GetDepth;
  if (Depth <> 8) and (Depth <> 32) then Exit;
  W := Source.GetWidth;
  H := Source.GetHeight;
  if (W <= 0) or (H <= 0) then Exit;
  if Depth = 8 then
    Result := NewMat(W, H, CV_MAKETYPE(CV_8U, 1))
  else
    Result := NewMat(W, H, CV_MAKETYPE(CV_8U, 4));
  if Result.IsEmpty or (Result.DataPtr = nil) then
  begin
    Result := WrapMat(nil, False);
    Exit;
  end;
  for Y := 0 to H - 1 do
  begin
    Row := PByte(Result.DataPtr);
    Inc(Row, Y * Result.Step);
    for X := 0 to W - 1 do
    begin
      Word32 := Source.GetPixel(X, Y);
      if Depth = 8 then
      begin
        Row^ := Byte(Word32);
        Inc(Row);
      end
      else begin
        Row^ := Byte(Word32 shr BLUE_SHIFT);
        Inc(Row);
        Row^ := Byte(Word32 shr GREEN_SHIFT);
        Inc(Row);
        Row^ := Byte(Word32 shr RED_SHIFT);
        Inc(Row);
        Row^ := Byte(Word32 shr ALPHA_SHIFT);
        Inc(Row);
      end;
    end;
  end;
end;

function MatToPix(const Source: IMat): IPix;
var
  W, H, X, Y, ChannelCount: Integer;
  R, G, B, A: Cardinal;
  Row: PByte;
begin
  Result := WrapPix(nil, False);
  if (Source = nil) or Source.IsEmpty or (Source.DataPtr = nil) then Exit;
  if Source.Depth <> CV_8U then Exit;
  ChannelCount := Source.Channels;
  if (ChannelCount <> 1) and (ChannelCount <> 3) and (ChannelCount <> 4) then Exit;
  W := Source.Width;
  H := Source.Height;
  if (W <= 0) or (H <= 0) then Exit;
  if ChannelCount = 1 then
    Result := NewPix(W, H, 8)
  else
    Result := NewPix(W, H, 32);
  if Result.IsEmpty then
  begin
    Result := WrapPix(nil, False);
    Exit;
  end;
  for Y := 0 to H - 1 do
  begin
    Row := PByte(Source.DataPtr);
    Inc(Row, Y * Source.Step);
    for X := 0 to W - 1 do
    begin
      if ChannelCount = 1 then
      begin
        Result.SetPixel(X, Y, Row^);
        Inc(Row);
      end
      else begin
        B := Row^;
        Inc(Row);
        G := Row^;
        Inc(Row);
        R := Row^;
        Inc(Row);
        if ChannelCount = 4 then
        begin
          A := Row^;
          Inc(Row);
        end
        else
          A := 255;
        Result.SetPixel(X, Y,
          (R shl RED_SHIFT) or (G shl GREEN_SHIFT) or (B shl BLUE_SHIFT) or (A shl ALPHA_SHIFT));
      end;
    end;
  end;
end;

function ScaleToSize(const Source: IMat; const W, H: Integer): IMat;
var
  ChannelCount: Integer;
  P: IPix;
begin
  Result := WrapMat(nil, False);
  if (Source = nil) or Source.IsEmpty or (W <= 0) or (H <= 0) then Exit;
  if (Source.Width = W) and (Source.Height = H) then Exit(Source);
  ChannelCount := Source.Channels;
  P := MatToPix(Source);
  if (P = nil) or P.IsEmpty then Exit;
  P := P.ScaleToSize(W, H);
  if (P = nil) or P.IsEmpty then Exit;
  Result := PixToMat(P);
  if Result.IsEmpty then Exit;
  Result := ConvertChannels(Result, ChannelCount);
end;

function CenteredCropRect(const SrcW, SrcH, W, H: Integer): TRect;
begin
  Result.Left := (SrcW - W) div 2;
  Result.Top := (SrcH - H) div 2;
  Result.Right := Result.Left + W - 1;
  Result.Bottom := Result.Top + H - 1;
  if Result.Left < 0 then Result.Left := 0;
  if Result.Top < 0 then Result.Top := 0;
  if Result.Right > SrcW - 1 then Result.Right := SrcW - 1;
  if Result.Bottom > SrcH - 1 then Result.Bottom := SrcH - 1;
  Inc(Result.Right);
  Inc(Result.Bottom);
end;

function CropCentered(const Source: IMat; const W, H: Integer): IMat;
var
  R: TRect;
begin
  if (Source = nil) or Source.IsEmpty or (W <= 0) or (H <= 0) then
    Exit(WrapMat(nil, False));
  R := CenteredCropRect(Source.Width, Source.Height, W, H);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit(WrapMat(nil, False));
  Result := ExtractRegion(Source, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
end;

function CropCentered(const Source: IPix; const W, H: Integer): IPix;
var
  R: TRect;
begin
  if (Source = nil) or Source.IsEmpty or (W <= 0) or (H <= 0) then
    Exit(WrapPix(nil, False));
  R := CenteredCropRect(Source.GetWidth, Source.GetHeight, W, H);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit(WrapPix(nil, False));
  Result := Source.Crop(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
end;

end.
