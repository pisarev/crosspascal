{ ************************************************************************** }
{                                                                            }
{ CrossVision.Geometry                                                       }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                                             }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Geometry;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  CrossVision.Geometry.Types;

function Orient2D(const A, B, C: TPointI): Int64;

function SegmentsIntersect(const A, B, C, D: TPointI): Boolean;

function LinesIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;

function SegmentsIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;

function RayLineIntersection(const Origin, Through, C, D: TPointD; out Point: TPointD;
  const Epsilon: Double = 1e-9): Boolean;

function LineCircleIntersection(const A, B, Center: TPointD; const Radius: Double;
  out P1, P2: TPointD; const Epsilon: Double = 1e-9): Integer;

function CircleCircleIntersection(const Center1: TPointD; const Radius1: Double;
  const Center2: TPointD; const Radius2: Double; out P1, P2: TPointD;
  const Epsilon: Double = 1e-9): Integer;

function PointInPolygon(const X, Y: Double; const Polygon: TPointDArray): Boolean; overload;
function PointInPolygon(const Point: TPointD; const Polygon: TPointDArray): Boolean; overload;

function PointInAnyPolygon(const Point: TPointD; const Polygons: array of TPointDArray): Boolean;

function ClipSegmentByPolygon(const A, B: TPointD; const Polygon: TPointDArray;
  const Side: TClipSide): TSegmentDArray;

function NextDistinctPointOnRay(const Origin: TPointD; const Angle: Double; var Distance: Integer;
  const Previous: TPointI; const MaxSteps: Integer = 10000): TPointI;

function BuildRadialScanLines(const Center: TPointD; const Width, Height: Integer;
  const MinAngle, MaxAngle, Step: Double): TSegmentDArray;

function BuildRibbonPolygon(const LeftBorder, RightBorder: TPointDArray): TPointDArray;

function FitSizePreserveAspect(const SrcW, SrcH, BoxW, BoxH: Integer; const Kind: TFitKind;
  out W, H: Integer): Boolean;

function SegmentsMeetByEnds(const A1, A2, B1, B2: TPointD; const MaxGap: Double): Boolean;

function FindBracketTriples(const Segments: TSegmentDArray;
  const Orientation: TSegmentOrientationArray; const MaxGap: Double): TIndexTripleArray;

function SpanWidth(const Span: TLineSpan): Integer;

function MeanSpanWidth(const Spans: TLineSpanArray; out Width: Integer): Boolean;

function FindSpanBulges(const Spans: TLineSpanArray; const MeanWidth: Integer;
  const ExcessFactor: Double): TArray<Integer>;

function ClassifyRuledLine(var Spans: TLineSpanArray; const MaxWidth, MinRun, MaxRun: Integer;
  const WidthFactor, ExcessFactor: Double): Boolean;

function BorderAngleValue(const Border: TBorderAngle): Double;

function ArbitrateOppositeBorders(var First, Second: TBorderAngle;
  const Epsilon: Double = 1e-9): Boolean;

function RejectSkewOutliers(const Angles: TArray<Double>;
  const MaxDeviation: Double): TArray<Double>;

function CombineSkewAngles(const Angles: TArray<Double>; const Pick: TSkewPick;
  const Minimum: Integer; out Skew: Double): Boolean;

function MergeCollinearLines(const Segments: TSegmentDArray; const Horizontal: Boolean;
  const CrossVary, MaxGap, MinLength: Double): TSegmentDArray;

function ExtractAxisLinesFromContour(const Contour: TPointDArray;
  const AngleVary, MinLength, MaxGap: Double; out Horizontals, Verticals: TSegmentDArray): Integer;

function RotatedBoundingSize(const SrcW, SrcH: Integer; const Angle: Double;
  out W, H: Integer): Boolean;

function InverseRotateMapPoint(const Target, SourceCenter, TargetCenter: TPointI;
  const Quadrant: TQuadrantKind; const Angle: Double; const MinAngle: Double = 1e-9): TPointI;

function ZoneGridSize(const SrcW, SrcH, ZoneW, ZoneH: Integer; out Cols, Rows: Integer): Boolean;

function ClosePolygon(const Polygon: TPointDArray): TPointDArray;

function ReversePolyline(const Points: TPointDArray): TPointDArray;

function PolygonSignedArea(const Polygon: TPointDArray): Double;

function PolygonArea(const Polygon: TPointDArray): Double;

function PolygonCentroid(const Polygon: TPointDArray): TPointD;

function MeanPoint(const Points: TPointDArray): TPointD;

function ConvexHull(const Points: TPointDArray; const Close: Boolean = False): TPointDArray;

function MinAreaRectAngle(const Points: TPointDArray): Double; overload;

function MinAreaRectAngle(const Points: TPointDArray; out Long, Short: Double): Double; overload;

function Distance(const A, B: TPointD): Double;

function LineSlope(const A, B: TPointD): Double;

function SanitizeSlope(const A, B: TPointD; const Epsilon: Double = 1e-9): Double;

function SlopeToAngle(const Slope: Double): Double;

function AngleToSlope(const Angle: Double): Double;

function LineYIntercept(const P: TPointD; const Slope: Double): Double;

function DirectionAngle(const A, B: TPointD): Double;

function IncludedAngle(const P1, Vertex, P2: TPointD): Double;

function WrapAngle360(const Angle: Double): Double;

function WrapAngle180(const Angle: Double): Double;

function AngularDifference(const A, B: Double): Double;

function CircularMean(const Angles: TArray<Double>): Double;

function PointAtAngleDistance(const P: TPointD; const Angle, Dist: Double): TPointD;

function ToPolar(const Center, Point: TPointD): TPolarD;

function QuadrantOf(const Center, Point: TPointD): TQuadrantKind;

function CounterClockwiseAngle(const Quadrant: TQuadrantKind; const Angle: Double): Double;

function PointSideOfLine(const P, A, B: TPointD): Integer;

function PointOnSegment(const P, A, B: TPointD; const Epsilon: Double = 1e-9): Boolean;

function PointsOnSegment(const Points: TPointDArray; const A, B: TPointD;
  const Epsilon: Double = 1e-9): Boolean;

function SegmentsCollinear(const A, B, C, D: TPointD; const Epsilon: Double = 1e-9): Boolean;

function CollinearOverlapLength(const A, B, C, D: TPointD): Double;

function RotatePoints(const Points: TPointDArray; const Angle: Double; const Center: TPointD): TPointDArray;

function ShearPoints(const Points: TPointDArray; const XSkew, YSkew: Double): TPointDArray;

function TurnPointsAboutMeanPoint(const Points: TPointDArray; const Angle: Double): TPointDArray;

function ScalePointsAboutMeanPoint(const Points: TPointDArray; const Factor: Double): TPointDArray;

function BoundingBox(const Points: TPointDArray): TRectD;

function NearestPoint(const FromPoint: TPointD; const Points: TPointDArray; out Index: Integer): Boolean;

function NormalizeRect(const R: TRectD): TRectD;
function RectWidth(const R: TRectD): Double;
function RectHeight(const R: TRectD): Double;
function RectArea(const R: TRectD): Double;
function RectIsEmpty(const R: TRectD): Boolean;
function RectCenter(const R: TRectD): TPointD;

function RectToPolygon(const R: TRectD): TPointDArray;

function RectsIntersect(const A, B: TRectD): Boolean;

function RectIntersection(const A, B: TRectD; out R: TRectD): Boolean;

function RectUnion(const A, B: TRectD): TRectD; overload;
function RectUnion(const Rects: TRectDArray): TRectD; overload;

function RectIoU(const A, B: TRectD): Double;

function RectGap(const A, B: TRectD): Double;

function RectsApproxEqual(const A, B: TRectD; const Tolerance: Double): Boolean;

function RectsCloserThan(const A, B: TRectD; const MaxGap: Double): Boolean;

function RectsWithinMargin(const A, B: TRectI; const XMargin, YMargin: Integer): Boolean;

function LargestTileSizeForCount(const SrcW, SrcH, Count: Integer;
  out TileW, TileH: Integer): Boolean;

function MergeNearbyRects(const Rects: TRectDArray; const MaxGap: Double): TRectDArray;

