{ ************************************************************************** }
{                                                                            }
{ CrossVision.Morphology                                                     }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                                             }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Morphology;

interface

uses CrossVision.Image;

const
  DefaultFgThreshold = 128;

function ErodeRect(const Src: IImageAccessor; const W, H: Integer;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;

function DilateRect(const Src: IImageAccessor; const W, H: Integer;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;

function OpenRect(const Src: IImageAccessor; const W, H: Integer;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;

function CloseRect(const Src: IImageAccessor; const W, H: Integer;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;

function SubtractImages(const A, B: IImageAccessor;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;
function UnionImages(const A, B: IImageAccessor;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;
function IntersectImages(const A, B: IImageAccessor;
  const FgThreshold: Integer = DefaultFgThreshold): IImageBuffer;

implementation

type
  TBinaryMask = record
    W: Integer;
    H: Integer;
    Bits: TArray<Byte>;
  end;

  TPointwiseOp = (poSubtract, poUnion, poIntersect);

function EmptyMask(const AW, AH: Integer): TBinaryMask;
begin
  Result.W := AW;
  Result.H := AH;
  SetLength(Result.Bits, AW * AH);
end;

function BuildMask(const Src: IImageAccessor; const FgThreshold: Integer): TBinaryMask;
var
  X, Y: Integer;
begin
  if (Src.GetWidth <= 0) or (Src.GetHeight <= 0) then
    Exit(EmptyMask(0, 0));
  Result := EmptyMask(Src.GetWidth, Src.GetHeight);
  for Y := 0 to Result.H - 1 do
    for X := 0 to Result.W - 1 do
      if Src.GetPixel(X, Y) < FgThreshold then
        Result.Bits[Y * Result.W + X] := 1;
end;

function MaskToImage(const M: TBinaryMask): IImageBuffer;
var
  X, Y: Integer;
begin
  Result := MemoryImage(M.W, M.H);
  for Y := 0 to M.H - 1 do
    for X := 0 to M.W - 1 do
      if M.Bits[Y * M.W + X] <> 0 then
        Result.SetPixel(X, Y, 0)
      else
        Result.SetPixel(X, Y, 255);
end;

function ErodeMaskX(const M: TBinaryMask; const KW: Integer): TBinaryMask;
var
  X, Y, Row, Lo, Hi, I: Integer;
  Keep: Boolean;
begin
  Result := EmptyMask(M.W, M.H);
  for Y := 0 to M.H - 1 do
  begin
    Row := Y * M.W;
    for X := 0 to M.W - 1 do
    begin
      Lo := X - (KW div 2);
      Hi := Lo + KW - 1;
      if (Lo < 0) or (Hi > M.W - 1) then
        Continue;
      Keep := True;
      for I := Lo to Hi do
        if M.Bits[Row + I] = 0 then
        begin
          Keep := False;
          Break;
        end;
      if Keep then
        Result.Bits[Row + X] := 1;
    end;
  end;
end;

function ErodeMaskY(const M: TBinaryMask; const KH: Integer): TBinaryMask;
var
  X, Y, Lo, Hi, I: Integer;
  Keep: Boolean;
begin
  Result := EmptyMask(M.W, M.H);
  for Y := 0 to M.H - 1 do
  begin
    Lo := Y - (KH div 2);
    Hi := Lo + KH - 1;
    if (Lo < 0) or (Hi > M.H - 1) then
      Continue;
    for X := 0 to M.W - 1 do
    begin
      Keep := True;
      for I := Lo to Hi do
        if M.Bits[I * M.W + X] = 0 then
        begin
          Keep := False;
          Break;
        end;
      if Keep then
        Result.Bits[Y * M.W + X] := 1;
    end;
  end;
end;

function DilateMaskX(const M: TBinaryMask; const KW: Integer): TBinaryMask;
var
  X, Y, Row, Lo, Hi, I: Integer;
begin
  Result := EmptyMask(M.W, M.H);
  for Y := 0 to M.H - 1 do
  begin
    Row := Y * M.W;
    for X := 0 to M.W - 1 do
    begin
      Lo := X - (KW - 1 - (KW div 2));
      Hi := X + (KW div 2);
      if Lo < 0 then
        Lo := 0;
      if Hi > M.W - 1 then
        Hi := M.W - 1;
      for I := Lo to Hi do
        if M.Bits[Row + I] <> 0 then
        begin
          Result.Bits[Row + X] := 1;
          Break;
        end;
    end;
  end;
end;

function DilateMaskY(const M: TBinaryMask; const KH: Integer): TBinaryMask;
var
  X, Y, Lo, Hi, I: Integer;
begin
  Result := EmptyMask(M.W, M.H);
  for Y := 0 to M.H - 1 do
  begin
    Lo := Y - (KH - 1 - (KH div 2));
    Hi := Y + (KH div 2);
    if Lo < 0 then
      Lo := 0;
    if Hi > M.H - 1 then
      Hi := M.H - 1;
    for X := 0 to M.W - 1 do
      for I := Lo to Hi do
        if M.Bits[I * M.W + X] <> 0 then
        begin
          Result.Bits[Y * M.W + X] := 1;
          Break;
        end;
  end;
end;

function ErodeMask(const M: TBinaryMask; const KW, KH: Integer): TBinaryMask;
begin
  Result := ErodeMaskY(ErodeMaskX(M, KW), KH);
end;

function DilateMask(const M: TBinaryMask; const KW, KH: Integer): TBinaryMask;
begin
  Result := DilateMaskY(DilateMaskX(M, KW), KH);
end;

function ErodeRect(const Src: IImageAccessor; const W, H, FgThreshold: Integer): IImageBuffer;
begin
  if (W <= 0) or (H <= 0) then
    Exit(MemoryImage(0, 0));
  Result := MaskToImage(ErodeMask(BuildMask(Src, FgThreshold), W, H));
end;

function DilateRect(const Src: IImageAccessor; const W, H, FgThreshold: Integer): IImageBuffer;
begin
  if (W <= 0) or (H <= 0) then
    Exit(MemoryImage(0, 0));
  Result := MaskToImage(DilateMask(BuildMask(Src, FgThreshold), W, H));
end;

function OpenRect(const Src: IImageAccessor; const W, H, FgThreshold: Integer): IImageBuffer;
var
  M: TBinaryMask;
begin
  if (W <= 0) or (H <= 0) then
    Exit(MemoryImage(0, 0));
  M := BuildMask(Src, FgThreshold);
  Result := MaskToImage(DilateMask(ErodeMask(M, W, H), W, H));
end;

function CloseRect(const Src: IImageAccessor; const W, H, FgThreshold: Integer): IImageBuffer;
var
  M: TBinaryMask;
begin
  if (W <= 0) or (H <= 0) then
    Exit(MemoryImage(0, 0));
  M := BuildMask(Src, FgThreshold);
  Result := MaskToImage(ErodeMask(DilateMask(M, W, H), W, H));
end;

function Pointwise(const A, B: IImageAccessor; const FgThreshold: Integer;
  const Op: TPointwiseOp): IImageBuffer;
var
  X, Y, AW, AH, BW, BH: Integer;
  FgA, FgB, Fg: Boolean;
begin
  AW := A.GetWidth;
  AH := A.GetHeight;
  BW := B.GetWidth;
  BH := B.GetHeight;
  Result := MemoryImage(AW, AH);
  for Y := 0 to AH - 1 do
    for X := 0 to AW - 1 do
    begin
      FgA := A.GetPixel(X, Y) < FgThreshold;
      FgB := (X < BW) and (Y < BH) and (B.GetPixel(X, Y) < FgThreshold);
      case Op of
        poSubtract: Fg := FgA and not FgB;
        poUnion: Fg := FgA or FgB;
      else
        Fg := FgA and FgB;
      end;
      if Fg then
        Result.SetPixel(X, Y, 0)
      else
        Result.SetPixel(X, Y, 255);
    end;
end;

function SubtractImages(const A, B: IImageAccessor; const FgThreshold: Integer): IImageBuffer;
begin
  Result := Pointwise(A, B, FgThreshold, poSubtract);
end;

function UnionImages(const A, B: IImageAccessor; const FgThreshold: Integer): IImageBuffer;
begin
  Result := Pointwise(A, B, FgThreshold, poUnion);
end;

function IntersectImages(const A, B: IImageAccessor; const FgThreshold: Integer): IImageBuffer;
begin
  Result := Pointwise(A, B, FgThreshold, poIntersect);
end;

end.
