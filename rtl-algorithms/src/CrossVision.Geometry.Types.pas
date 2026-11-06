{ ************************************************************************** }
{                                                                            }
{ CrossVision.Geometry.Types                                                 }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Geometry.Types;

interface

uses
  {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF};

type
  TPointD = record
    X: Double;
    Y: Double;
  end;

  TPointDArray = TArray<TPointD>;

  TRectD = record
    Left: Double;
    Top: Double;
    Right: Double;
    Bottom: Double;
  end;

  TRectDArray = TArray<TRectD>;

  TRectI = {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF}.TRect;

  TRectOverlapKind = (okNone, okSame, okInside, okInsideTL, okInsideTR, okInsideBR, okInsideBL,
    okInsideL, okInsideT, okInsideR, okInsideB, okInsideH, okInsideV, okInsideLTB, okInsideTLR,
    okInsideRTB, okInsideBLR, okOutside, okOutsideL, okOutsideT, okOutsideR, okOutsideB,
    okTL, okTR, okBR, okBL, okH, okV, okInnerL, okInnerT, okInnerR, okInnerB,
    okOuterL, okOuterT, okOuterR, okOuterB);

  TRectPositionKind = (pkNone, pkL, pkT, pkR, pkB, pkLT, pkTL, pkTR, pkRT, pkRB, pkBR, pkBL, pkLB,
    pkTTLL, pkTTRR, pkBBRR, pkBBLL, pkLTB, pkTLR, pkRTB, pkBLR);

  TRectAlignmentKind = (akNone, akL, akT, akR, akB, akTL, akTR, akRB, akLB);

  TQuadrantKind = (qkRightTop, qkLeftTop, qkLeftBottom, qkRightBottom);

  TPolarD = record
    Angle: Double;
    Distance: Double;
  end;

  TSegmentDArray = TArray<TPointDArray>;

  TFitKind = (fkContain, fkCover);

  TClipSide = (csInside, csOutside);

  TSegmentOrientation = (soHorizontal, soVertical, soOther);
  TSegmentOrientationArray = TArray<TSegmentOrientation>;

  TIndexTriple = record
    A: Integer;
    B: Integer;
    C: Integer;
  end;
  TIndexTripleArray = TArray<TIndexTriple>;

  TLineSpan = record
    First: Integer;
    Last: Integer;
    Spare: Boolean;
  end;
  TLineSpanArray = TArray<TLineSpan>;

  TBorderAngle = record
    Found: Boolean;
    FromAngle: Double;
    LastAngle: Double;
    Slip: Double;
  end;
  TBorderAngleArray = TArray<TBorderAngle>;

  TSkewPick = (spMean, spMaximum);

  TPointI = {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF}.TPoint;
  TPointIArray = TArray<TPointI>;

function PointD(const X, Y: Double): TPointD; inline; overload;
function PointD(const Point: TPointI): TPointD; inline; overload;
function RectD(const Left, Top, Right, Bottom: Double): TRectD; inline;

implementation

function PointD(const X, Y: Double): TPointD;
begin
  Result.X := X;
  Result.Y := Y;
end;

function PointD(const Point: TPointI): TPointD;
begin
  Result.X := Point.X;
  Result.Y := Point.Y;
end;

function RectD(const Left, Top, Right, Bottom: Double): TRectD;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Right := Right;
  Result.Bottom := Bottom;
end;

end.