function RotateRectCorners(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TPointDArray; overload;

function RotateRectCorners(const R: TRectD; const Skew: Double): TPointDArray; overload;

function RotatedRectBounds(const R: TRectD; const Skew: Double): TRectD; overload;

function RotatedRectBounds(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TRectD; overload;

function ClassifyRectOverlap(const First, Second: TRectI): TRectOverlapKind;

function ClassifyRectPosition(const First, Second: TRectI): TRectPositionKind;

function RectRelativeAlignment(const First, Second: TRectI): TRectAlignmentKind;

implementation

uses
  {$IFDEF FPC}
  Types, Math;
  {$ELSE}
  System.Types, System.Math;
  {$ENDIF}

const
  GeometryEpsilon = 1e-12;
  TwoPi = 2 * Pi;

function Orient2D(const A, B, C: TPointI): Int64;
begin
  Result := Int64(B.X - A.X) * Int64(C.Y - A.Y) - Int64(B.Y - A.Y) * Int64(C.X - A.X);
end;

function OnBox(const A, B, P: TPointI): Boolean;
begin
  Result := (P.X >= Min(A.X, B.X)) and (P.X <= Max(A.X, B.X)) and (P.Y >= Min(A.Y, B.Y)) and
    (P.Y <= Max(A.Y, B.Y));
end;

function SegmentsIntersect(const A, B, C, D: TPointI): Boolean;
var
  O1, O2, O3, O4: Int64;
begin
  O1 := Orient2D(A, B, C);
  O2 := Orient2D(A, B, D);
  O3 := Orient2D(C, D, A);
  O4 := Orient2D(C, D, B);
  if (((O1 > 0) and (O2 < 0)) or ((O1 < 0) and (O2 > 0))) and (((O3 > 0) and (O4 < 0)) or ((O3 < 0) and
    (O4 > 0))) then
      Exit(True);
  if (O1 = 0) and OnBox(A, B, C) then Exit(True);
  if (O2 = 0) and OnBox(A, B, D) then Exit(True);
  if (O3 = 0) and OnBox(C, D, A) then Exit(True);
  if (O4 = 0) and OnBox(C, D, B) then Exit(True);
  Result := False;
end;

function CrossD(const AX, AY, BX, BY: Double): Double; inline;
begin
  Result := AX * BY - AY * BX;
end;

function LinesIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;
var
  RX, RY, SX, SY, Denom, T: Double;
begin
  Point := PointD(0, 0);
  RX := B.X - A.X;
  RY := B.Y - A.Y;
  SX := D.X - C.X;
  SY := D.Y - C.Y;
  Denom := CrossD(RX, RY, SX, SY);
  if Abs(Denom) < GeometryEpsilon then Exit(False);
  T := CrossD(C.X - A.X, C.Y - A.Y, SX, SY) / Denom;
  Point := PointD(A.X + T * RX, A.Y + T * RY);
  Result := True;
end;

function SegmentsIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;
var
  RX, RY, SX, SY, Denom, T, U: Double;
begin
  Point := PointD(0, 0);
  RX := B.X - A.X;
  RY := B.Y - A.Y;
  SX := D.X - C.X;
  SY := D.Y - C.Y;
  Denom := CrossD(RX, RY, SX, SY);
  if Abs(Denom) < GeometryEpsilon then Exit(False);
  T := CrossD(C.X - A.X, C.Y - A.Y, SX, SY) / Denom;
  U := CrossD(C.X - A.X, C.Y - A.Y, RX, RY) / Denom;
  if (T < 0) or (T > 1) or (U < 0) or (U > 1) then Exit(False);
  Point := PointD(A.X + T * RX, A.Y + T * RY);
  Result := True;
end;

function PointInPolygon(const X, Y: Double; const Polygon: TPointDArray): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Length(Polygon) < 3 then Exit;
  J := High(Polygon);
  for I := Low(Polygon) to High(Polygon) do
  begin
    if (((Polygon[I].Y < Y) and (Polygon[J].Y >= Y)) or ((Polygon[J].Y < Y) and (Polygon[I].Y >= Y))) and
      (Polygon[I].X + (Y - Polygon[I].Y) / (Polygon[J].Y - Polygon[I].Y) * (Polygon[J].X - Polygon[I].X) > X) then
        Result := not Result;
    J := I;
  end;
end;

function PointInPolygon(const Point: TPointD; const Polygon: TPointDArray): Boolean;
begin
  Result := PointInPolygon(Point.X, Point.Y, Polygon);
end;

function RayLineIntersection(const Origin, Through, C, D: TPointD; out Point: TPointD;
  const Epsilon: Double): Boolean;
var
  Travel: Double;
begin
  Result := LinesIntersectionPoint(Origin, Through, C, D, Point);
  if not Result then Exit;
  Travel := (Through.X - Origin.X) * (Point.X - Origin.X) +
    (Through.Y - Origin.Y) * (Point.Y - Origin.Y);
  Result := Travel >= -Epsilon;
end;

function LineCircleIntersection(const A, B, Center: TPointD; const Radius: Double;
  out P1, P2: TPointD; const Epsilon: Double): Integer;
var
  DX, DY, FX, FY, KA, KB, KC, Discriminant, Eps, Root, T1, T2: Double;
begin
  P1 := PointD(0, 0);
  P2 := PointD(0, 0);
  if Radius < 0 then Exit(0);
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  KA := DX * DX + DY * DY;
  if KA <= Epsilon then Exit(0);
  FX := A.X - Center.X;
  FY := A.Y - Center.Y;
  KB := 2 * (FX * DX + FY * DY);
  KC := FX * FX + FY * FY - Radius * Radius;
  Discriminant := KB * KB - 4 * KA * KC;
  Eps := Epsilon * (Abs(KB * KB) + Abs(4 * KA * KC) + 1);
  if Discriminant < -Eps then Exit(0);
  if Discriminant <= Eps then
  begin
    T1 := -KB / (2 * KA);
    P1 := PointD(A.X + T1 * DX, A.Y + T1 * DY);
    P2 := P1;
    Exit(1);
  end;
  Root := Sqrt(Discriminant);
  T1 := (-KB - Root) / (2 * KA);
  T2 := (-KB + Root) / (2 * KA);
  P1 := PointD(A.X + T1 * DX, A.Y + T1 * DY);
  P2 := PointD(A.X + T2 * DX, A.Y + T2 * DY);
  Result := 2;
end;

function CircleCircleIntersection(const Center1: TPointD; const Radius1: Double;
  const Center2: TPointD; const Radius2: Double; out P1, P2: TPointD;
  const Epsilon: Double): Integer;
var
  Between, AlongDist, HalfChord, Angle, Sq, Eps: Double;
  Base: TPointD;
begin
  P1 := PointD(0, 0);
  P2 := PointD(0, 0);
  if (Radius1 < 0) or (Radius2 < 0) then Exit(0);
  Between := Distance(Center1, Center2);
  if Between <= Epsilon then Exit(0);
  AlongDist := (Radius1 * Radius1 - Radius2 * Radius2 + Between * Between) / (2 * Between);
  Sq := Radius1 * Radius1 - AlongDist * AlongDist;
  Eps := Epsilon * (Radius1 * Radius1 + 1);
  if Sq < -Eps then Exit(0);
  Angle := DirectionAngle(Center1, Center2);
  Base := PointAtAngleDistance(Center1, Angle, AlongDist);
  if Sq <= Eps then
  begin
    P1 := Base;
    P2 := Base;
    Exit(1);
  end;
  HalfChord := Sqrt(Sq);
  P1 := PointAtAngleDistance(Base, Angle + Pi / 2, HalfChord);
  P2 := PointAtAngleDistance(Base, Angle + Pi / 2, -HalfChord);
  Result := 2;
end;

function NextDistinctPointOnRay(const Origin: TPointD; const Angle: Double; var Distance: Integer;
  const Previous: TPointI; const MaxSteps: Integer): TPointI;
var
  StepIndex, Dist: Integer;
  P: TPointD;
begin
  Result := Previous;
  Dist := Distance;
  for StepIndex := 1 to MaxSteps do
  begin
    Inc(Dist);
    P := PointAtAngleDistance(Origin, Angle, Dist);
    if IsNan(P.X) or IsNan(P.Y) or IsInfinite(P.X) or IsInfinite(P.Y) then Exit;
    Result := Point(Round(P.X), Round(P.Y));
    if (Result.X <> Previous.X) or (Result.Y <> Previous.Y) then
    begin
      Distance := Dist;
      Exit;
    end;
  end;
  Result := Previous;
end;

function ClipSegmentByPolygon(const A, B: TPointD; const Polygon: TPointDArray;
  const Side: TClipSide): TSegmentDArray;
var
  Pts: TPointDArray;
  I, J, N: Integer;
  P, Mid: TPointD;
  Inside, Keep: Boolean;
  Tmp: TPointD;
begin
  Result := nil;
  if Length(Polygon) < 2 then Exit;
  N := 0;
  SetLength(Pts, Length(Polygon));
  for I := 0 to High(Polygon) - 1 do
    if SegmentsIntersectionPoint(A, B, Polygon[I], Polygon[I + 1], P) then
    begin
      Pts[N] := P;
      Inc(N);
    end;
  SetLength(Pts, N);
  for I := 0 to High(Pts) - 1 do
    for J := 0 to High(Pts) - 1 - I do
      if Distance(A, Pts[J]) > Distance(A, Pts[J + 1]) then
      begin
        Tmp := Pts[J];
        Pts[J] := Pts[J + 1];
        Pts[J + 1] := Tmp;
      end;
  Pts := [A] + Pts;
  Pts := Pts + [B];
  for I := 0 to High(Pts) - 1 do
  begin
    Mid := PointD((Pts[I].X + Pts[I + 1].X) / 2, (Pts[I].Y + Pts[I + 1].Y) / 2);
    Inside := PointInPolygon(Mid, Polygon);
    if Side = csInside then
      Keep := Inside
    else
      Keep := not Inside;
    if Keep then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := [Pts[I], Pts[I + 1]];
    end;
  end;
end;

function PointInAnyPolygon(const Point: TPointD; const Polygons: array of TPointDArray): Boolean;
var
  I: Integer;
begin
  for I := Low(Polygons) to High(Polygons) do
    if PointInPolygon(Point, Polygons[I]) then Exit(True);
  Result := False;
end;

function BuildRadialScanLines(const Center: TPointD; const Width, Height: Integer;
  const MinAngle, MaxAngle, Step: Double): TSegmentDArray;

  function InBounds(const P: TPointD): Boolean;
  begin
    Result := (P.X >= 0) and (P.X <= Width - 1) and (P.Y >= 0) and (P.Y <= Height - 1);
  end;

var
  Angle, ScreenAngle, SinA, CosA, EdgeY, EdgeX, Travel: Double;
  Hit: TPointD;
  Count, StepIndex: Integer;
begin
  Result := nil;
  if (Width <= 0) or (Height <= 0) or (Step <= 0) then Exit;
  if IsNan(MinAngle) or IsNan(MaxAngle) or IsNan(Step) then Exit;
  if IsInfinite(Step) then Exit;
  if not InBounds(Center) then Exit;
  Count := 0;
  StepIndex := 0;
  Angle := MinAngle;
  while Angle < MaxAngle do
  begin
    ScreenAngle := WrapAngle360(-Angle);
    SinA := Sin(ScreenAngle);
    CosA := Cos(ScreenAngle);
    if SinA < 0 then
      EdgeY := 0
    else
      EdgeY := Height - 1;
    if CosA > 0 then
      EdgeX := Width - 1
    else
      EdgeX := 0;
    Hit.X := -1;
    Hit.Y := -1;
    if SinA <> 0 then
    begin
      Travel := (EdgeY - Center.Y) / SinA;
      Hit.X := Center.X + Travel * CosA;
      Hit.Y := EdgeY;
    end;
    if not InBounds(Hit) and (CosA <> 0) then
    begin
      Travel := (EdgeX - Center.X) / CosA;
      Hit.X := EdgeX;
      Hit.Y := Center.Y + Travel * SinA;
    end;
    if InBounds(Hit) then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := [Center, Hit];
      Inc(Count);
    end;
    Inc(StepIndex);
    Angle := MinAngle + StepIndex * Step;
  end;
end;

function BuildRibbonPolygon(const LeftBorder, RightBorder: TPointDArray): TPointDArray;
var
  I, LeftCount, RightCount: Integer;
begin
  Result := nil;
  LeftCount := Length(LeftBorder);
  RightCount := Length(RightBorder);
  if (LeftCount < 2) or (RightCount < 2) then Exit;
  SetLength(Result, LeftCount + RightCount);
  for I := 0 to LeftCount - 1 do Result[I] := LeftBorder[I];
  for I := 0 to RightCount - 1 do Result[LeftCount + I] := RightBorder[RightCount - 1 - I];
  Result := ClosePolygon(Result);
end;

function FitSizePreserveAspect(const SrcW, SrcH, BoxW, BoxH: Integer; const Kind: TFitKind;
  out W, H: Integer): Boolean;
var
  HeightBinds: Boolean;
begin
  W := 0;
  H := 0;
  Result := (SrcW > 0) and (SrcH > 0) and (BoxW > 0) and (BoxH > 0);
  if not Result then Exit;
  W := BoxW;
  H := BoxH;
  HeightBinds := Int64(SrcW) * BoxH < Int64(SrcH) * BoxW;
  if (Kind = fkContain) = HeightBinds then
    W := Integer(Int64(SrcW) * BoxH div SrcH)
  else
    H := Integer(Int64(SrcH) * BoxW div SrcW);
  Result := (W > 0) and (H > 0);
  if not Result then
  begin
    W := 0;
    H := 0;
  end;
end;

function SegmentsMeetByEnds(const A1, A2, B1, B2: TPointD; const MaxGap: Double): Boolean;
begin
  Result := (Distance(A1, B1) <= MaxGap) or (Distance(A2, B1) <= MaxGap) or
    (Distance(A1, B2) <= MaxGap) or (Distance(A2, B2) <= MaxGap);
end;

function FindBracketTriples(const Segments: TSegmentDArray;
  const Orientation: TSegmentOrientationArray; const MaxGap: Double): TIndexTripleArray;

  function OrientationAt(const N: Integer): TSegmentOrientation;
  begin
    if (N >= Low(Orientation)) and (N <= High(Orientation)) then
      Result := Orientation[N]
    else
      Result := soOther;
  end;

var
  I, J, L, Count: Integer;
  Across: TSegmentOrientation;
begin
  Result := nil;
  Count := 0;
  if Length(Segments) <> Length(Orientation) then Exit;
  for I := Low(Segments) to High(Segments) do
  begin
    if Length(Segments[I]) <> 2 then Continue;
    if OrientationAt(I) = soHorizontal then
      Across := soVertical
    else if OrientationAt(I) = soVertical then
        Across := soHorizontal
      else
        Continue;
    for J := Low(Segments) to High(Segments) do
    begin
      if (J = I) or (OrientationAt(J) <> Across) or (Length(Segments[J]) <> 2) then Continue;
      if not SegmentsMeetByEnds(Segments[J][0], Segments[J][1],
                                Segments[I][0], Segments[I][1], MaxGap) then Continue;
      for L := Low(Segments) to High(Segments) do
      begin
        if (L = I) or (L = J) or (OrientationAt(L) <> OrientationAt(I)) then Continue;
        if Length(Segments[L]) <> 2 then Continue;
        if Distance(Segments[L][0], Segments[J][1]) > MaxGap then Continue;
        SetLength(Result, Count + 1);
        Result[Count].A := I;
        Result[Count].B := J;
        Result[Count].C := L;
        Inc(Count);
      end;
    end;
  end;
end;

function SpanWidth(const Span: TLineSpan): Integer;
begin
  if (Span.First < 0) or (Span.Last < 0) then Exit(0);
  Result := Span.Last - Span.First + 1;
  if Result < 0 then Result := 0;
end;

function MeanSpanWidth(const Spans: TLineSpanArray; out Width: Integer): Boolean;
var
  I, GoodCount, Total: Integer;
begin
  Width := 0;
  GoodCount := 0;
  Total := 0;
  for I := Low(Spans) to High(Spans) do
    if SpanWidth(Spans[I]) > 0 then
    begin
      Inc(Total, SpanWidth(Spans[I]));
      Inc(GoodCount);
    end;
  if GoodCount > 0 then Width := Total div GoodCount;
  Result := GoodCount > 0;
end;

function FindSpanBulges(const Spans: TLineSpanArray; const MeanWidth: Integer;
  const ExcessFactor: Double): TArray<Integer>;
var
  I, Threshold, Count: Integer;
begin
  Result := nil;
  Count := 0;
  if MeanWidth <= 0 then Exit;
  Threshold := Round(MeanWidth * ExcessFactor);
  for I := Low(Spans) to High(Spans) do
    if SpanWidth(Spans[I]) > Threshold then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := I;
      Inc(Count);
    end;
end;

function ClassifyRuledLine(var Spans: TLineSpanArray; const MaxWidth, MinRun, MaxRun: Integer;
  const WidthFactor, ExcessFactor: Double): Boolean;

  procedure MarkSpare(const FromIndex, ToIndex: Integer);
  var
    N: Integer;
  begin
    for N := FromIndex to ToIndex do
      if (N >= Low(Spans)) and (N <= High(Spans)) then Spans[N].Spare := True;
  end;

var
  MeanWidth, I, RunStart, RunEnd: Integer;
  Bulges: TArray<Integer>;
begin
  Result := False;
  if not MeanSpanWidth(Spans, MeanWidth) then Exit;
  if MeanWidth > MaxWidth * WidthFactor then Exit;
  Bulges := FindSpanBulges(Spans, MeanWidth, ExcessFactor);
  if Length(Bulges) = 0 then Exit(True);
  for I := 0 to Length(Bulges) do
  begin
    if I = 0 then
      RunStart := Low(Spans)
    else
      RunStart := Bulges[I - 1];
    if I = Length(Bulges) then
      RunEnd := High(Spans)
    else
      RunEnd := Bulges[I];
    if RunEnd - RunStart >= MinRun then Result := True;
    if RunEnd - RunStart <= MaxRun then MarkSpare(RunStart, RunEnd);
  end;
  for I := Low(Bulges) to High(Bulges) do
    MarkSpare(Bulges[I] - MaxWidth, Bulges[I] + MaxWidth);
end;

function BorderAngleValue(const Border: TBorderAngle): Double;
begin
  if not Border.Found then Exit(0);
  Result := (Border.FromAngle + Border.LastAngle) / 2;
end;

function ArbitrateOppositeBorders(var First, Second: TBorderAngle; const Epsilon: Double): Boolean;
begin
  Result := First.Found and Second.Found and (Abs(First.Slip - Second.Slip) > Epsilon);
  if not Result then Exit;
  if First.Slip > Second.Slip then
    First.Found := False
  else
    Second.Found := False;
end;

function RejectSkewOutliers(const Angles: TArray<Double>;
  const MaxDeviation: Double): TArray<Double>;
var
  I, Count: Integer;
  Spread, Deviation: Double;
begin
  Result := Copy(Angles);
  if Length(Result) <= 2 then Exit;
  Spread := StdDev(Result);
  Count := 0;
  for I := Low(Result) to High(Result) do
  begin
    Deviation := Abs(Result[I]) - Spread;
    if Deviation < 0 then Deviation := 0;
    if Deviation <= MaxDeviation then
    begin
      Result[Count] := Result[I];
      Inc(Count);
    end;
  end;
  SetLength(Result, Count);
end;

function CombineSkewAngles(const Angles: TArray<Double>; const Pick: TSkewPick;
  const Minimum: Integer; out Skew: Double): Boolean;
var
  I: Integer;
  Total: Double;
begin
  Skew := 0;
  Result := Length(Angles) >= Minimum;
  if not Result or (Length(Angles) = 0) then Exit;
  if Pick = spMaximum then
  begin
    for I := Low(Angles) to High(Angles) do
      if Abs(Skew) < Abs(Angles[I]) then Skew := Angles[I];
  end
  else begin
    Total := 0;
    for I := Low(Angles) to High(Angles) do Total := Total + Angles[I];
    Skew := Total / Length(Angles);
  end;
end;

function MergeCollinearLines(const Segments: TSegmentDArray; const Horizontal: Boolean;
  const CrossVary, MaxGap, MinLength: Double): TSegmentDArray;
var
  Kept: TSegmentDArray;
  Alive: TArray<Boolean>;

  function AlongAxis(const P: TPointD): Double;
  begin
    if Horizontal then
      Result := P.X
    else
      Result := P.Y;
  end;

  function AcrossAxis(const P: TPointD): Double;
  begin
    if Horizontal then
      Result := P.Y
    else
      Result := P.X;
  end;

  function MidAcross(const S: TPointDArray): Double;
  begin
    Result := (AcrossAxis(S[0]) + AcrossAxis(S[1])) / 2;
  end;

  function BandGap(const A, B: TPointDArray): Double;
  var
    A1, A2, B1, B2: Double;
  begin
    A1 := AcrossAxis(A[0]);
    A2 := AcrossAxis(A[1]);
    if A1 > A2 then
    begin
      Result := A1;
      A1 := A2;
      A2 := Result;
    end;
    B1 := AcrossAxis(B[0]);
    B2 := AcrossAxis(B[1]);
    if B1 > B2 then
    begin
      Result := B1;
      B1 := B2;
      B2 := Result;
    end;
    if (A2 >= B1) and (B2 >= A1) then Exit(0);
    if A1 > B2 then
      Result := A1 - B2
    else
      Result := B1 - A2;
  end;

  function EndGap(const A, B: TPointDArray): Double;
  var
    D: Double;
  begin
    Result := Distance(A[0], B[0]);
    D := Distance(A[0], B[1]);
    if D < Result then Result := D;
    D := Distance(A[1], B[0]);
    if D < Result then Result := D;
    D := Distance(A[1], B[1]);
    if D < Result then Result := D;
  end;

  function MinOf(const A, B: Double): Double;
  begin
    if A < B then
      Result := A
    else
      Result := B;
  end;

  function MaxOf(const A, B: Double): Double;
  begin
    if A > B then
      Result := A
    else
      Result := B;
  end;

  function JoinPair(const A, B: TPointDArray): TPointDArray;
  var
    AxisMin, AxisMax: Double;
  begin
    AxisMin := MinOf(MinOf(AlongAxis(A[0]), AlongAxis(A[1])), MinOf(AlongAxis(B[0]), AlongAxis(B[1])));
    AxisMax := MaxOf(MaxOf(AlongAxis(A[0]), AlongAxis(A[1])), MaxOf(AlongAxis(B[0]), AlongAxis(B[1])));
    SetLength(Result, 2);
    if Horizontal then
    begin
      Result[0] := PointD(AxisMin, MidAcross(A));
      Result[1] := PointD(AxisMax, MidAcross(B));
    end
    else begin
      Result[0] := PointD(MidAcross(A), AxisMin);
      Result[1] := PointD(MidAcross(B), AxisMax);
    end;
  end;

  procedure AddKept(const S: TPointDArray);
  begin
    SetLength(Kept, Length(Kept) + 1);
    SetLength(Alive, Length(Alive) + 1);
    Kept[High(Kept)] := S;
    Alive[High(Alive)] := True;
  end;

var
  I, J: Integer;
  Joined: Boolean;
  Merged: TPointDArray;
  A1, A2, B1, B2: Double;
begin
  Result := nil;
  Kept := nil;
  Alive := nil;
  if (CrossVary < 0) or (MaxGap < 0) then Exit;
  for I := Low(Segments) to High(Segments) do
    if Length(Segments[I]) = 2 then AddKept(Copy(Segments[I]));
  repeat
    Joined := False;
    for I := Low(Kept) to High(Kept) do
    begin
      if not Alive[I] then Continue;
      for J := I + 1 to High(Kept) do
      begin
        if not Alive[J] then Continue;
        if Abs(MidAcross(Kept[I]) - MidAcross(Kept[J])) > CrossVary then Continue;
        if EndGap(Kept[I], Kept[J]) > MaxGap then Continue;
        Merged := JoinPair(Kept[I], Kept[J]);
        if Distance(Merged[0], Merged[1]) < MinLength then Continue;
        Alive[I] := False;
        Alive[J] := False;
        AddKept(Merged);
        Joined := True;
        Break;
      end;
      if Joined then Break;
    end;
  until not Joined;
  for I := Low(Kept) to High(Kept) do
  begin
    if not Alive[I] then Continue;
    for J := I + 1 to High(Kept) do
    begin
      if not Alive[J] then Continue;
      if BandGap(Kept[I], Kept[J]) > CrossVary then Continue;
      A1 := MinOf(AlongAxis(Kept[I][0]), AlongAxis(Kept[I][1]));
      A2 := MaxOf(AlongAxis(Kept[I][0]), AlongAxis(Kept[I][1]));
      B1 := MinOf(AlongAxis(Kept[J][0]), AlongAxis(Kept[J][1]));
      B2 := MaxOf(AlongAxis(Kept[J][0]), AlongAxis(Kept[J][1]));
      if (A1 >= B1) and (A2 <= B2) then
        Alive[I] := False
      else if (B1 >= A1) and (B2 <= A2) then
          Alive[J] := False
        else if (A2 >= B1) and (B2 >= A1) then
          begin
            Kept[I] := JoinPair(Kept[I], Kept[J]);
            Alive[J] := False;
          end;
      if not Alive[I] then Break;
    end;
  end;
  for I := Low(Kept) to High(Kept) do
    if Alive[I] then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Kept[I];
    end;
end;

function ExtractAxisLinesFromContour(const Contour: TPointDArray;
  const AngleVary, MinLength, MaxGap: Double; out Horizontals, Verticals: TSegmentDArray): Integer;
var
  FoundCount: Integer;

  function AxisAngle(const A, B: TPointD): Double;
  begin
    Result := Abs(SlopeToAngle(LineSlope(A, B)));
  end;

  function AxisKind(const A, B: TPointD): Integer;
  var
    Angle: Double;
  begin
    Angle := AxisAngle(A, B);
    if Angle <= AngleVary then Exit(1);
    if Abs(Angle - Pi / 2) <= AngleVary then Exit(2);
    Result := 0;
  end;

  procedure TakeAxisLine(const A, B: TPointD; const Axis: Integer);
  var
    Seg: TPointDArray;
  begin
    SetLength(Seg, 2);
    Seg[0] := A;
    Seg[1] := B;
    if Axis = 1 then
    begin
      SetLength(Horizontals, Length(Horizontals) + 1);
      Horizontals[High(Horizontals)] := Seg;
    end
    else begin
      SetLength(Verticals, Length(Verticals) + 1);
      Verticals[High(Verticals)] := Seg;
    end;
    Inc(FoundCount);
  end;

var
  I, J, Axis: Integer;
  Support: TPointD;
  HasSupport: Boolean;
begin
  Horizontals := nil;
  Verticals := nil;
  FoundCount := 0;
  Result := 0;
  if (AngleVary < 0) or (MinLength <= 0) or (MaxGap < 0) then Exit;
  HasSupport := False;
  Support := PointD(0, 0);
  I := Low(Contour);
  while I <= High(Contour) do
  begin
    if not HasSupport then
    begin
      Support := Contour[I];
      HasSupport := True;
      Inc(I);
      Continue;
    end;
    if Distance(Support, Contour[I]) < MinLength then
    begin
      Inc(I);
      Continue;
    end;
    Axis := AxisKind(Support, Contour[I]);
    if Axis > 0 then
      TakeAxisLine(Support, Contour[I], Axis)
    else
      for J := I to High(Contour) do
      begin
        if Distance(Contour[I], Contour[J]) > MaxGap then Break;
        if Distance(Support, Contour[J]) < MinLength then Continue;
        Axis := AxisKind(Support, Contour[J]);
        if Axis > 0 then
        begin
          TakeAxisLine(Support, Contour[J], Axis);
          I := J;
          Break;
        end;
      end;
    Support := Contour[I];
    Inc(I);
  end;
  Result := FoundCount;
end;

function RotatedBoundingSize(const SrcW, SrcH: Integer; const Angle: Double;
  out W, H: Integer): Boolean;
var
  PolX, PolY, CosA, SinA: Double;
begin
  W := 0;
  H := 0;
  Result := (SrcW > 0) and (SrcH > 0) and not IsNan(Angle) and not IsInfinite(Angle);
  if not Result then Exit;
  PolX := SrcW / 2;
  PolY := SrcH / 2;
  CosA := Abs(Cos(Angle));
  SinA := Abs(Sin(Angle));
  W := Round((PolX * CosA + PolY * SinA) * 2);
  H := Round((PolX * SinA + PolY * CosA) * 2);
end;

function InverseRotateMapPoint(const Target, SourceCenter, TargetCenter: TPointI;
  const Quadrant: TQuadrantKind; const Angle, MinAngle: Double): TPointI;
const
  SignX: array[TQuadrantKind] of Double = (1, -1, 1, -1);
  SignSX: array[TQuadrantKind] of Double = (1, 1, -1, -1);
  SignSY: array[TQuadrantKind] of Double = (-1, 1, 1, -1);
var
  Tx, Ty, Shared, Sx, Sy: Double;
begin
  if Abs(Angle) < MinAngle then
  begin
    Result.X := Target.X - TargetCenter.X + SourceCenter.X;
    Result.Y := Target.Y - TargetCenter.Y + SourceCenter.Y;
    Exit;
  end;
  Tx := SignX[Quadrant] * (Target.X - TargetCenter.X);
  Ty := TargetCenter.Y - Target.Y;
  Shared := Tx - Ty * (Cos(Angle) / Sin(Angle));
  Sx := SignSX[Quadrant] * (Ty / Sin(Angle) + Shared * Cos(Angle));
  Sy := SignSY[Quadrant] * (Shared * Sin(Angle));
  Result.X := Round(Sx + SourceCenter.X);
  Result.Y := Round(SourceCenter.Y - Sy);
end;

function ZoneGridSize(const SrcW, SrcH, ZoneW, ZoneH: Integer; out Cols, Rows: Integer): Boolean;
begin
  Cols := 0;
  Rows := 0;
  Result := (SrcW > 0) and (SrcH > 0) and (ZoneW > 0) and (ZoneH > 0);
  if not Result then Exit;
  if ZoneW > 0 then
  begin
    Cols := SrcW div ZoneW;
    if SrcW mod ZoneW > 0 then Inc(Cols);
  end;
  if ZoneH > 0 then
  begin
    Rows := SrcH div ZoneH;
    if SrcH mod ZoneH > 0 then Inc(Rows);
  end;
end;

function ClosePolygon(const Polygon: TPointDArray): TPointDArray;
var
  Last: Integer;
begin
  Last := High(Polygon);
  if Last < 0 then Exit(nil);
  Result := Copy(Polygon);
  if (Result[0].X <> Result[Last].X) or (Result[0].Y <> Result[Last].Y) then
  begin
    SetLength(Result, Last + 2);
    Result[Last + 1] := Result[0];
  end;
end;

function ReversePolyline(const Points: TPointDArray): TPointDArray;
var
  I, Last: Integer;
begin
  Last := High(Points);
  Result := Copy(Points);
  for I := 0 to Last do Result[Last - I] := Points[I];
end;

function PolygonSignedArea(const Polygon: TPointDArray): Double;
var
  I, K, N: Integer;
  S: Double;
begin
  N := Length(Polygon);
  if N < 3 then Exit(0);
  S := 0;
  for I := 0 to N - 1 do
  begin
    K := (I + 1) mod N;
    S := S + (Polygon[I].X * Polygon[K].Y) - (Polygon[K].X * Polygon[I].Y);
  end;
  Result := S * 0.5;
end;

function PolygonArea(const Polygon: TPointDArray): Double;
begin
  Result := Abs(PolygonSignedArea(Polygon));
end;

function MeanPoint(const Points: TPointDArray): TPointD;
var
  I: Integer;
  X, Y: Double;
begin
  Result := PointD(0, 0);
  if Length(Points) = 0 then Exit;
  X := 0;
  Y := 0;
  for I := Low(Points) to High(Points) do
  begin
    X := X + Points[I].X;
    Y := Y + Points[I].Y;
  end;
  Result := PointD(X / Length(Points), Y / Length(Points));
end;

function PolygonCentroid(const Polygon: TPointDArray): TPointD;
var
  I, K, N: Integer;
  Area, Factor, X, Y: Double;
begin
  N := Length(Polygon);
  if N < 3 then Exit(MeanPoint(Polygon));
  Area := 0;
  X := 0;
  Y := 0;
  for I := 0 to N - 1 do
  begin
    K := (I + 1) mod N;
    Factor := (Polygon[I].X * Polygon[K].Y) - (Polygon[K].X * Polygon[I].Y);
    X := X + (Polygon[I].X + Polygon[K].X) * Factor;
    Y := Y + (Polygon[I].Y + Polygon[K].Y) * Factor;
    Area := Area + Factor;
  end;
  Area := Area * 0.5;
  if Area = 0 then Exit(MeanPoint(Polygon));
  Result := PointD(X / (Area * 6), Y / (Area * 6));
end;

function HullPointLess(const A, B: TPointD): Boolean; inline;
begin
  if A.X < B.X then Exit(True);
  if A.X > B.X then Exit(False);
  Result := A.Y < B.Y;
end;

procedure HullSort(var Points: TPointDArray; Min, Max: Integer);
var
  I, J: Integer;
  Pivot, Swap: TPointD;
begin
  while Min < Max do
  begin
    I := Min;
    J := Max;
    Pivot := Points[Min + ((Max - Min) shr 1)];
    repeat
      while HullPointLess(Points[I], Pivot) do Inc(I);
      while HullPointLess(Pivot, Points[J]) do Dec(J);
      if I <= J then
      begin
        if I < J then
        begin
          Swap := Points[I];
          Points[I] := Points[J];
          Points[J] := Swap;
        end;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if J - Min < Max - I then
    begin
      if Min < J then HullSort(Points, Min, J);
      Min := I;
    end
    else begin
      if I < Max then HullSort(Points, I, Max);
      Max := J;
    end;
  end;
end;

function ConvexHull(const Points: TPointDArray; const Close: Boolean): TPointDArray;
var
  Sorted: TPointDArray;
  I, N, K, L: Integer;

  function Turn(const O, P, Q: TPointD): Double; inline;
  begin
    Result := (P.X - O.X) * (Q.Y - O.Y) - (P.Y - O.Y) * (Q.X - O.X);
  end;

begin
  N := Length(Points);
  if N < 4 then Exit(Copy(Points));
  Sorted := Copy(Points);
  HullSort(Sorted, Low(Sorted), High(Sorted));
  SetLength(Result, N * 2);
  K := 0;
  for I := 0 to N - 1 do
  begin
    while (K >= 2) and (Turn(Result[K - 2], Result[K - 1], Sorted[I]) <= 0) do Dec(K);
    Result[K] := Sorted[I];
    Inc(K);
  end;
  L := K + 1;
  for I := N - 2 downto 0 do
  begin
    while (K >= L) and (Turn(Result[K - 2], Result[K - 1], Sorted[I]) <= 0) do Dec(K);
    Result[K] := Sorted[I];
    Inc(K);
  end;
  if Close then
  begin
    SetLength(Result, K);
    Result[K - 1] := Result[0];
  end
  else
    SetLength(Result, K - 1);
end;

function Distance(const A, B: TPointD): Double;
begin
  if A.X = B.X then Exit(Abs(A.Y - B.Y));
  if A.Y = B.Y then Exit(Abs(A.X - B.X));
  Result := Sqrt(Sqr(A.X - B.X) + Sqr(A.Y - B.Y));
end;

function LineSlope(const A, B: TPointD): Double;
begin
  if A.X = B.X then Exit(Infinity);
  Result := (B.Y - A.Y) / (B.X - A.X);
end;

function SanitizeSlope(const A, B: TPointD; const Epsilon: Double): Double;
begin
  if Abs(B.X - A.X) <= Epsilon then Exit(Infinity);
  if Abs(B.Y - A.Y) <= Epsilon then Exit(0);
  Result := (B.Y - A.Y) / (B.X - A.X);
end;

function SlopeToAngle(const Slope: Double): Double;
begin
  if IsInfinite(Slope) then Exit(Pi / 2);
  Result := ArcTan(Slope);
end;

function AngleToSlope(const Angle: Double): Double;
var
  Turns: Double;
begin
  Turns := Angle / Pi;
  if Abs(Turns - Round(Turns)) <= GeometryEpsilon then Exit(0);
  Turns := Angle / (Pi / 2);
  if Abs(Turns - Round(Turns)) <= GeometryEpsilon then Exit(Infinity);
  Result := Tan(Angle);
end;

function LineYIntercept(const P: TPointD; const Slope: Double): Double;
begin
  Result := P.Y - Slope * P.X;
end;

function WrapAngle360(const Angle: Double): Double;
begin
  Result := Angle - Floor(Angle / TwoPi) * TwoPi;
end;

function WrapAngle180(const Angle: Double): Double;
begin
  Result := Angle - Floor(Angle / Pi) * Pi;
end;

function DirectionAngle(const A, B: TPointD): Double;
begin
  Result := WrapAngle360(ArcTan2(B.Y - A.Y, B.X - A.X));
end;

function IncludedAngle(const P1, Vertex, P2: TPointD): Double;
var
  A, B, C, Cosine: Double;
begin
  A := Distance(Vertex, P1);
  B := Distance(Vertex, P2);
  if (A < GeometryEpsilon) or (B < GeometryEpsilon) then Exit(0);
  C := Distance(P1, P2);
  Cosine := EnsureRange((Sqr(A) + Sqr(B) - Sqr(C)) / (2 * A * B), -1, 1);
  Result := ArcCos(Cosine);
end;

function AngularDifference(const A, B: Double): Double;
begin
  Result := WrapAngle360(A - B);
  if Result > Pi then Result := TwoPi - Result;
end;

function CircularMean(const Angles: TArray<Double>): Double;
var
  I: Integer;
  S, C: Double;
begin
  S := 0;
  C := 0;
  for I := Low(Angles) to High(Angles) do
  begin
    S := S + Sin(Angles[I]);
    C := C + Cos(Angles[I]);
  end;
  Result := WrapAngle360(ArcTan2(S, C));
end;

function MinAreaRectAngle(const Points: TPointDArray): Double;
var
  Longer, Shorter: Double;
begin
  Result := MinAreaRectAngle(Points, Longer, Shorter);
end;

function MinAreaRectAngle(const Points: TPointDArray; out Long, Short: Double): Double;
var
  Hull: TPointDArray;
  I, J, N, V: Integer;
  Ux, Uy, Len, Pr, Pe: Double;
  MinPr, MaxPr, MinPe, MaxPe: Double;
  SpanAlong, SpanAcross, Area, BestArea, Angle: Double;
begin
  Result := -1;
  Long := 0;
  Short := 0;
  Hull := ConvexHull(Points);
  N := Length(Hull);
  if N < 2 then Exit;
  BestArea := -1;
  Angle := 0;
  for I := 0 to N - 1 do
  begin
    J := (I + 1) mod N;
    Ux := Hull[J].X - Hull[I].X;
    Uy := Hull[J].Y - Hull[I].Y;
    Len := Sqrt(Ux * Ux + Uy * Uy);
    if Len < 1E-12 then Continue;
    Ux := Ux / Len;
    Uy := Uy / Len;
    MinPr := 0;
    MaxPr := 0;
    MinPe := 0;
    MaxPe := 0;
    for V := 0 to N - 1 do
    begin
      Pr := (Hull[V].X - Hull[I].X) * Ux + (Hull[V].Y - Hull[I].Y) * Uy;
      Pe := -(Hull[V].X - Hull[I].X) * Uy + (Hull[V].Y - Hull[I].Y) * Ux;
      if Pr < MinPr then MinPr := Pr;
      if Pr > MaxPr then MaxPr := Pr;
      if Pe < MinPe then MinPe := Pe;
      if Pe > MaxPe then MaxPe := Pe;
    end;
    SpanAlong := MaxPr - MinPr;
    SpanAcross := MaxPe - MinPe;
    Area := SpanAlong * SpanAcross;
    if (BestArea < 0) or (Area < BestArea) then
    begin
      BestArea := Area;
      if SpanAlong >= SpanAcross then
      begin
        Long := SpanAlong;
        Short := SpanAcross;
      end
      else begin
        Long := SpanAcross;
        Short := SpanAlong;
      end;
      if SpanAlong >= SpanAcross then
        Angle := ArcTan2(Uy, Ux)
      else
        Angle := ArcTan2(Ux, -Uy);
    end;
  end;
  if BestArea < 0 then Exit;
  Result := WrapAngle180(Angle);
end;

function PointAtAngleDistance(const P: TPointD; const Angle, Dist: Double): TPointD;
begin
  if IsNan(Angle) or IsInfinite(Angle) or IsNan(Dist) or IsInfinite(Dist) then
  begin
    Result := PointD(NaN, NaN);
    Exit;
  end;
  Result := PointD(P.X + Dist * Cos(Angle), P.Y + Dist * Sin(Angle));
end;

function ToPolar(const Center, Point: TPointD): TPolarD;
begin
  Result.Angle := DirectionAngle(Center, Point);
  Result.Distance := Distance(Center, Point);
end;

function QuadrantOf(const Center, Point: TPointD): TQuadrantKind;
begin
  if Point.X < Center.X then
    if Point.Y < Center.Y then
      Result := qkLeftTop
    else
      Result := qkLeftBottom
  else
    if Point.Y < Center.Y then
      Result := qkRightTop
    else
      Result := qkRightBottom;
end;

function CounterClockwiseAngle(const Quadrant: TQuadrantKind; const Angle: Double): Double;
begin
  case Quadrant of
    qkLeftTop, qkLeftBottom: Result := Pi + Angle;
    qkRightBottom: Result := TwoPi + Angle;
  else
    Result := Angle;
  end;
end;

function PointSideOfLine(const P, A, B: TPointD): Integer;
begin
  Result := Sign((B.X - A.X) * (P.Y - A.Y) - (B.Y - A.Y) * (P.X - A.X));
end;

function PointOnSegment(const P, A, B: TPointD; const Epsilon: Double): Boolean;
begin
  if Abs((B.X - A.X) * (P.Y - A.Y) - (B.Y - A.Y) * (P.X - A.X)) > Epsilon then Exit(False);
  Result := (P.X >= Min(A.X, B.X) - Epsilon) and (P.X <= Max(A.X, B.X) + Epsilon) and
    (P.Y >= Min(A.Y, B.Y) - Epsilon) and (P.Y <= Max(A.Y, B.Y) + Epsilon);
end;

function PointsOnSegment(const Points: TPointDArray; const A, B: TPointD;
  const Epsilon: Double): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Points) do
    if not PointOnSegment(Points[I], A, B, Epsilon) then Exit(False);
  Result := True;
end;

function SegmentsCollinear(const A, B, C, D: TPointD; const Epsilon: Double): Boolean;
begin
  Result := (Abs((B.X - A.X) * (C.Y - A.Y) - (B.Y - A.Y) * (C.X - A.X)) <= Epsilon) and
    (Abs((B.X - A.X) * (D.Y - A.Y) - (B.Y - A.Y) * (D.X - A.X)) <= Epsilon);
end;

function CollinearOverlapLength(const A, B, C, D: TPointD): Double;
var
  DX, DY, L2, TC, TD, OverlapMin, OverlapMax: Double;
begin
  Result := 0;
  if not SegmentsCollinear(A, B, C, D) then Exit;
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  L2 := DX * DX + DY * DY;
  if L2 < GeometryEpsilon then Exit;
  TC := ((C.X - A.X) * DX + (C.Y - A.Y) * DY) / L2;
  TD := ((D.X - A.X) * DX + (D.Y - A.Y) * DY) / L2;
  OverlapMin := Max(0.0, Min(TC, TD));
  OverlapMax := Min(1.0, Max(TC, TD));
  if OverlapMax < OverlapMin then Exit;
  Result := (OverlapMax - OverlapMin) * Sqrt(L2);
end;

function RotatePoints(const Points: TPointDArray; const Angle: Double; const Center: TPointD): TPointDArray;
var
  I: Integer;
  S, C, DX, DY: Double;
begin
  S := Sin(Angle);
  C := Cos(Angle);
  SetLength(Result, Length(Points));
  for I := Low(Points) to High(Points) do
  begin
    DX := Points[I].X - Center.X;
    DY := Points[I].Y - Center.Y;
    Result[I] := PointD(Center.X + DX * C - DY * S, Center.Y + DX * S + DY * C);
  end;
end;

function ShearPoints(const Points: TPointDArray; const XSkew, YSkew: Double): TPointDArray;
var
  I: Integer;
  TX, TY: Double;
begin
  TX := Tan(XSkew);
  TY := Tan(YSkew);
  Result := Copy(Points);
  for I := Low(Points) to High(Points) do
    Result[I] := PointD(Points[I].X + TX * Points[I].Y, Points[I].Y + TY * Points[I].X);
end;

function TurnPointsAboutMeanPoint(const Points: TPointDArray; const Angle: Double): TPointDArray;
begin
  if Length(Points) = 0 then Exit(nil);
  Result := RotatePoints(Points, Angle, MeanPoint(Points));
end;

function ScalePointsAboutMeanPoint(const Points: TPointDArray; const Factor: Double): TPointDArray;
var
  I: Integer;
  Base: TPointD;
begin
  if Length(Points) = 0 then Exit(nil);
  Base := MeanPoint(Points);
  SetLength(Result, Length(Points));
  for I := Low(Points) to High(Points) do
    Result[I] := PointD(Base.X + (Points[I].X - Base.X) * Factor,
                        Base.Y + (Points[I].Y - Base.Y) * Factor);
end;

function BoundingBox(const Points: TPointDArray): TRectD;
var
  I: Integer;
begin
  if Length(Points) = 0 then Exit(RectD(0, 0, 0, 0));
  Result := RectD(Points[0].X, Points[0].Y, Points[0].X, Points[0].Y);
  for I := 1 to High(Points) do
  begin
    if Points[I].X < Result.Left then Result.Left := Points[I].X;
    if Points[I].X > Result.Right then Result.Right := Points[I].X;
    if Points[I].Y < Result.Top then Result.Top := Points[I].Y;
    if Points[I].Y > Result.Bottom then Result.Bottom := Points[I].Y;
  end;
end;

function NearestPoint(const FromPoint: TPointD; const Points: TPointDArray; out Index: Integer): Boolean;
var
  I: Integer;
  Best, D: Double;
begin
  Index := -1;
  if Length(Points) = 0 then Exit(False);
  Best := MaxDouble;
  for I := Low(Points) to High(Points) do
  begin
    D := Distance(FromPoint, Points[I]);
    if D < Best then
    begin
      Best := D;
      Index := I;
    end;
  end;
  Result := Index >= 0;
end;

function NormalizeRect(const R: TRectD): TRectD;
begin
  Result.Left := Min(R.Left, R.Right);
  Result.Right := Max(R.Left, R.Right);
  Result.Top := Min(R.Top, R.Bottom);
  Result.Bottom := Max(R.Top, R.Bottom);
end;

function RectWidth(const R: TRectD): Double;
begin
  Result := R.Right - R.Left;
end;

function RectHeight(const R: TRectD): Double;
begin
  Result := R.Bottom - R.Top;
end;

function RectArea(const R: TRectD): Double;
begin
  Result := Max(0, R.Right - R.Left) * Max(0, R.Bottom - R.Top);
end;

function RectIsEmpty(const R: TRectD): Boolean;
begin
  Result := (R.Right <= R.Left) or (R.Bottom <= R.Top);
end;

function RectCenter(const R: TRectD): TPointD;
begin
  Result := PointD((R.Left + R.Right) / 2, (R.Top + R.Bottom) / 2);
end;

function RectToPolygon(const R: TRectD): TPointDArray;
begin
  Result := [PointD(R.Left, R.Top), PointD(R.Right, R.Top), PointD(R.Right, R.Bottom), PointD(R.Left, R.Bottom)];
end;

function RectsIntersect(const A, B: TRectD): Boolean;
begin
  Result := (A.Left < B.Right) and (B.Left < A.Right) and (A.Top < B.Bottom) and (B.Top < A.Bottom);
end;

function RectIntersection(const A, B: TRectD; out R: TRectD): Boolean;
begin
  R.Left := Max(A.Left, B.Left);
  R.Top := Max(A.Top, B.Top);
  R.Right := Min(A.Right, B.Right);
  R.Bottom := Min(A.Bottom, B.Bottom);
  Result := (R.Right > R.Left) and (R.Bottom > R.Top);
  if not Result then R := RectD(0, 0, 0, 0);
end;

function RectUnion(const A, B: TRectD): TRectD;
begin
  Result := RectD(Min(A.Left, B.Left), Min(A.Top, B.Top), Max(A.Right, B.Right), Max(A.Bottom, B.Bottom));
end;

function RectUnion(const Rects: TRectDArray): TRectD;
var
  I: Integer;
begin
  if Length(Rects) = 0 then Exit(RectD(0, 0, 0, 0));
  Result := Rects[0];
  for I := 1 to High(Rects) do
    Result := RectUnion(Result, Rects[I]);
end;

function RectIoU(const A, B: TRectD): Double;
var
  R: TRectD;
  Inter, Union: Double;
begin
  if not RectIntersection(A, B, R) then Exit(0);
  Inter := RectArea(R);
  Union := RectArea(A) + RectArea(B) - Inter;
  if Union <= GeometryEpsilon then Exit(0);
  Result := Inter / Union;
end;

function RectGap(const A, B: TRectD): Double;
var
  DX, DY: Double;
begin
  DX := Max(0, Max(A.Left - B.Right, B.Left - A.Right));
  DY := Max(0, Max(A.Top - B.Bottom, B.Top - A.Bottom));
  Result := Sqrt(DX * DX + DY * DY);
end;

function RectsApproxEqual(const A, B: TRectD; const Tolerance: Double): Boolean;
begin
  Result := (Abs(A.Left - B.Left) <= Tolerance) and (Abs(A.Top - B.Top) <= Tolerance) and
    (Abs(A.Right - B.Right) <= Tolerance) and (Abs(A.Bottom - B.Bottom) <= Tolerance);
end;

function RectsCloserThan(const A, B: TRectD; const MaxGap: Double): Boolean;
begin
  Result := RectGap(A, B) <= MaxGap;
end;

function MergeNearbyRects(const Rects: TRectDArray; const MaxGap: Double): TRectDArray;
var
  Work: TRectDArray;
  I, J, N: Integer;
  Merged: Boolean;
begin
  Work := Copy(Rects);
  N := Length(Work);
  Merged := True;
  while Merged do
  begin
    Merged := False;
    I := 0;
    while I < N do
    begin
      J := I + 1;
      while J < N do
        if RectGap(Work[I], Work[J]) <= MaxGap then
        begin
          Work[I] := RectUnion(Work[I], Work[J]);
          Work[J] := Work[N - 1];
          Dec(N);
          Merged := True;
        end
        else
          Inc(J);
      Inc(I);
    end;
  end;
  SetLength(Work, N);
  Result := Work;
end;

function RotateRectCorners(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TPointDArray;
var
  Corners: TPointDArray;
  I: Integer;
  Ang, Dist: Double;
begin
  SetLength(Corners, 4);
  Corners[0] := PointD(R.Left, R.Top);
  Corners[1] := PointD(R.Right, R.Top);
  Corners[2] := PointD(R.Right, R.Bottom);
  Corners[3] := PointD(R.Left, R.Bottom);
  SetLength(Result, 4);
  for I := 0 to 3 do
  begin
    Ang := DirectionAngle(SourceCenter, Corners[I]);
    Dist := Distance(SourceCenter, Corners[I]);
    Result[I] := PointAtAngleDistance(TargetCenter, Ang - Skew, Dist);
  end;
end;

function RotateRectCorners(const R: TRectD; const Skew: Double): TPointDArray;
var
  Center: TPointD;
begin
  Center := RectCenter(R);
  Result := RotateRectCorners(R, Skew, Center, Center);
end;

function RotatedRectBounds(const R: TRectD; const Skew: Double): TRectD;
begin
  Result := BoundingBox(RotateRectCorners(R, Skew));
end;

function RotatedRectBounds(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TRectD;
begin
  Result := BoundingBox(RotateRectCorners(R, Skew, SourceCenter, TargetCenter));
end;

function ClassifyRectOverlap(const First, Second: TRectI): TRectOverlapKind;
var
  A, B: TRectI;
  AA, AB, AD, BA, BB, BD: TPointI;
begin
  A := First;
  A.NormalizeRect;
  B := Second;
  B.NormalizeRect;
  if (A.Left = B.Left) and (A.Top = B.Top) and (A.Right = B.Right) and (A.Bottom = B.Bottom) then
    Exit(okSame);
  AA := Point(A.Left, A.Top);
  AB := Point(A.Right, A.Top);
  AD := Point(A.Left, A.Bottom);
  BA := Point(B.Left, B.Top);
  BB := Point(B.Right, B.Top);
  BD := Point(B.Left, B.Bottom);
  if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
    Result := okInside
  else if (BA.X = AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
      Result := okInsideTL
    else if (BA.X = AA.X) and (BB.X < AB.X) and (BD.Y = AD.Y) and (BA.Y > AA.Y) then
        Result := okInsideBL
      else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
          Result := okInsideTR
        else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y = AD.Y) then
            Result := okInsideBR
          else if (BA.X = AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
              Result := okInsideL
            else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
                Result := okInsideT
              else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
                  Result := okInsideR
                else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y = AD.Y) then
                    Result := okInsideB
                  else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y = AD.Y) then
                      Result := okInsideV
                    else if (BA.X = AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
                        Result := okInsideH
                      else if (BA.X = AA.X) and (BB.X = AB.X) and (BA.Y = AA.Y) and
                        (BD.Y < AD.Y) then
                            Result := okInsideTLR
                        else if (BA.X = AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and
                          (BD.Y = AD.Y) then
                              Result := okInsideLTB
                          else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y = AA.Y) and
                            (BD.Y = AD.Y) then
                                Result := okInsideRTB
                            else if (BA.X = AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and
                              (BD.Y = AD.Y) then
                                  Result := okInsideBLR
                              else if (BA.X < AA.X) and (BB.X > AB.X) and (BA.Y < AA.Y) and
                                (BD.Y > AD.Y) then
                                    Result := okOutside
                                else if BB.X = AA.X then
                                    Result := okOutsideL
                                  else if BD.Y = AA.Y then
                                      Result := okOutsideL
                                    else if BA.X = AB.X then
                                        Result := okOutsideT
                                      else if BA.Y = AD.Y then
                                          Result := okOutsideB
                                        else if (BA.X < AA.X) and (BB.X > AA.X) and (BB.X < AB.X) and
                                          (BD.Y > AA.Y) and (BD.Y < AD.Y) and (BA.Y < AA.Y) then
                                              Result := okTL
                                          else if (BA.X > AA.X) and (BA.X < AB.X) and (BB.X > AB.X) and
                                            (BD.Y > AA.Y) and (BD.Y < AD.Y) and (BA.Y < AA.Y) then
                                                Result := okTR
                                            else if (BA.X > AA.X) and (BA.X < AB.X) and
                                              (BB.X > AB.X) and (BA.Y > AA.Y) and (BA.Y < AD.Y) and
                                              (BD.Y > AD.Y) then
                                                  Result := okBR
                                              else if (BB.X > AA.X) and (BB.X < AB.X) and (BA.X < AA.X) and
                                                (BA.Y > AA.Y) and (BA.Y < AD.Y) and (BD.Y > AD.Y) then
                                                    Result := okBL
                                                else if (BA.X < AA.X) and (BB.X > AB.X) and
                                                  (BA.Y >= AA.Y) and (BD.Y <= AD.Y) then
                                                      Result := okH
                                                  else if (BA.X >= AA.X) and (BB.X <= AB.X) and
                                                    (BA.Y < AA.Y) and (BD.Y > AD.Y) then
                                                        Result := okV
                                                    else if (BB.X > AA.X) and (BB.X < AB.X) and
                                                      (BA.Y > AA.Y) and (BD.Y < AD.Y) and
                                                      (BA.X < AA.X) then
                                                          Result := okInnerL
                                                      else if (BA.X > AA.X) and (BB.X < AB.X) and
                                                        (BD.Y > AA.Y) and (BD.Y < AD.Y) and
                                                        (BA.Y < AA.Y) then
                                                            Result := okInnerT
                                                        else if (BA.X > AA.X) and (BA.X < AB.X) and
                                                          (BA.Y > AA.Y) and (BD.Y < AD.Y) and
                                                          (BB.X > AB.X) then
                                                              Result := okInnerR
                                                          else if (BA.X > AA.X) and (BB.X < AB.X) and
                                                            (BA.Y > AA.Y) and (BA.Y < AD.Y) and
                                                            (BD.Y > AD.Y) then
                                                                Result := okInnerB
                                                            else if (BA.Y < AA.Y) and (BD.Y > AD.Y) and
                                                              (BB.X > AA.X) and (BB.X < AB.X) and
                                                              (BA.X < AA.X) then
                                                                  Result := okOuterL
                                                              else if (BA.X < AA.X) and
                                                                (BB.X > AB.X) and (BD.Y > AA.Y) and
                                                                (BD.Y < AD.Y) and (BA.Y < AA.Y) then
                                                                    Result := okOuterT
                                                                else if (BA.Y < AA.Y) and (BD.Y > AD.Y) and
                                                                  (BA.X > AA.X) and (BA.X < AB.X) and
                                                                  (BB.X > AB.X) then
                                                                      Result := okOuterR
                                                                  else if (BA.X < AA.X) and (BB.X > AB.X) and
                                                                    (BA.Y > AA.Y) and (BA.Y < AD.Y) and
                                                                    (BD.Y > AD.Y) then
                                                                        Result := okOuterB
                                                                    else
                                                                      Result := okNone;
end;

function ClassifyRectPosition(const First, Second: TRectI): TRectPositionKind;
var
  A, B: TRectI;
  AA, AB, AD, BA, BB, BD: TPointI;
begin
  A := First;
  A.NormalizeRect;
  B := Second;
  B.NormalizeRect;
  AA := Point(A.Left, A.Top);
  AB := Point(A.Right, A.Top);
  AD := Point(A.Left, A.Bottom);
  BA := Point(B.Left, B.Top);
  BB := Point(B.Right, B.Top);
  BD := Point(B.Left, B.Bottom);
  if (BA.X >= AA.X) and (BB.X <= AB.X) then
  begin
    if AD.Y < BA.Y then
      Result := pkB
    else if AA.Y > BD.Y then
        Result := pkT
      else
        Result := pkNone;
  end
  else if (BA.Y >= AA.Y) and (BD.Y <= AD.Y) then
    begin
      if AB.X < BA.X then
        Result := pkR
      else if AA.X > BB.X then
          Result := pkL
        else
          Result := pkNone;
    end
    else if (AA.X >= BA.X) and (AB.X <= BB.X) then
      begin
        if AD.Y < BA.Y then
          Result := pkBLR
        else if AA.Y > BD.Y then
            Result := pkTLR
          else
            Result := pkNone;
      end
      else if (AA.X >= BA.X) and (AA.X <= BB.X) then
        begin
          if AD.Y < BA.Y then
            Result := pkBL
          else if AA.Y > BD.Y then
              Result := pkTL
            else
              Result := pkNone;
        end
        else if (AB.X >= BA.X) and (AB.X <= BB.X) then
          begin
            if AD.Y < BA.Y then
              Result := pkBR
            else if AA.Y > BD.Y then
                Result := pkTR
              else
                Result := pkNone;
          end
          else if (AA.Y >= BA.Y) and (AD.Y <= BD.Y) then
            begin
              if AB.X < BA.X then
                Result := pkRTB
              else if AA.X > BB.X then
                  Result := pkLTB
                else
                  Result := pkNone;
            end
            else if (AA.Y >= BA.Y) and (AA.Y <= BD.Y) then
              begin
                if AB.X < BA.X then
                  Result := pkRT
                else if AA.X > BB.X then
                    Result := pkLT
                  else
                    Result := pkNone;
              end
              else if (AD.Y >= BA.Y) and (AD.Y <= BD.Y) then
                begin
                  if AB.X < BA.X then
                    Result := pkRB
                  else if AA.X > BB.X then
                      Result := pkLB
                    else
                      Result := pkNone;
                end
                else if (AA.X > BB.X) and (AA.Y > BD.Y) then
                    Result := pkTTLL
                  else if (AB.X < BA.X) and (AA.Y > BD.Y) then
                      Result := pkTTRR
                    else if (AB.X < BA.X) and (AD.Y < BA.Y) then
                        Result := pkBBRR
                      else if (AA.X > BB.X) and (AD.Y < BA.Y) then
                          Result := pkBBLL
                        else
                          Result := pkNone;
end;

function RectsWithinMargin(const A, B: TRectI; const XMargin, YMargin: Integer): Boolean;
var
  P, Q: TRectI;
begin
  P := A;
  P.NormalizeRect;
  Q := B;
  Q.NormalizeRect;
  Dec(P.Left, XMargin); Dec(P.Top, YMargin);
  Inc(P.Right, XMargin); Inc(P.Bottom, YMargin);
  Dec(Q.Left, XMargin); Dec(Q.Top, YMargin);
  Inc(Q.Right, XMargin); Inc(Q.Bottom, YMargin);
  Result := (P.Left < Q.Right) and (Q.Left < P.Right) and (P.Top < Q.Bottom) and (Q.Top < P.Bottom);
end;

function LargestTileSizeForCount(const SrcW, SrcH, Count: Integer;
  out TileW, TileH: Integer): Boolean;
var
  W, H, Area, BestArea: Integer;
begin
  TileW := 0;
  TileH := 0;
  BestArea := 0;
  if (SrcW <= 0) or (SrcH <= 0) or (Count <= 0) then Exit(False);
  for W := SrcW downto 1 do
    for H := SrcH downto 1 do
      if (SrcW div W) * (SrcH div H) >= Count then
      begin
        Area := W * H;
        if Area > BestArea then
        begin
          BestArea := Area;
          TileW := W;
          TileH := H;
        end;
      end;
  Result := BestArea > 0;
end;

function RectRelativeAlignment(const First, Second: TRectI): TRectAlignmentKind;
var
  A, B: TRectI;
  IsAbove, IsBelow, IsLeft, IsRight: Boolean;
begin
  A := First;
  A.NormalizeRect;
  B := Second;
  B.NormalizeRect;
  IsAbove := B.Bottom <= A.Top;
  IsBelow := B.Top >= A.Bottom;
  IsLeft := B.Right <= A.Left;
  IsRight := B.Left >= A.Right;
  if IsAbove and IsLeft then Exit(akTL);
  if IsAbove and IsRight then Exit(akTR);
  if IsBelow and IsLeft then Exit(akLB);
  if IsBelow and IsRight then Exit(akRB);
  if IsAbove then Exit(akT);
  if IsBelow then Exit(akB);
  if IsLeft then Exit(akL);
  if IsRight then Exit(akR);
  Result := akNone;
end;

end.
