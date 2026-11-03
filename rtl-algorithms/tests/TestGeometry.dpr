program TestGeometry;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Math,
  Types,
  CrossVision.Geometry.Types,
  CrossVision.Geometry;

var
  Passed: Integer = 0;
  Failed: Integer = 0;

procedure Check(const Cond: Boolean; const Name: string);
begin
  if Cond then
  begin
    Inc(Passed);
    Writeln('  ok   ', Name);
  end
  else begin
    Inc(Failed);
    Writeln('  FAIL ', Name);
  end;
end;

procedure CheckClose(const Got, Expected: Double; const Name: string);
begin
  Check(Abs(Got - Expected) < 1e-6, Format('%s (got %.6f, expected %.6f)', [Name, Got, Expected]));
end;

function RayEnd(const Angle: Double; const W, H: Integer): TPointD;
var
  L: TSegmentDArray;
begin
  Result := PointD(-999, -999);
  L := BuildRadialScanLines(PointD((W - 1) / 2, (H - 1) / 2), W, H, Angle, Angle + 0.1, Pi / 2);
  if (Length(L) = 1) and (Length(L[0]) = 2) then Result := L[0][1];
end;

function ReferenceCases(const R1, R2: TRect): TRectAlignmentKind;
begin
  if (R2.Bottom <= R1.Top) and (R2.Right <= R1.Left) then Exit(akTL);
  if (R2.Bottom <= R1.Top) and (R2.Left >= R1.Right) then Exit(akTR);
  if (R2.Top >= R1.Bottom) and (R2.Right <= R1.Left) then Exit(akLB);
  if (R2.Top >= R1.Bottom) and (R2.Left >= R1.Right) then Exit(akRB);
  if R2.Bottom <= R1.Top then Exit(akT);
  if R2.Top >= R1.Bottom then Exit(akB);
  if R2.Right <= R1.Left then Exit(akL);
  if R2.Left >= R1.Right then Exit(akR);
  Result := akNone;
end;

var
  P, C: TPointD;
  Square, Triangle, Cloud, Hull, Rot, Poly: TPointDArray;
  BB, R1, R2, RR: TRectD;
  Half: TPolarD;
  Q1, Q2: TPointD;
  N, I, J, K, L, Failures, Mismatches: Integer;
  Base, SecondIdx: TRect;
  Pt, Second: TPointI;
  Pieces: TSegmentDArray;
  Rays, Segments, MergedLines, Horizontals, Verticals: TSegmentDArray;
  Contour: TPointDArray;
  Orientations: TSegmentOrientationArray;
  Triples: TIndexTripleArray;
  Samples: TLineSpanArray;
  Bulges: TArray<Integer>;
  Angles, Kept: TArray<Double>;
  Border, SecondBorder: TBorderAngle;
  Skew: Double;
  Spared: Integer;
  Ribbon: TPointDArray;
const
  COORDS: array[0..7] of Integer = (0, 5, 10, 12, 15, 20, 25, 30);
  SIZES: array[0..3] of Integer = (0, 3, 10, 22);
var
  Merged: TRectDArray;
  Idx: Integer;
  Angle: Double;
  Angle30: Double;
  RectCloud: TPointDArray;
  Longer, Shorter: Double;
begin
  Check(Orient2D(Point(0, 0), Point(1, 0), Point(0, 1)) > 0, 'Orient2D CCW > 0');
  Check(Orient2D(Point(0, 0), Point(1, 0), Point(0, -1)) < 0, 'Orient2D CW < 0');
  Check(Orient2D(Point(0, 0), Point(2, 2), Point(1, 1)) = 0, 'Orient2D collinear = 0');
  Check(SegmentsIntersect(Point(0, 0), Point(4, 4), Point(0, 4), Point(4, 0)), 'SegmentsIntersect: crossing');
  Check(not SegmentsIntersect(Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)),
    'SegmentsIntersect: parallel');
  Check(not SegmentsIntersect(Point(0, 0), Point(1, 1), Point(2, 2), Point(3, 3)),
    'SegmentsIntersect: collinear disjoint');
  Check(SegmentsIntersect(Point(0, 0), Point(2, 2), Point(2, 2), Point(3, 0)),
    'SegmentsIntersect: touch at endpoint');
  Check(SegmentsIntersectionPoint(PointD(0, 0), PointD(4, 4), PointD(0, 4), PointD(4, 0), P),
    'SegmentsIntersectionPoint: crossing returns True');
  CheckClose(P.X, 2, 'SegmentsIntersectionPoint X');
  CheckClose(P.Y, 2, 'SegmentsIntersectionPoint Y');
  Check(not SegmentsIntersectionPoint(PointD(0, 0), PointD(2, 0), PointD(0, 1), PointD(2, 1), P),
    'SegmentsIntersectionPoint: parallel returns False');
  Check(not SegmentsIntersectionPoint(PointD(0, 0), PointD(1, 0), PointD(2, 2), PointD(2, 3), P),
    'SegmentsIntersectionPoint: lines cross but outside segments');
  Check(LinesIntersectionPoint(PointD(0, 0), PointD(1, 0), PointD(2, 2), PointD(2, 3), P),
    'LinesIntersectionPoint: infinite lines cross at (2,0)');
  CheckClose(P.X, 2, 'LinesIntersectionPoint X');
  CheckClose(P.Y, 0, 'LinesIntersectionPoint Y');
  Square := [PointD(0, 0), PointD(4, 0), PointD(4, 4), PointD(0, 4)];
  Check(PointInPolygon(PointD(2, 2), Square), 'PointInPolygon: inside');
  Check(not PointInPolygon(PointD(5, 2), Square), 'PointInPolygon: outside (right)');
  Check(not PointInPolygon(PointD(-1, 2), Square), 'PointInPolygon: outside (left)');
  CheckClose(PolygonArea(Square), 16, 'PolygonArea: square 4x4');
  Triangle := [PointD(0, 0), PointD(4, 0), PointD(0, 3)];
  CheckClose(PolygonArea(Triangle), 6, 'PolygonArea: triangle (BUGFIX: оригинал давал 0)');
  C := PolygonCentroid(Square);
  CheckClose(C.X, 2, 'PolygonCentroid square X');
  CheckClose(C.Y, 2, 'PolygonCentroid square Y');
  C := MeanPoint(Square);
  CheckClose(C.X, 2, 'MeanPoint X');
  Cloud := [PointD(0, 0), PointD(4, 0), PointD(4, 4), PointD(0, 4), PointD(2, 2)];
  Hull := ConvexHull(Cloud, False);
  Check(Length(Hull) = 4, Format('ConvexHull: drops interior point (got %d, expected 4)', [Length(Hull)]));
  CheckClose(Distance(PointD(0, 0), PointD(3, 4)), 5, 'Distance: 3-4-5');
  CheckClose(Distance(PointD(1, 5), PointD(1, 9)), 4, 'Distance: vertical fast-path');
  CheckClose(LineSlope(PointD(0, 0), PointD(2, 4)), 2, 'LineSlope = 2');
  Check(IsInfinite(LineSlope(PointD(1, 0), PointD(1, 5))), 'LineSlope vertical = Infinity');
  CheckClose(LineYIntercept(PointD(0, 3), 2), 3, 'LineYIntercept');
  CheckClose(DirectionAngle(PointD(0, 0), PointD(1, 0)), 0, 'DirectionAngle east = 0');
  CheckClose(DirectionAngle(PointD(0, 0), PointD(0, 1)), Pi / 2, 'DirectionAngle +Y = Pi/2');
  CheckClose(IncludedAngle(PointD(1, 0), PointD(0, 0), PointD(0, 1)), Pi / 2, 'IncludedAngle right angle');
  CheckClose(WrapAngle360(-Pi / 2), 3 * Pi / 2, 'WrapAngle360 negative');
  CheckClose(AngularDifference(0, 3 * Pi / 2), Pi / 2, 'AngularDifference shortest');
  CheckClose(CircularMean([0.0, Pi / 2]), Pi / 4, 'CircularMean of 0 and 90 deg');
  CheckClose(CircularMean([2 * Pi - 0.02, 2 * Pi - 0.01, 0.01, 0.02]), 0,
    'CircularMean: заворот через ноль дает ноль, а не Pi');
  CheckClose(CircularMean([Pi - 0.02, Pi - 0.01, Pi + 0.01, Pi + 0.02]), Pi,
    'CircularMean: без заворота совпадает с обычным средним');
  CheckClose(CircularMean([1.234]), 1.234, 'CircularMean: один угол - он сам');
  CheckClose(CircularMean([3.99, 4.0, 4.01]), 4.0,
    'CircularMean: ответ приведен к [0, 2*Pi), а не отрицателен');
  Angle := CircularMean([0.0, Pi]);
  Check((Angle >= 0) and (Angle < 2 * Pi),
    Format('CircularMean: у противоположных ответ в [0,2Pi) (got %.6f)', [Angle]));
  CheckClose(CircularMean([]), 0,
    'CircularMean: пустой вход дает ноль - см. оговорку у объявления');
  P := PointAtAngleDistance(PointD(0, 0), 0, 5);
  CheckClose(P.X, 5, 'PointAtAngleDistance X');
  CheckClose(P.Y, 0, 'PointAtAngleDistance Y');
  Check(PointSideOfLine(PointD(1, 1), PointD(0, 0), PointD(2, 0)) = 1, 'PointSideOfLine left = +1');
  Check(PointSideOfLine(PointD(1, -1), PointD(0, 0), PointD(2, 0)) = -1, 'PointSideOfLine right = -1');
  Check(PointSideOfLine(PointD(1, 0), PointD(0, 0), PointD(2, 0)) = 0, 'PointSideOfLine on = 0');
  Check(PointOnSegment(PointD(1, 0), PointD(0, 0), PointD(2, 0)), 'PointOnSegment inside');
  Check(not PointOnSegment(PointD(3, 0), PointD(0, 0), PointD(2, 0)), 'PointOnSegment collinear but outside');
  Check(not PointOnSegment(PointD(1, 1), PointD(0, 0), PointD(2, 0)), 'PointOnSegment off line');
  Check(SegmentsCollinear(PointD(0, 0), PointD(4, 0), PointD(1, 0), PointD(2, 0)), 'SegmentsCollinear: yes');
  Check(not SegmentsCollinear(PointD(0, 0), PointD(4, 0), PointD(1, 1), PointD(2, 0)),
    'SegmentsCollinear: no');
  CheckClose(CollinearOverlapLength(PointD(0, 0), PointD(4, 0), PointD(2, 0), PointD(6, 0)), 2,
    'CollinearOverlapLength');
  Rot := RotatePoints([PointD(1, 0)], Pi / 2, PointD(0, 0));
  CheckClose(Rot[0].X, 0, 'RotatePoints X');
  CheckClose(Rot[0].Y, 1, 'RotatePoints Y');
  BB := BoundingBox([PointD(1, 2), PointD(5, 0), PointD(3, 8)]);
  CheckClose(BB.Left, 1, 'BoundingBox Left');
  CheckClose(BB.Top, 0, 'BoundingBox Top (BUGFIX: оригинал float T/B из .X)');
  CheckClose(BB.Right, 5, 'BoundingBox Right');
  CheckClose(BB.Bottom, 8, 'BoundingBox Bottom');
  Check(NearestPoint(PointD(0, 0), [PointD(5, 5), PointD(1, 1), PointD(9, 9)], Idx) and (Idx = 1),
    'NearestPoint index = 1');
  R1 := RectD(0, 0, 4, 4);
  R2 := RectD(2, 2, 6, 6);
  CheckClose(RectArea(R1), 16, 'RectArea');
  CheckClose(RectWidth(R1), 4, 'RectWidth');
  C := RectCenter(R1);
  CheckClose(C.X, 2, 'RectCenter X');
  Check(RectsIntersect(R1, R2), 'RectsIntersect: yes');
  Check(not RectsIntersect(R1, RectD(5, 5, 9, 9)), 'RectsIntersect: no');
  Check(RectIntersection(R1, R2, RR) and (RectArea(RR) = 4), 'RectIntersection area = 4');
  RR := RectUnion(R1, R2);
  Check((RR.Left = 0) and (RR.Top = 0) and (RR.Right = 6) and (RR.Bottom = 6), 'RectUnion bounds');
  CheckClose(RectIoU(R1, R2), 4 / 28, 'RectIoU');
  CheckClose(RectGap(RectD(0, 0, 2, 2), RectD(5, 0, 7, 2)), 3, 'RectGap horizontal');
  CheckClose(RectGap(R1, R2), 0, 'RectGap overlapping = 0');
  Poly := RectToPolygon(R1);
  Check(Length(Poly) = 4, 'RectToPolygon: 4 corners');
  Check(RectsApproxEqual(R1, RectD(0.4, 0.3, 4.2, 3.8), 0.5), 'RectsApproxEqual: within tolerance');
  Check(not RectsApproxEqual(R1, RectD(1, 1, 4, 4), 0.5), 'RectsApproxEqual: beyond tolerance');
  Merged := MergeNearbyRects([RectD(0, 0, 2, 2), RectD(2, 0, 4, 2), RectD(20, 20, 22, 22)], 0.5);
  Check(Length(Merged) = 2, Format('MergeNearbyRects 3 -> 2 (got %d)', [Length(Merged)]));
  Check(ClassifyRectOverlap(Rect(0, 0, 4, 4), Rect(0, 0, 4, 4)) = okSame, 'ClassifyRectOverlap: okSame');
  Check(ClassifyRectOverlap(Rect(0, 0, 10, 10), Rect(2, 2, 8, 8)) = okInside,
    'ClassifyRectOverlap: okInside');
  Check(ClassifyRectOverlap(Rect(2, 2, 8, 8), Rect(0, 0, 10, 10)) = okOutside,
    'ClassifyRectOverlap: okOutside');
  Check(ClassifyRectOverlap(Rect(0, 0, 4, 4), Rect(2, 2, 6, 6)) = okBR, 'ClassifyRectOverlap: okBR corner');
  Check(ClassifyRectPosition(Rect(0, 0, 4, 10), Rect(10, 2, 14, 8)) = pkR, 'ClassifyRectPosition: pkR');
  Check(ClassifyRectPosition(Rect(10, 0, 14, 10), Rect(0, 2, 4, 8)) = pkL, 'ClassifyRectPosition: pkL');
  Check(ClassifyRectPosition(Rect(0, 10, 10, 14), Rect(2, 0, 8, 4)) = pkT, 'ClassifyRectPosition: pkT');
  Check(ClassifyRectPosition(Rect(0, 0, 10, 4), Rect(2, 10, 8, 14)) = pkB, 'ClassifyRectPosition: pkB');
  Check(ClassifyRectPosition(Rect(10, 10, 14, 14), Rect(0, 0, 4, 4)) = pkTTLL,
    'ClassifyRectPosition: pkTTLL');
  RR := RectD(0, 0, 10, 10);
  Rot := RotateRectCorners(RR, 0);
  CheckClose(Rot[0].X, 0, 'RotateRectCorners skew=0 TL.X');
  CheckClose(Rot[0].Y, 0, 'RotateRectCorners skew=0 TL.Y');
  CheckClose(Rot[2].X, 10, 'RotateRectCorners skew=0 BR.X');
  CheckClose(Rot[2].Y, 10, 'RotateRectCorners skew=0 BR.Y');
  R2 := RotatedRectBounds(RR, 0);
  CheckClose(R2.Right - R2.Left, 10, 'RotatedRectBounds skew=0 width');
  R2 := RotatedRectBounds(RR, Pi / 2);
  CheckClose(R2.Right - R2.Left, 10, 'RotatedRectBounds skew=90 width (symmetry)');
  R2 := RotatedRectBounds(RR, Pi / 4);
  CheckClose(R2.Right - R2.Left, 10 * Sqrt(2), 'RotatedRectBounds skew=45 width (diagonal)');
  Square := [PointD(0, 0), PointD(4, 0), PointD(4, 4), PointD(0, 4)];
  Triangle := [PointD(10, 0), PointD(14, 0), PointD(12, 4)];
  Check(PointInAnyPolygon(PointD(2, 2), [Square, Triangle]), 'PointInAnyPolygon: внутри первого');
  Check(PointInAnyPolygon(PointD(12, 1), [Square, Triangle]), 'PointInAnyPolygon: внутри второго');
  Check(not PointInAnyPolygon(PointD(7, 2), [Square, Triangle]), 'PointInAnyPolygon: между ними - снаружи');
  Check(not PointInAnyPolygon(PointD(2, 2), []), 'PointInAnyPolygon: пустой список - False');
  Cloud := [PointD(1, 1), PointD(2, 2), PointD(3, 3)];
  Check(PointsOnSegment(Cloud, PointD(0, 0), PointD(4, 4)), 'PointsOnSegment: все на отрезке');
  Cloud := [PointD(1, 1), PointD(2, 2.5), PointD(3, 3)];
  Check(not PointsOnSegment(Cloud, PointD(0, 0), PointD(4, 4)), 'PointsOnSegment: одна в стороне - False');
  Cloud := [PointD(1, 1), PointD(9, 9)];
  Check(not PointsOnSegment(Cloud, PointD(0, 0), PointD(4, 4)), 'PointsOnSegment: за концом - False');
  Check(PointsOnSegment([], PointD(0, 0), PointD(4, 4)), 'PointsOnSegment: пустой набор - True');
  Check(PointsOnSegment([PointD(2, 2)], PointD(2, 2), PointD(2, 2)), 'PointsOnSegment: вырожденный, совпало');
  Check(not PointsOnSegment([PointD(2, 3)], PointD(2, 2), PointD(2, 2)),
    'PointsOnSegment: вырожденный, не совпало');
  Poly := ClosePolygon([PointD(0, 0), PointD(4, 0), PointD(4, 4)]);
  Check(Length(Poly) = 4, 'ClosePolygon: незамкнутый вырос на одну вершину');
  CheckClose(Poly[3].X, 0, 'ClosePolygon: последняя вершина равна первой по X');
  CheckClose(Poly[3].Y, 0, 'ClosePolygon: последняя вершина равна первой по Y');
  Poly := ClosePolygon([PointD(0, 0), PointD(4, 0), PointD(4, 4), PointD(0, 0)]);
  Check(Length(Poly) = 4, 'ClosePolygon: уже замкнутый не растет');
  Check(Length(ClosePolygon([])) = 0, 'ClosePolygon: пустой вход - пустой выход');
  Cloud := [PointD(0, 0), PointD(1, 5), PointD(2, 9)];
  Poly := ReversePolyline(Cloud);
  Check(Length(Poly) = 3, 'ReversePolyline: длина сохранилась');
  CheckClose(Poly[0].Y, 9, 'ReversePolyline: первой стала последняя');
  CheckClose(Poly[2].Y, 0, 'ReversePolyline: последней стала первая');
  CheckClose(Cloud[0].Y, 0, 'ReversePolyline: вход не изменился');
  Check(Length(ReversePolyline([])) = 0, 'ReversePolyline: пустой вход - пустой выход');
  Check(IsInfinite(SanitizeSlope(PointD(2, 0), PointD(2, 10))), 'SanitizeSlope: вертикаль - Infinity');
  CheckClose(SanitizeSlope(PointD(0, 3), PointD(10, 3)), 0, 'SanitizeSlope: горизонталь - ноль');
  CheckClose(SanitizeSlope(PointD(0, 0), PointD(2, 4)), 2, 'SanitizeSlope: обычный наклон');
  Check(LineSlope(PointD(0, 0), PointD(10, 1e-12)) <> 0,
    'SanitizeSlope: у LineSlope почти-горизонталь не ноль');
  Check(SanitizeSlope(PointD(0, 0), PointD(10, 1e-12)) = 0, 'SanitizeSlope: почти-горизонталь - ровный ноль');
  CheckClose(SlopeToAngle(0), 0, 'SlopeToAngle: ноль - ноль');
  CheckClose(SlopeToAngle(1), Pi / 4, 'SlopeToAngle: единица - 45 град');
  CheckClose(SlopeToAngle(Infinity), Pi / 2, 'SlopeToAngle: Infinity - 90 град');
  CheckClose(AngleToSlope(0), 0, 'AngleToSlope: ноль - ноль');
  CheckClose(AngleToSlope(Pi), 0, 'AngleToSlope: Pi - ровный ноль');
  CheckClose(AngleToSlope(Pi / 4), 1, 'AngleToSlope: 45 град - единица');
  Check(IsInfinite(AngleToSlope(Pi / 2)), 'AngleToSlope: 90 град - Infinity');
  CheckClose(SlopeToAngle(AngleToSlope(Pi / 6)), Pi / 6, 'SlopeToAngle(AngleToSlope) сходится');
  C := PointD(10, 10);
  Check(QuadrantOf(C, PointD(15, 5)) = qkRightTop, 'QuadrantOf: правая верхняя');
  Check(QuadrantOf(C, PointD(5, 5)) = qkLeftTop, 'QuadrantOf: левая верхняя');
  Check(QuadrantOf(C, PointD(5, 15)) = qkLeftBottom, 'QuadrantOf: левая нижняя');
  Check(QuadrantOf(C, PointD(15, 15)) = qkRightBottom, 'QuadrantOf: правая нижняя');
  Check(QuadrantOf(C, PointD(10, 5)) = qkRightTop, 'QuadrantOf: на вертикальной оси - правая');
  Check(QuadrantOf(C, PointD(15, 10)) = qkRightBottom, 'QuadrantOf: на горизонтальной оси - нижняя');
  Check(QuadrantOf(C, C) = qkRightBottom, 'QuadrantOf: сам центр');
  Half := ToPolar(C, PointD(20, 10));
  CheckClose(Half.Distance, 10, 'ToPolar: расстояние вправо');
  CheckClose(Half.Angle, 0, 'ToPolar: угол вправо - ноль');
  Half := ToPolar(C, PointD(10, 20));
  CheckClose(Half.Distance, 10, 'ToPolar: расстояние вниз');
  CheckClose(Half.Angle, Pi / 2, 'ToPolar: угол вниз - 90 град (экранные оси)');
  Half := ToPolar(C, PointD(0, 10));
  CheckClose(Half.Angle, Pi, 'ToPolar: угол влево - Pi, а не минус Pi');
  Half := ToPolar(C, C);
  CheckClose(Half.Distance, 0, 'ToPolar: сам центр - нулевое расстояние');
  P := PointD(13, 17);
  Half := ToPolar(C, P);
  P := PointAtAngleDistance(C, Half.Angle, Half.Distance);
  CheckClose(P.X, 13, 'ToPolar туда и обратно: X');
  CheckClose(P.Y, 17, 'ToPolar туда и обратно: Y');
  P := PointD(4, 2);
  Half := ToPolar(C, P);
  P := PointAtAngleDistance(C, Half.Angle, Half.Distance);
  CheckClose(P.X, 4, 'ToPolar туда и обратно, другая четверть: X');
  CheckClose(P.Y, 2, 'ToPolar туда и обратно, другая четверть: Y');
  CheckClose(CounterClockwiseAngle(qkRightTop, 0.5), 0.5, 'CCW: правая верхняя - без добавки');
  CheckClose(CounterClockwiseAngle(qkLeftTop, 0.5), Pi + 0.5, 'CCW: левая верхняя - плюс Pi');
  CheckClose(CounterClockwiseAngle(qkLeftBottom, 0.5), Pi + 0.5, 'CCW: левая нижняя - плюс Pi');
  CheckClose(CounterClockwiseAngle(qkRightBottom, 0.5), 2 * Pi + 0.5,
    'CCW: правая нижняя - плюс полный оборот');
  CheckClose(CounterClockwiseAngle(qkLeftTop, 1.0), CounterClockwiseAngle(qkLeftBottom, 1.0),
    'CCW: обе левые четверти дают одну добавку');
  Check(RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(5, -1), PointD(5, 1), P),
    'RayLine: точка впереди луча');
  CheckClose(P.X, 5, 'RayLine: X впереди');
  Check(not RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(-5, -1), PointD(-5, 1), P),
    'RayLine: точка позади луча - False');
  Check(LinesIntersectionPoint(PointD(0, 0), PointD(1, 0), PointD(-5, -1), PointD(-5, 1), P),
    'RayLine: прямая ту же точку находит');
  Check(not RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(0, 3), PointD(4, 3), P),
    'RayLine: параллельные - False');
  Check(RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(0, -1), PointD(0, 1), P),
    'RayLine: точка в начале луча - True');
  N := LineCircleIntersection(PointD(-10, 0), PointD(10, 0), PointD(0, 0), 5, Q1, Q2);
  Check(N = 2, 'LineCircle: секущая через центр - две точки');
  CheckClose(Abs(Q1.X), 5, 'LineCircle: секущая, модуль X первой');
  CheckClose(Abs(Q2.X), 5, 'LineCircle: секущая, модуль X второй');
  N := LineCircleIntersection(PointD(-10, 5), PointD(10, 5), PointD(0, 0), 5, Q1, Q2);
  Check(N = 1, 'LineCircle: касание - одна точка');
  CheckClose(Q1.Y, 5, 'LineCircle: касание, Y');
  CheckClose(Q1.X, Q2.X, 'LineCircle: касание, обе выдачи совпали');
  Check(LineCircleIntersection(PointD(-10, 9), PointD(10, 9), PointD(0, 0), 5, Q1, Q2) = 0,
    'LineCircle: мимо - ноль');
  Check(LineCircleIntersection(PointD(3, 3), PointD(3, 3), PointD(0, 0), 5, Q1, Q2) = 0,
    'LineCircle: вырожденный отрезок - ноль');
  Check(LineCircleIntersection(PointD(-10, 0), PointD(10, 0), PointD(0, 0), 0, Q1, Q2) = 1,
    'LineCircle: нулевой радиус через центр - одна');
  Check(LineCircleIntersection(PointD(-10, 0), PointD(10, 0), PointD(0, 0), -5, Q1, Q2) = 0,
    'LineCircle: отрицательный радиус - ноль');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(8, 0), 5, Q1, Q2) = 2,
    'CircleCircle: пересекаются - две');
  Check(Distance(Q1, Q2) > 1e-6, 'CircleCircle: две точки различны');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(10, 0), 5, Q1, Q2) = 1,
    'CircleCircle: внешнее касание - одна');
  CheckClose(Q1.X, 5, 'CircleCircle: внешнее касание, X');
  Check(CircleCircleIntersection(PointD(0, 0), 10, PointD(5, 0), 5, Q1, Q2) = 1,
    'CircleCircle: внутреннее касание - одна');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(20, 0), 5, Q1, Q2) = 0,
    'CircleCircle: далеко - ноль');
  Check(CircleCircleIntersection(PointD(0, 0), 10, PointD(1, 0), 2, Q1, Q2) = 0,
    'CircleCircle: одна внутри другой - ноль');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(0, 0), 5, Q1, Q2) = 0,
    'CircleCircle: совпадающие - ноль, а не две наугад');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(0, 0), 3, Q1, Q2) = 0,
    'CircleCircle: концентрические разных радиусов - ноль');
  Check(CircleCircleIntersection(PointD(0, 0), 0, PointD(4, 0), 4, Q1, Q2) = 1,
    'CircleCircle: нулевой радиус на второй окружности - одна');
  Check(CircleCircleIntersection(PointD(0, 0), -5, PointD(8, 0), 5, Q1, Q2) = 0,
    'CircleCircle: отрицательный радиус - ноль');
  Idx := 0;
  Failures := 0;
  for I := 0 to 24 do
    for J := 1 to 12 do
    begin
      C := PointD(I * 0.75, 0);
      N := CircleCircleIntersection(PointD(0, 0), 5, C, J, Q1, Q2);
      if N >= 1 then
      begin
        Inc(Idx);
        if Abs(Distance(PointD(0, 0), Q1) - 5) > 1e-6 then Inc(Failures);
        if Abs(Distance(C, Q1) - J) > 1e-6 then Inc(Failures);
      end;
      if N = 2 then
      begin
        if Abs(Distance(PointD(0, 0), Q2) - 5) > 1e-6 then Inc(Failures);
        if Abs(Distance(C, Q2) - J) > 1e-6 then Inc(Failures);
      end;
    end;
  Check(Idx > 100, Format('CircleCircle перебор: набралось случаев с точками (%d)', [Idx]));
  Check(Failures = 0,
    Format('CircleCircle перебор: точки лежат на обеих окружностях (промахов %d)', [Failures]));
  Idx := 0;
  Failures := 0;
  for I := -12 to 12 do
    for J := -12 to 12 do
    begin
      N := LineCircleIntersection(PointD(-20, I), PointD(20, I), PointD(J, 0), 5, Q1, Q2);
      if N >= 1 then
      begin
        Inc(Idx);
        if Abs(Distance(PointD(J, 0), Q1) - 5) > 1e-6 then Inc(Failures);
        if Abs(Q1.Y - I) > 1e-6 then Inc(Failures);
      end;
    end;
  Check(Idx > 100, Format('LineCircle перебор: набралось случаев с точками (%d)', [Idx]));
  Check(Failures = 0,
    Format('LineCircle перебор: точки на окружности и на прямой (промахов %d)', [Failures]));
  Cloud := [PointD(0, 0), PointD(10, 0), PointD(0, 10)];
  Poly := ShearPoints(Cloud, Pi / 4, 0);
  CheckClose(Poly[0].X, 0, 'ShearPoints: начало на месте');
  CheckClose(Poly[1].X, 10, 'ShearPoints: точка на оси X не сдвинута');
  CheckClose(Poly[2].X, 10, 'ShearPoints: точка на оси Y сдвинута на tan*Y');
  CheckClose(Poly[2].Y, 10, 'ShearPoints: Y не тронут при сдвиге только по X');
  CheckClose(Cloud[2].X, 0, 'ShearPoints: вход не изменился');
  Poly := ShearPoints(ShearPoints(Cloud, 0.3, 0), -0.3, 0);
  CheckClose(Poly[2].X, 0, 'ShearPoints туда и обратно по одной оси: X');
  CheckClose(Poly[2].Y, 10, 'ShearPoints туда и обратно по одной оси: Y');
  Poly := ShearPoints(ShearPoints(Cloud, 0.3, 0.3), -0.3, -0.3);
  CheckClose(Poly[2].X, 0, 'ShearPoints: по двум осям X все же возвращается');
  Check(Abs(Poly[2].Y - 10) > 1e-6, 'ShearPoints: по двум осям Y НЕ возвращается');
  Check(Length(ShearPoints([], 0.3, 0)) = 0, 'ShearPoints: пустой вход - пустой выход');
  Cloud := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10)];
  Poly := ScalePointsAboutMeanPoint(Cloud, 2);
  CheckClose(Poly[0].X, -5, 'ScalePoints: угол ушел вдвое дальше по X');
  CheckClose(Poly[0].Y, -5, 'ScalePoints: угол ушел вдвое дальше по Y');
  CheckClose(MeanPoint(Poly).X, 5, 'ScalePoints: средняя точка не сдвинулась по X');
  CheckClose(MeanPoint(Poly).Y, 5, 'ScalePoints: средняя точка не сдвинулась по Y');
  Poly := ScalePointsAboutMeanPoint(ScalePointsAboutMeanPoint(Cloud, 3), 1 / 3);
  CheckClose(Poly[2].X, 10, 'ScalePoints туда и обратно: X');
  CheckClose(Poly[2].Y, 10, 'ScalePoints туда и обратно: Y');
  Poly := ScalePointsAboutMeanPoint(Cloud, 0);
  CheckClose(Poly[0].X, 5, 'ScalePoints: нулевой множитель стягивает все в среднюю точку');
  Check(Length(ScalePointsAboutMeanPoint([], 2)) = 0, 'ScalePoints: пустой вход - пустой выход');
  Poly := TurnPointsAboutMeanPoint(Cloud, Pi / 2);
  CheckClose(MeanPoint(Poly).X, 5, 'TurnPoints: средняя точка не сдвинулась');
  Poly := TurnPointsAboutMeanPoint(
    TurnPointsAboutMeanPoint(
      TurnPointsAboutMeanPoint(
        TurnPointsAboutMeanPoint(
          Cloud,
          Pi / 2
        ),
        Pi / 2
      ),
      Pi / 2
    ),
    Pi / 2
  );
  CheckClose(Poly[0].X, 0, 'TurnPoints: четыре четверти оборота возвращают исходное, X');
  CheckClose(Poly[0].Y, 0, 'TurnPoints: четыре четверти оборота возвращают исходное, Y');
  Check(Length(TurnPointsAboutMeanPoint([], 1)) = 0, 'TurnPoints: пустой вход - пустой выход');
  Poly := TurnPointsAboutMeanPoint(Cloud, 0.7);
  Hull := RotatePoints(Cloud, 0.7, MeanPoint(Cloud));
  CheckClose(Poly[1].X, Hull[1].X, 'TurnPoints: совпал с RotatePoints при явном центре, X');
  CheckClose(Poly[1].Y, Hull[1].Y, 'TurnPoints: совпал с RotatePoints при явном центре, Y');
  Cloud := [PointD(0, 0), PointD(1, 0), PointD(2, 0), PointD(9, 0), PointD(0, 9)];
  Check(Abs(MeanPoint(Cloud).X - PolygonCentroid(Cloud).X) > 0.5,
    'TurnPoints: набор выбран так, что средняя и центроид РАСХОДЯТСЯ');
  Poly := TurnPointsAboutMeanPoint(Cloud, Pi / 2);
  Hull := RotatePoints(Cloud, Pi / 2, MeanPoint(Cloud));
  CheckClose(Poly[3].X, Hull[3].X, 'TurnPoints: опора именно средняя точка');
  Base := Rect(10, 10, 20, 20);
  Check(RectRelativeAlignment(Base, Rect(0, 0, 5, 5)) = akTL, 'Alignment: сверху слева');
  Check(RectRelativeAlignment(Base, Rect(25, 0, 30, 5)) = akTR, 'Alignment: сверху справа');
  Check(RectRelativeAlignment(Base, Rect(0, 25, 5, 30)) = akLB, 'Alignment: снизу слева');
  Check(RectRelativeAlignment(Base, Rect(25, 25, 30, 30)) = akRB, 'Alignment: снизу справа');
  Check(RectRelativeAlignment(Base, Rect(12, 0, 18, 5)) = akT, 'Alignment: сверху');
  Check(RectRelativeAlignment(Base, Rect(12, 25, 18, 30)) = akB, 'Alignment: снизу');
  Check(RectRelativeAlignment(Base, Rect(0, 12, 5, 18)) = akL, 'Alignment: слева');
  Check(RectRelativeAlignment(Base, Rect(25, 12, 30, 18)) = akR, 'Alignment: справа');
  Check(RectRelativeAlignment(Base, Rect(12, 12, 18, 18)) = akNone, 'Alignment: внутри - никак');
  Check(RectRelativeAlignment(Base, Rect(0, 12, 10, 18)) = akL, 'Alignment: касание слева - уже слева');
  Mismatches := 0;
  Idx := 0;
  for I := 0 to 7 do
    for J := 0 to 7 do
      for K := 0 to 3 do
        for L := 0 to 3 do
        begin
          SecondIdx := Rect(COORDS[I], COORDS[J], COORDS[I] + SIZES[K], COORDS[J] + SIZES[L]);
          Inc(Idx);
          if RectRelativeAlignment(Base, SecondIdx) <> ReferenceCases(Base, SecondIdx) then
            Inc(Mismatches);
        end;
  Check(Idx = 1024, Format('Alignment перебор: случаев состоялось (%d, ждали 1024)', [Idx]));
  Check(Mismatches = 0, Format('Alignment: совпал с дословным оригиналом на всех парах (расхождений %d)', [Mismatches]));
  SecondIdx := Rect(25, 12, 5, 18);
  Check(RectRelativeAlignment(Base, SecondIdx) = akNone,
    'Alignment: перевернутый вход нормализуется и накрывает основу');
  Check(ReferenceCases(Base, SecondIdx) = akL,
    'Alignment: а дословный оригинал на нем говорит слева - отличие названо');
  Base := Rect(0, 0, 10, 10);
  Check(RectsWithinMargin(Base, Rect(5, 5, 15, 15), 0, 0), 'WithinMargin: перекрываются - True');
  Check(not RectsWithinMargin(Base, Rect(20, 0, 30, 10), 0, 0), 'WithinMargin: далеко - False');
  Check(RectsWithinMargin(Base, Rect(15, 0, 25, 10), 3, 0),
    'WithinMargin: зазор 5 при допуске 3 - True, потому что раздуваются ОБА');
  Check(not RectsWithinMargin(Base, Rect(15, 0, 25, 10), 2, 0),
    'WithinMargin: зазор 5 при допуске 2 - False');
  Check(not RectsWithinMargin(Base, Rect(16, 0, 26, 10), 3, 0),
    'WithinMargin: зазор ровно в два допуска - касание, False');
  Check(RectsWithinMargin(Base, Rect(16, 0, 26, 10), 4, 0),
    'WithinMargin: тот же зазор при допуске 4 - уже True');
  Check(not RectsWithinMargin(Base, Rect(0, 20, 10, 30), 20, 0),
    'WithinMargin: щедрый допуск по X не спасает расхождение по Y');
  Check(RectsWithinMargin(Base, Rect(0, 20, 10, 30), 0, 6),
    'WithinMargin: тот же случай лечится допуском по Y');
  Check(not RectsWithinMargin(Rect(0, 20, 10, 30), Rect(0, 0, 10, 10), 20, 0),
    'WithinMargin: сосед сверху, щедрый допуск по X не спасает');
  Check(RectsWithinMargin(Rect(0, 20, 10, 30), Rect(0, 0, 10, 10), 0, 6),
    'WithinMargin: сосед сверху лечится допуском по Y');
  Check(RectsWithinMargin(Base, Rect(15, 15, 5, 5), 0, 0),
    'WithinMargin: перевернутый вход нормализуется');
  Check(LargestTileSizeForCount(10, 10, 4, N, Idx), 'TileSize: решение найдено');
  Check((10 div N) * (10 div Idx) >= 4, 'TileSize: плиток не меньше запрошенного');
  Check(N * Idx = 25, Format('TileSize: площадь наибольшая из возможных, 5x5 (got %dx%d)', [N, Idx]));
  Check(LargestTileSizeForCount(7, 3, 1, N, Idx), 'TileSize: одна плитка найдена');
  Check(N * Idx = 21, Format('TileSize: одна плитка занимает все (got %dx%d)', [N, Idx]));
  Check(not LargestTileSizeForCount(4, 4, 100, N, Idx), 'TileSize: столько не влезет - False');
  Check(N = 0, Format('TileSize: при отказе ширина обнулена (got %d)', [N]));
  Check(not LargestTileSizeForCount(0, 10, 1, N, Idx), 'TileSize: нулевой источник - False');
  Check(not LargestTileSizeForCount(10, 10, 0, N, Idx), 'TileSize: ноль плиток - False');
  Check(LargestTileSizeForCount(10, 10, 3, N, Idx), 'TileSize: три плитки, решение есть');
  Check(N * Idx = 30, Format('TileSize: остаток теряется по каждой оси, 30 (got %dx%d)', [N, Idx]));
  Check(LargestTileSizeForCount(12, 2, 6, N, Idx), 'TileSize: узкая полоса, решение есть');
  Check((12 div N) * (2 div Idx) >= 6, 'TileSize: узкая полоса, плиток хватает');
  N := 0;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0, N, Point(0, 0));
  Check((Pt.X = 1) and (Pt.Y = 0), 'NextOnRay: вправо - соседний пиксель');
  Check(N = 1, Format('NextOnRay: расстояние выросло до 1 (got %d)', [N]));
  N := 0;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0.05, N, Point(0, 0));
  Check((Pt.X <> 0) or (Pt.Y <> 0), 'NextOnRay: пологий луч все же сдвинулся');
  Check(N >= 1, 'NextOnRay: расстояние выросло');
  N := 0;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0, N, Point(1, 0));
  Check((Pt.X = 2) and (Pt.Y = 0), 'NextOnRay: совпавший шаг пропущен');
  Check(N = 2, Format('NextOnRay: расстояние перескочило через совпадение (got %d)', [N]));
  Second := NextDistinctPointOnRay(PointD(0, 0), 0.05, N, Pt);
  Check((Second.X <> Pt.X) or (Second.Y <> Pt.Y), 'NextOnRay: следующая отлична от предыдущей');
  N := 7;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0 / 0.0, N, Point(3, 3));
  Check((Pt.X = 3) and (Pt.Y = 3), 'NextOnRay: NaN - точка прежняя');
  Check(N = 7, Format('NextOnRay: NaN - расстояние не тронуто (got %d)', [N]));
  Square := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10), PointD(0, 0)];
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(15, 5), Square, csInside);
  Check(Length(Pieces) = 1, Format('ClipSegment: внутри один кусок (got %d)', [Length(Pieces)]));
  if Length(Pieces) = 1 then
  begin
    CheckClose(Pieces[0][0].X, 0, 'ClipSegment: внутренний кусок начинается на границе');
    CheckClose(Pieces[0][1].X, 10, 'ClipSegment: и кончается на другой границе');
  end;
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(15, 5), Square, csOutside);
  Check(Length(Pieces) = 2, Format('ClipSegment: снаружи два куска (got %d)', [Length(Pieces)]));
  Pieces := ClipSegmentByPolygon(PointD(2, 5), PointD(8, 5), Square, csInside);
  Check(Length(Pieces) = 1, 'ClipSegment: целиком внутри - один кусок');
  if Length(Pieces) = 1 then CheckClose(Pieces[0][0].X, 2, 'ClipSegment: кусок от самого начала');
  Pieces := ClipSegmentByPolygon(PointD(20, 5), PointD(30, 5), Square, csInside);
  Check(Length(Pieces) = 0, 'ClipSegment: целиком снаружи - внутренних нет');
  Pieces := ClipSegmentByPolygon(PointD(20, 5), PointD(30, 5), Square, csOutside);
  Check(Length(Pieces) = 1, 'ClipSegment: целиком снаружи - один внешний');
  Check(Length(ClipSegmentByPolygon(PointD(0, 0), PointD(9, 9), [PointD(1, 1)], csInside)) = 0,
    'ClipSegment: одна вершина - пусто');
  Poly := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10)];
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(5, 5), Poly, csInside);
  Check(Length(Pieces) = 1, 'ClipSegment: незамкнутый вход, кусок все равно один');
  CheckClose(Pieces[0][0].X, -5,
    'ClipSegment: без замыкающего ребра левая граница НЕ найдена - кусок с самого начала');
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(5, 5), ClosePolygon(Poly), csInside);
  CheckClose(Pieces[0][0].X, 0, 'ClipSegment: после ClosePolygon левая граница найдена');
  Rays := BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, Pi / 180);
  Check(Length(Rays) = 360, Format('RadialScan: полный круг - 360 лучей (got %d)', [Length(Rays)]));
  Check((Length(Rays) > 0) and (Length(Rays[0]) = 2), 'RadialScan: луч - ровно две точки');
  if Length(Rays) > 0 then
  begin
    CheckClose(Rays[0][0].X, 50, 'RadialScan: луч начинается в центре по X');
    CheckClose(Rays[0][0].Y, 50, 'RadialScan: луч начинается в центре по Y');
  end;
  Rays := BuildRadialScanLines(PointD(50, 50), 101, 101, 0, Pi / 4, Pi / 2);
  Check(Length(Rays) = 1, 'RadialScan: один шаг - один луч');
  C := RayEnd(0, 101, 101);
  CheckClose(C.X, 100, 'RadialScan: угол 0 упирается в правый край');
  CheckClose(C.Y, 50, 'RadialScan: угол 0 идет по горизонтали');
  C := RayEnd(Pi / 2, 101, 101);
  CheckClose(C.Y, 0, 'RadialScan: четверть круга упирается в ВЕРХНИЙ край');
  CheckClose(C.X, 50, 'RadialScan: четверть круга идет по вертикали');
  C := RayEnd(Pi, 101, 101);
  CheckClose(C.X, 0, 'RadialScan: полкруга упирается в левый край');
  C := RayEnd(3 * Pi / 2, 101, 101);
  CheckClose(C.Y, 100, 'RadialScan: три четверти упираются в НИЖНИЙ край');
  C := RayEnd(7 * Pi / 4, 101, 101);
  CheckClose(C.X, 100, 'RadialScan: диагональ - правый нижний угол по X');
  CheckClose(C.Y, 100, 'RadialScan: диагональ - правый нижний угол по Y');
  C := RayEnd(0, 21, 11);
  CheckClose(C.X, 20, 'RadialScan: широкий - правый край на 20, а не на 10');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 0, Pi / 2)) = 0,
    'RadialScan: пустой промежуток - лучей нет');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, Pi / 2, Pi / 2)) = 1,
    'RadialScan: верхняя граница исключающая - один луч, не два');
  Check(Length(BuildRadialScanLines(PointD(500, 500), 101, 101, 0, 2 * Pi, Pi / 180)) = 0,
    'RadialScan: центр снаружи - ни одного луча');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 0, 101, 0, 2 * Pi, Pi / 180)) = 0,
    'RadialScan: нулевая ширина - пусто');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, 0)) = 0,
    'RadialScan: нулевой шаг - пусто, а не вечный цикл');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, -1)) = 0,
    'RadialScan: шаг назад - пусто');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0 / 0.0, 2 * Pi, Pi / 180)) = 0,
    'RadialScan: NaN в углу - пусто');
  Rays := BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, Pi / 180);
  Failures := 0;
  for I := 0 to High(Rays) do
    if not ((Abs(Rays[I][1].X) < 1e-6) or (Abs(Rays[I][1].X - 100) < 1e-6) or
      (Abs(Rays[I][1].Y) < 1e-6) or (Abs(Rays[I][1].Y - 100) < 1e-6)) then
        Inc(Failures);
  Check(Failures = 0, Format('RadialScan: все концы на краю (мимо %d)', [Failures]));
  Mismatches := 0;
  for I := 0 to High(Rays) do
  begin
    C := PointD(Rays[I][1].X - 50, Rays[I][1].Y - 50);
    if Abs(AngularDifference(ArcTan2(-C.Y, C.X), I * Pi / 180)) > 1e-6 then
      Inc(Mismatches);
  end;
  Check(Mismatches = 0, Format('RadialScan: направление совпадает с углом (мимо %d)', [Mismatches]));
  Ribbon := BuildRibbonPolygon(
    [
      PointD(
        0,
        0
      ),
      PointD(
        5,
        0
      ),
      PointD(
        10,
        0
      )
    ],
    [
      PointD(
        0,
        4
      ),
      PointD(
        5,
        4
      ),
      PointD(
        10,
        4
      )
    ]
  );
  Check(Length(Ribbon) = 7, Format('Ribbon: три и три дают семь вершин (got %d)', [Length(Ribbon)]));
  CheckClose(Ribbon[0].X, 0, 'Ribbon: начало - первая точка левого края');
  CheckClose(Ribbon[2].X, 10, 'Ribbon: левый край пройден ВПЕРЕД');
  CheckClose(Ribbon[3].X, 10, 'Ribbon: правый край начат с КОНЦА');
  CheckClose(Ribbon[3].Y, 4, 'Ribbon: и это точно правый край, а не левый');
  CheckClose(Ribbon[5].X, 0, 'Ribbon: правый край пройден НАЗАД');
  CheckClose(Ribbon[6].X, Ribbon[0].X, 'Ribbon: контур замкнут по X');
  CheckClose(Ribbon[6].Y, Ribbon[0].Y, 'Ribbon: контур замкнут по Y');
  CheckClose(PolygonArea(Ribbon), 40, 'Ribbon: площадь - как у прямоугольника, а не восьмерка');
  Ribbon := BuildRibbonPolygon([PointD(0, 0), PointD(10, 0)], [PointD(0, 4), PointD(10, 4)]);
  Check(Length(Ribbon) = 5, Format('Ribbon: два и два дают пять вершин (got %d)', [Length(Ribbon)]));
  CheckClose(PolygonArea(Ribbon), 40, 'Ribbon: у наименьшей ленты площадь та же');
  Ribbon := BuildRibbonPolygon(
    [
      PointD(
        0,
        0
      ),
      PointD(
        3,
        0
      ),
      PointD(
        7,
        0
      ),
      PointD(
        10,
        0
      )
    ],
    [
      PointD(
        0,
        4
      ),
      PointD(
        10,
        4
      )
    ]
  );
  Check(Length(Ribbon) = 7, Format('Ribbon: четыре и два дают семь (got %d)', [Length(Ribbon)]));
  CheckClose(Ribbon[4].Y, 4, 'Ribbon: четыре и два - правый край начат с конца');
  CheckClose(PolygonArea(Ribbon), 40, 'Ribbon: четыре и два - площадь та же');
  Ribbon := BuildRibbonPolygon([PointD(0, 0), PointD(10, 0)], [PointD(0, 0), PointD(10, 4)]);
  Check(Length(Ribbon) = 4, Format('Ribbon: замкнутый вход не удваивает вершину (got %d)', [Length(Ribbon)]));
  if Length(Ribbon) = 4 then
  begin
    CheckClose(Ribbon[3].X, Ribbon[0].X, 'Ribbon: замкнутый вход - контур все же замкнут по X');
    CheckClose(Ribbon[3].Y, Ribbon[0].Y, 'Ribbon: замкнутый вход - и по Y');
  end;
  Check(Length(BuildRibbonPolygon([PointD(0, 0)], [PointD(0, 4), PointD(10, 4)])) = 0,
    'Ribbon: одна точка слева - пусто');
  Check(Length(BuildRibbonPolygon([PointD(0, 0), PointD(10, 0)], [])) = 0,
    'Ribbon: пустой правый край - пусто');
  Check(FitSizePreserveAspect(100, 50, 10, 10, fkContain, N, K),
    'Fit: широкий внутрь квадрата - сработал');
  Check((N = 10) and (K = 5), Format('Fit: широкий внутрь дает 10 на 5 (got %d на %d)', [N, K]));
  Check(FitSizePreserveAspect(100, 50, 10, 10, fkCover, N, K),
    'Fit: широкий поверх квадрата - сработал');
  Check((N = 20) and (K = 10), Format('Fit: широкий поверх дает 20 на 10 (got %d на %d)', [N, K]));
  FitSizePreserveAspect(50, 100, 10, 10, fkContain, N, K);
  Check((N = 5) and (K = 10), Format('Fit: высокий внутрь дает 5 на 10 (got %d на %d)', [N, K]));
  FitSizePreserveAspect(50, 100, 10, 10, fkCover, N, K);
  Check((N = 10) and (K = 20), Format('Fit: высокий поверх дает 10 на 20 (got %d на %d)', [N, K]));
  FitSizePreserveAspect(100, 50, 20, 10, fkContain, N, K);
  Check((N = 20) and (K = 10), Format('Fit: то же соотношение внутрь - вся коробка (got %d на %d)', [N, K]));
  FitSizePreserveAspect(100, 50, 20, 10, fkCover, N, K);
  Check((N = 20) and (K = 10), Format('Fit: то же соотношение поверх - вся коробка (got %d на %d)', [N, K]));
  FitSizePreserveAspect(100, 50, 30, 30, fkContain, N, K);
  Check((N = 30) and (K = 15), Format('Fit: 100x50 внутрь 30x30 (got %d на %d)', [N, K]));
  Failures := 0;
  Mismatches := 0;
  for I := 1 to 40 do
    for J := 1 to 40 do
    begin
      if FitSizePreserveAspect(I, J, 17, 11, fkContain, N, K) then
        if (N > 17) or (K > 11) then Inc(Failures);
      if FitSizePreserveAspect(I, J, 17, 11, fkCover, N, K) then
        if (N < 17) or (K < 11) then Inc(Mismatches);
    end;
  Check(Failures = 0, Format('Fit: вписанное не вылезает из коробки (мимо %d)', [Failures]));
  Check(Mismatches = 0, Format('Fit: накрывающее не меньше коробки (мимо %d)', [Mismatches]));
  Check(not FitSizePreserveAspect(100, 0, 10, 10, fkContain, N, K),
    'Fit: нулевая высота источника - отказ, а не деление на ноль');
  Check((N = 0) and (K = 0), 'Fit: при отказе размер обнулен, а не оставлен прежним');
  Check(not FitSizePreserveAspect(0, 50, 10, 10, fkContain, N, K),
    'Fit: нулевая ширина источника - отказ');
  Check(not FitSizePreserveAspect(-100, -50, 10, 10, fkContain, N, K),
    'Fit: обе стороны источника отрицательны - отказ, а не 20 на 10');
  Check(not FitSizePreserveAspect(0, 0, 10, 10, fkContain, N, K),
    'Fit: источник ноль на ноль - отказ');
  Check(not FitSizePreserveAspect(100, 50, 0, 10, fkContain, N, K), 'Fit: нулевая коробка - отказ');
  Check(not FitSizePreserveAspect(100, 50, -3, 10, fkContain, N, K), 'Fit: коробка назад - отказ');
  Check(not FitSizePreserveAspect(1000, 1, 5, 5, fkContain, N, K),
    'Fit: схлопнулось в ноль - отказ, а не размер с нулем');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 1), PointD(9, 9), 2),
    'MeetByEnds: начало с началом');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(9, 9), PointD(0, 1), 2),
    'MeetByEnds: начало с концом');
  Check(SegmentsMeetByEnds(PointD(10, 0), PointD(0, 0), PointD(0, 1), PointD(9, 9), 2),
    'MeetByEnds: конец с началом');
  Check(SegmentsMeetByEnds(PointD(10, 0), PointD(0, 0), PointD(9, 9), PointD(0, 1), 2),
    'MeetByEnds: конец с концом');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 2), PointD(50, 50), 2),
    'MeetByEnds: одна пара ровно на пороге - сходятся');
  Check(not SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 20), PointD(10, 20), 2),
    'MeetByEnds: далеко - не сходятся');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 2), PointD(10, 2), 2),
    'MeetByEnds: ровно на пороге - сходятся');
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 10), PointD(0, 0)],
              [PointD(0, 0), PointD(20, 0)]];
  Orientations := [soHorizontal, soVertical, soHorizontal];
  Triples := FindBracketTriples(Segments, Orientations, 2);
  Check(Length(Triples) = 1, Format('Bracket: скобка П найдена один раз (got %d)', [Length(Triples)]));
  if Length(Triples) = 1 then
  begin
    Check(Triples[0].A = 0, 'Bracket: первым идет крайний');
    Check(Triples[0].B = 1, 'Bracket: вторым поперечный');
    Check(Triples[0].C = 2, 'Bracket: третьим второй крайний');
  end;
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 0), PointD(0, 10)],
              [PointD(0, 0), PointD(20, 0)]];
  Triples := FindBracketTriples(Segments, Orientations, 2);
  Check(Length(Triples) = 1,
    Format('Bracket: развернутый поперечный - тройка одна (got %d)', [Length(Triples)]));
  if Length(Triples) = 1 then
  begin
    Check((Triples[0].A = 2) and (Triples[0].B = 1) and (Triples[0].C = 0),
      Format('Bracket: та же тройка, названная с другого конца (%d,%d,%d)',
        [Triples[0].A, Triples[0].B, Triples[0].C]));
  end;
  if Length(Triples) = 1 then
  begin
    Check(Triples[0].A = 2, 'Bracket: развернутый - первым НИЖНИЙ крайний');
    Check(Triples[0].C = 0, 'Bracket: развернутый - третьим ВЕРХНИЙ крайний');
  end;
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(0, 10), PointD(0, 0)]];
  Check(Length(FindBracketTriples(Segments, [soHorizontal, soVertical], 2)) = 0,
    'Bracket: двух сторон мало');
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 10), PointD(0, 0)],
              [PointD(0, 0), PointD(20, 0)]];
  Check(Length(FindBracketTriples(Segments, [soOther, soVertical, soHorizontal], 2)) = 0,
    'Bracket: косой крайний - тройки нет');
  Check(Length(FindBracketTriples(Segments, [soOther, soVertical, soOther], 2)) = 0,
    'Bracket: оба крайних косые - тройки нет');
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 10), PointD(0, 0)],
              [PointD(0, 0), PointD(20, 0)],
              [PointD(50, 50), PointD(70, 50)]];
  Check(Length(FindBracketTriples(Segments, Orientations, 2)) = 0,
    'Bracket: наборы разной длины - пусто, даже когда скобка есть');
  SetLength(Samples, 5);
  for I := 0 to 4 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Check(SpanWidth(Samples[0]) = 3, 'SpanWidth: от 10 до 12 - три');
  Samples[2].First := -1;
  Check(SpanWidth(Samples[2]) = 0, 'SpanWidth: замера нет - ноль');
  Check(MeanSpanWidth(Samples, N) and (N = 3), Format('MeanSpanWidth: три (got %d)', [N]));
  Samples[3].Last := 20;
  Check(MeanSpanWidth(Samples, N) and (N = 5),
    Format('MeanSpanWidth: пустые не тянут среднее вниз (got %d)', [N]));
  SetLength(Samples, 2);
  Samples[0].First := -1;
  Samples[0].Last := -1;
  Samples[1].First := -1;
  Samples[1].Last := -1;
  Check(not MeanSpanWidth(Samples, N), 'MeanSpanWidth: годных нет - отказ');
  SetLength(Samples, 10);
  for I := 0 to 9 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[4].Last := 20;
  Bulges := FindSpanBulges(Samples, 3, 1.2);
  Check(Length(Bulges) = 1, Format('Bulges: одно вздутие (got %d)', [Length(Bulges)]));
  if Length(Bulges) = 1 then
    Check(Bulges[0] = 4, Format('Bulges: и оно на месте 4 (got %d)', [Bulges[0]]));
  Check(Length(FindSpanBulges(Samples, 0, 1.2)) = 0, 'Bulges: без средней ширины - пусто');
  Samples[4].Last := 13;
  Check(Length(FindSpanBulges(Samples, 3, 1.2)) = 0, 'Bulges: ровно на пороге - НЕ вздутие');
  Samples[4].Last := 14;
  Bulges := FindSpanBulges(Samples, 3, 1.2);
  Check(Length(Bulges) = 1, 'Bulges: выше порога - вздутие');
  if Length(Bulges) = 1 then
    Check(Bulges[0] = 4, Format('Bulges: выше порога - и оно на месте 4 (got %d)', [Bulges[0]]));
  Samples[4].Last := 12;
  Check(Length(FindSpanBulges(Samples, 3, 1.2)) = 0, 'Bulges: ровной линии вздутий нет');
  SetLength(Samples, 100);
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2), 'Classify: ровная тонкая - линовка');
  Spared := 0;
  for I := 0 to 99 do if Samples[I].Spare then Inc(Spared);
  Check(Spared = 0, Format('Classify: у ровной щадить нечего (got %d)', [Spared]));
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 23;
    Samples[I].Spare := False;
  end;
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2), 'Classify: слишком толстая - не линовка');
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 21;
    Samples[I].Spare := False;
  end;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: ширина РОВНО по пределу - еще линовка');
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 22;
    Samples[I].Spare := False;
  end;
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: на единицу толще предела - уже не линовка');
  SetLength(Samples, 101);
  for I := 0 to 100 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[50].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: длинные ровные участки перевешивают вздутие');
  Check(Samples[50].Spare, 'Classify: само вздутие пощажено');
  Check(Samples[45].Spare, 'Classify: и его окрестность в пределах MaxWidth');
  Check(not Samples[20].Spare, 'Classify: а середина длинного ровного участка - нет');
  SetLength(Samples, 100);
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
    if I mod 20 = 10 then Samples[I].Last := 20;
  end;
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: частые вздутия - текст, а не линовка');
  Spared := 0;
  for I := 0 to 99 do if Samples[I].Spare then Inc(Spared);
  Check(Spared = 100, Format('Classify: у текста пощажено все (got %d)', [Spared]));
  SetLength(Samples, 60);
  for I := 0 to 59 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[55].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: длинный участок ДО первого вздутия тоже считается');
  SetLength(Samples, 100);
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[98].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: вздутие у самого конца - длинный участок перевесил');
  Check(Samples[99].Spare, 'Classify: пощада дошла до последнего замера');
  Check(Samples[91].Spare, 'Classify: и до начала окрестности');
  Check(not Samples[89].Spare, 'Classify: а дальше окрестности - нет');
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[1].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: вздутие у самого начала - длинный участок перевесил');
  Check(Samples[0].Spare, 'Classify: пощада дошла до первого замера');
  Check(not Samples[11].Spare, 'Classify: а дальше окрестности - нет');
  SetLength(Samples, 0);
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2), 'Classify: пустой замер - не линовка');
  Border.Found := True;
  Border.FromAngle := 0.2;
  Border.LastAngle := 0.4;
  Border.Slip := 1;
  CheckClose(BorderAngleValue(Border), 0.3, 'BorderAngle: середина промежутка');
  Border.FromAngle := -0.4;
  Border.LastAngle := -0.2;
  CheckClose(BorderAngleValue(Border), -0.3, 'BorderAngle: и у отрицательных');
  Border.Found := False;
  CheckClose(BorderAngleValue(Border), 0, 'BorderAngle: ненайденная дает ноль');
  Border.Found := True;
  Border.FromAngle := 0;
  Border.LastAngle := 0;
  CheckClose(BorderAngleValue(Border), 0, 'BorderAngle: и ровная граница дает ноль');
  Check(Border.Found, 'BorderAngle: но у ровной Found истинен - в этом вся разница');
  Border.Found := True;
  Border.Slip := 1.0;
  SecondBorder.Found := True;
  SecondBorder.Slip := 0.5;
  Check(ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: спор разобран');
  Check(not Border.Found, 'Arbitrate: отброшена та, у которой доля БОЛЬШЕ');
  Check(SecondBorder.Found, 'Arbitrate: та, у которой меньше, осталась');
  Border.Found := True;
  Border.Slip := 0.25;
  SecondBorder.Found := True;
  SecondBorder.Slip := 1.0;
  Check(ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: зеркальный спор разобран');
  Check(Border.Found, 'Arbitrate: зеркально - осталась первая');
  Check(not SecondBorder.Found, 'Arbitrate: зеркально - отброшена вторая');
  Border.Found := True;
  Border.Slip := 0.5;
  SecondBorder.Found := True;
  SecondBorder.Slip := 0.5;
  Check(not ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: равные доли не спорят');
  Check(Border.Found and SecondBorder.Found, 'Arbitrate: обе остались');
  SecondBorder.Slip := 0.5 + 1e-12;
  Check(not ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: почти равные не спорят');
  Border.Found := False;
  Border.Slip := 1.0;
  SecondBorder.Found := True;
  SecondBorder.Slip := 0.5;
  Check(not ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: ненайденная не спорит');
  Check(SecondBorder.Found, 'Arbitrate: и найденная не пострадала');
  Angles := [0.1, 9.9];
  Kept := RejectSkewOutliers(Angles, 0.01);
  Check(Length(Kept) = 2, 'RejectOutliers: двух не трогает');
  if Length(Kept) = 2 then
  begin
    CheckClose(Kept[0], 0.1, 'RejectOutliers: и первый тот же');
    CheckClose(Kept[1], 9.9, 'RejectOutliers: и второй тот же');
  end;
  Angles := [7.7];
  Kept := RejectSkewOutliers(Angles, 0.01);
  Check(Length(Kept) = 1, 'RejectOutliers: одного не трогает');
  if Length(Kept) = 1 then
    CheckClose(Kept[0], 7.7, 'RejectOutliers: и он тот же');
  Check(Length(RejectSkewOutliers(nil, 0.01)) = 0, 'RejectOutliers: пусто дает пусто');
  Angles := [5.0, 5.0, 5.1];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 0,
    Format('RejectOutliers: согласных больших углов уцелело ноль (got %d)', [Length(Kept)]));
  Angles := [0.10, 0.11, 0.12];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 3,
    Format('RejectOutliers: согласных малых углов уцелело три (got %d)', [Length(Kept)]));
  if Length(Kept) = 3 then
  begin
    CheckClose(Kept[0], 0.10, 'RejectOutliers: тройка - первый тот же');
    CheckClose(Kept[1], 0.11, 'RejectOutliers: тройка - второй тот же');
    CheckClose(Kept[2], 0.12, 'RejectOutliers: тройка - третий тот же');
  end;
  Angles := [0.1, 0.2, 9.0];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 2,
    Format('RejectOutliers: далекий прощает малым, но не себе (got %d)', [Length(Kept)]));
  if Length(Kept) = 2 then
    Check((Kept[0] < 1) and (Kept[1] < 1), 'RejectOutliers: уцелели ИМЕННО малые, а не любые два');
  Angles := [1.0, 1.0, 5.0];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 2,
    Format('RejectOutliers: разброс спасает единицы (got %d)', [Length(Kept)]));
  Angles := [0.1, 0.2, 9.0];
  Kept := RejectSkewOutliers(Angles, 0);
  Check(Length(Kept) = 2,
    Format('RejectOutliers: допуск ноль - малые уцелели (got %d)', [Length(Kept)]));
  Kept := RejectSkewOutliers(Angles, -0.001);
  Check(Length(Kept) = 0,
    Format('RejectOutliers: отрицательный допуск отсевает всех (got %d)', [Length(Kept)]));
  Angles := [0.10, 0.11, 0.12];
  Kept := RejectSkewOutliers(Angles, 0.5);
  if Length(Kept) = 3 then
    Check((Kept[0] < Kept[1]) and (Kept[1] < Kept[2]),
      'RejectOutliers: порядок уцелевших сохранен');
  Angles := [0.2, 0.4, 0.6];
  Check(CombineSkewAngles(Angles, spMean, 1, Skew), 'Combine: среднее сработало');
  CheckClose(Skew, 0.4, 'Combine: среднее трех');
  Check(CombineSkewAngles(Angles, spMaximum, 1, Skew), 'Combine: наибольший сработал');
  CheckClose(Skew, 0.6, 'Combine: наибольший из трех');
  Angles := [0.2, -0.9, 0.6];
  CombineSkewAngles(Angles, spMaximum, 1, Skew);
  CheckClose(Skew, -0.9, 'Combine: наибольший ПО МОДУЛЮ, знак свой');
  CombineSkewAngles(Angles, spMean, 1, Skew);
  CheckClose(Skew, -0.1 / 3 * 1, 'Combine: среднее со знаками');
  Skew := 7;
  Check(not CombineSkewAngles([0.5, 0.5], spMean, 3, Skew), 'Combine: двух мало при трех нужных');
  CheckClose(Skew, 0, 'Combine: при отказе перекос обнулен');
  Check(not CombineSkewAngles(nil, spMean, 1, Skew), 'Combine: пусто - отказ');
  Check(CombineSkewAngles([0.5, 0.5], spMean, 2, Skew), 'Combine: ровно по требованию - довольно');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(25, 10), PointD(50, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 10, 5);
  Check(Length(MergedLines) = 1, Format('Merge: два куска сшиты в один (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].X, 0, 'Merge: сшитый начинается у левого края');
    CheckClose(MergedLines[0][1].X, 50, 'Merge: и кончается у правого');
    CheckClose(MergedLines[0][0].Y, 10, 'Merge: поперек - середина первого');
  end;
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(45, 10), PointD(50, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 2,
    'Merge: разрыв больше допуска - не сшиты');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(21, 30), PointD(50, 30)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 2,
    'Merge: разная высота - не сшиты');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(25, 12), PointD(50, 12)]];
  MergedLines := MergeCollinearLines(Segments, True, 3, 10, 5);
  Check(Length(MergedLines) = 1, 'Merge: разная высота в пределах допуска - сшиты');
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].Y, 10, 'Merge: один конец на высоте первого');
    CheckClose(MergedLines[0][1].Y, 12, 'Merge: другой на высоте второго - сшитый НАКЛОНЕН');
  end;
  Segments := [[PointD(0, 10), PointD(3, 10)], [PointD(5, 10), PointD(8, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 50)) = 2,
    'Merge: сшивка короче предела - оставлены как были');
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 1,
    'Merge: тот же вход при малом пределе - сшит');
  Segments := [[PointD(0, 10), PointD(10, 10)], [PointD(15, 10), PointD(25, 10)],
              [PointD(30, 10), PointD(40, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 10, 5);
  Check(Length(MergedLines) = 1, Format('Merge: три куска сшиты в один (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
    CheckClose(MergedLines[0][1].X, 40, 'Merge: сшитый из трех достает до дальнего края');
  Segments := [[PointD(0, 10), PointD(50, 10)], [PointD(10, 10), PointD(20, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 0, 5);
  Check(Length(MergedLines) = 1, Format('Merge: вложенный поглощен (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].X, 0, 'Merge: уцелел длинный, а не короткий');
    CheckClose(MergedLines[0][1].X, 50, 'Merge: и целиком');
  end;
  Segments := [[PointD(10, 10), PointD(20, 10)], [PointD(0, 12), PointD(50, 12)]];
  MergedLines := MergeCollinearLines(Segments, True, 3, 0, 5);
  Check(Length(MergedLines) = 1, 'Merge: вложенный на другой высоте - один');
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].Y, 12, 'Merge: уцелевший ВЕСЬ на высоте длинного');
    CheckClose(MergedLines[0][1].Y, 12, 'Merge: и второй конец тоже - не наклонен');
  end;
  Segments := [[PointD(10, 10), PointD(20, 10)], [PointD(0, 10), PointD(50, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 0, 5);
  Check(Length(MergedLines) = 1, 'Merge: вложенный поглощен и в обратном порядке');
  if Length(MergedLines) = 1 then
    CheckClose(MergedLines[0][1].X - MergedLines[0][0].X, 50, 'Merge: уцелел длинный и тут');
  Segments := [[PointD(0, 10), PointD(30, 10)], [PointD(20, 10), PointD(50, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 0, 5);
  Check(Length(MergedLines) = 1, 'Merge: налегающие сведены в один');
  if Length(MergedLines) = 1 then
    CheckClose(MergedLines[0][1].X - MergedLines[0][0].X, 50, 'Merge: и размах общий');
  Segments := [[PointD(10, 0), PointD(10, 20)], [PointD(10, 25), PointD(10, 50)]];
  MergedLines := MergeCollinearLines(Segments, False, 2, 10, 5);
  Check(Length(MergedLines) = 1, Format('Merge: вертикали сшиты (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].Y, 0, 'Merge: вертикаль от верха');
    CheckClose(MergedLines[0][1].Y, 50, 'Merge: и до низа');
  end;
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 2,
    'Merge: вертикали как горизонтали - не сшиты');
  Check(Length(MergeCollinearLines(nil, True, 2, 10, 5)) = 0, 'Merge: пусто дает пусто');
  Segments := [[PointD(0, 10), PointD(20, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 1, 'Merge: один остается один');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(25, 10), PointD(50, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, -1, 10, 5)) = 0,
    'Merge: отрицательный допуск поперек - отказ');
  Check(Length(MergeCollinearLines(Segments, True, 2, -1, 5)) = 0,
    'Merge: отрицательный разрыв - отказ');
  Contour := [PointD(0, 0), PointD(50, 0), PointD(50, 40), PointD(0, 40), PointD(0, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals);
  Check(N = 4, Format('AxisLines: у прямоугольника четыре стороны (got %d)', [N]));
  Check(Length(Horizontals) = 2, Format('AxisLines: две горизонтали (got %d)', [Length(Horizontals)]));
  Check(Length(Verticals) = 2, Format('AxisLines: две вертикали (got %d)', [Length(Verticals)]));
  if Length(Horizontals) = 2 then
  begin
    CheckClose(Horizontals[0][0].X, 0, 'AxisLines: первая горизонталь от нуля');
    CheckClose(Horizontals[0][1].X, 50, 'AxisLines: и до пятидесяти');
    CheckClose(Horizontals[0][0].Y, 0, 'AxisLines: и она именно верхняя');
  end;
  if Length(Verticals) = 2 then
    CheckClose(Verticals[0][0].X, 50, 'AxisLines: первая вертикаль - правая');
  Contour := [PointD(0, 0), PointD(50, 30), PointD(20, 60), PointD(0, 0)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: у косого контура осевых нет');
  Check((Length(Horizontals) = 0) and (Length(Verticals) = 0),
    'AxisLines: и наборы пусты, а не с мусором');
  Contour := [PointD(0, 0), PointD(50, 5)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: наклон вне допуска - не осевой');
  Check(ExtractAxisLinesFromContour(Contour, 0.15, 10, 5, Horizontals, Verticals) = 1,
    'AxisLines: тот же наклон при щедром допуске - осевой');
  Contour := [PointD(0, 0), PointD(5, 0)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: короткая сторона не берется');
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 3, 5, Horizontals, Verticals) = 1,
    'AxisLines: она же при малом пределе - берется');
  Contour := [PointD(0, 0), PointD(2, 0), PointD(4, 0), PointD(6, 0), PointD(50, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals);
  Check(N = 1, Format('AxisLines: мелкие шаги не дробят линию (got %d)', [N]));
  if Length(Horizontals) = 1 then
  begin
    CheckClose(Horizontals[0][0].X, 0, 'AxisLines: и он от самого начала');
    CheckClose(Horizontals[0][1].X, 50, 'AxisLines: до самого конца');
  end;
  Contour := [PointD(0, 0), PointD(20, 12), PointD(24, 12), PointD(50, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 40, Horizontals, Verticals);
  Check(N >= 1, Format('AxisLines: заглядывание нашло осевой (got %d)', [N]));
  Contour := [PointD(0, 0), PointD(20, 12), PointD(5, 0), PointD(50, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 40, Horizontals, Verticals);
  Check(N >= 1, Format('AxisLines: заглядывание мимо короткого нашло осевой (got %d)', [N]));
  if Length(Horizontals) >= 1 then
    CheckClose(Horizontals[0][1].X, 50, 'AxisLines: взят ДЛИННЫЙ, а не огрызок до пятой точки');
  Contour := [PointD(0, 0), PointD(20, 12), PointD(24, 12), PointD(50, 0)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 2, Horizontals, Verticals) = 0,
    'AxisLines: малый разрыв - заглядывание не достает');
  Check(ExtractAxisLinesFromContour(nil, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: пустой контур - ноль');
  Contour := [PointD(7, 7)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: одна точка - ноль');
  Contour := [PointD(0, 0), PointD(50, 0)];
  Check(ExtractAxisLinesFromContour(Contour, -1, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: отрицательный допуск угла - отказ');
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 0, 5, Horizontals, Verticals) = 0,
    'AxisLines: нулевой предел длины - отказ');
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, -1, Horizontals, Verticals) = 0,
    'AxisLines: отрицательный разрыв - отказ');
  RR := NormalizeRect(RectD(30, 40, 10, 20));
  CheckClose(RR.Left, 10, 'Normalize: левый стал меньшим');
  CheckClose(RR.Right, 30, 'Normalize: правый большим');
  CheckClose(RR.Top, 20, 'Normalize: верхний меньшим');
  CheckClose(RR.Bottom, 40, 'Normalize: нижний большим');
  RR := NormalizeRect(RectD(10, 20, 30, 40));
  Check((RR.Left = 10) and (RR.Right = 30) and (RR.Top = 20) and (RR.Bottom = 40),
    'Normalize: упорядоченный не тронут');
  CheckClose(RectHeight(RectD(10, 20, 30, 45)), 25, 'RectHeight: высота 25');
  CheckClose(RectHeight(RectD(10, 45, 30, 20)), -25,
    'RectHeight: у вывернутого высота ОТРИЦАТЕЛЬНА, а не по модулю');
  Check(RectIsEmpty(RectD(10, 20, 10, 45)), 'RectIsEmpty: нулевая ширина - пуст');
  Check(RectIsEmpty(RectD(10, 20, 30, 20)), 'RectIsEmpty: нулевая высота - пуст');
  Check(not RectIsEmpty(RectD(10, 20, 30, 45)), 'RectIsEmpty: полноценный не пуст');
  Check(RectIsEmpty(RectD(30, 20, 10, 45)), 'RectIsEmpty: вывернутый по X - пуст');
  Square := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10)];
  Check(PolygonSignedArea(Square) <> 0, 'SignedArea: у квадрата площадь не ноль');
  CheckClose(Abs(PolygonSignedArea(Square)), 100, 'SignedArea: и по модулю сто');
  CheckClose(PolygonSignedArea(ReversePolyline(Square)), -PolygonSignedArea(Square),
    'SignedArea: обратный обход дает противоположный ЗНАК');
  CheckClose(PolygonSignedArea([PointD(0, 0), PointD(10, 0)]), 0,
    'SignedArea: у отрезка площади нет');
  R1 := RectD(0, 0, 10, 10);
  R2 := RectD(15, 0, 25, 10);
  Check(RectsCloserThan(R1, R2, 6), 'CloserThan: зазор 5 при допуске 6 - ближе');
  Check(not RectsCloserThan(R1, R2, 4), 'CloserThan: тот же зазор при допуске 4 - нет');
  Check(RectsCloserThan(R1, R2, 5), 'CloserThan: ровно по допуску - ближе, порог нестрогий');
  Check(RectsCloserThan(R1, RectD(5, 5, 15, 15), 0), 'CloserThan: налегающие - при нулевом допуске');
  CheckClose(WrapAngle180(0.3), 0.3, 'Wrap180: свое остается своим');
  CheckClose(WrapAngle180(Pi + 0.3), 0.3, 'Wrap180: за Pi заворачивается');
  CheckClose(WrapAngle180(-0.3), Pi - 0.3, 'Wrap180: отрицательное заворачивается ВВЕРХ');
  CheckClose(WrapAngle180(2 * Pi + 0.3), 0.3, 'Wrap180: два оборота тоже');
  CheckClose(WrapAngle180(Pi), 0, 'Wrap180: ровно Pi дает ноль - промежуток ПОЛУОТКРЫТ');
  Check(RotatedBoundingSize(100, 40, 0, N, K), 'RotBounds: сработал');
  Check((N = 100) and (K = 40), Format('RotBounds: ноль градусов - тот же (got %d на %d)', [N, K]));
  RotatedBoundingSize(100, 40, Pi / 2, N, K);
  Check((N = 40) and (K = 100), Format('RotBounds: четверть - стороны местами (got %d на %d)', [N, K]));
  RotatedBoundingSize(100, 40, Pi, N, K);
  Check((N = 100) and (K = 40), Format('RotBounds: полоборота - тот же (got %d на %d)', [N, K]));
  RotatedBoundingSize(100, 40, Pi / 4, N, K);
  Check(K > 40, Format('RotBounds: наискось рамка ВЫШЕ исходной (got %d)', [K]));
  Check(N < 100, Format('RotBounds: и УЖЕ исходной по ширине (got %d)', [N]));
  CheckClose(N, K, 'RotBounds: у наискось на 45 стороны равны');
  RotatedBoundingSize(100, 40, 0.3, N, K);
  RotatedBoundingSize(100, 40, -0.3, I, J);
  Check((N = I) and (K = J), 'RotBounds: знак угла не меняет охвата');
  Check(not RotatedBoundingSize(0, 40, 0.3, N, K), 'RotBounds: нулевая ширина - отказ');
  Check((N = 0) and (K = 0), 'RotBounds: при отказе размер обнулен');
  Check(not RotatedBoundingSize(100, 40, 0 / 0.0, N, K), 'RotBounds: NaN в угле - отказ');
  Pt := InverseRotateMapPoint(Point(70, 30), Point(50, 20), Point(60, 25), qkRightTop, 0);
  Check((Pt.X = 60) and (Pt.Y = 25),
    Format('InvRotate: нулевой угол - перенос середин (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(60, 25), Point(50, 20), Point(60, 25), qkRightTop, 0.3);
  Check((Pt.X = 50) and (Pt.Y = 20),
    Format('InvRotate: середина цели идет в середину источника (got %d,%d)',
      [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(60, 25), Point(50, 20), Point(60, 25), qkLeftBottom, -0.7);
  Check((Pt.X = 50) and (Pt.Y = 20),
    'InvRotate: и при другой четверти с другим углом - тоже середина');
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkRightTop, 0.4);
  Check((Pt.X = 65) and (Pt.Y = 10),
    Format('InvRotate: правая верхняя дает 65,10 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkLeftTop, 0.4);
  Check((Pt.X = 47) and (Pt.Y = 38),
    Format('InvRotate: левая верхняя дает 47,38 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkLeftBottom, 0.4);
  Check((Pt.X = 35) and (Pt.Y = 30),
    Format('InvRotate: левая нижняя дает 35,30 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkRightBottom, 0.4);
  Check((Pt.X = 53) and (Pt.Y = 2),
    Format('InvRotate: правая нижняя дает 53,2 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 30), Point(50, 20), Point(60, 25), qkRightTop, 1e-12);
  Check((Pt.X = 60) and (Pt.Y = 25), 'InvRotate: почти нулевой угол - тоже перенос');
  Second := InverseRotateMapPoint(Point(70, 30), Point(50, 20), Point(60, 25), qkRightTop, 0.5);
  Check((Second.X <> Pt.X) or (Second.Y <> Pt.Y), 'InvRotate: за пределом идет настоящий расчет');
  Check(ZoneGridSize(100, 60, 20, 20, N, K), 'ZoneGrid: сработал');
  Check((N = 5) and (K = 3), Format('ZoneGrid: 100 на 60 по 20 - пять на три (got %d на %d)', [N, K]));
  ZoneGridSize(101, 61, 20, 20, N, K);
  Check((N = 6) and (K = 4),
    Format('ZoneGrid: остаток дает лишнюю зону по каждой оси (got %d на %d)', [N, K]));
  ZoneGridSize(10, 10, 50, 50, N, K);
  Check((N = 1) and (K = 1), Format('ZoneGrid: зона больше листа - одна (got %d на %d)', [N, K]));
  ZoneGridSize(100, 60, 20, 30, N, K);
  Check((N = 5) and (K = 2), Format('ZoneGrid: разные зоны по осям (got %d на %d)', [N, K]));
  Check(not ZoneGridSize(0, 60, 20, 20, N, K), 'ZoneGrid: нулевая ширина - отказ');
  Check(not ZoneGridSize(100, 60, 0, 20, N, K), 'ZoneGrid: нулевая зона - отказ');
  Check((N = 0) and (K = 0), 'ZoneGrid: при отказе счет обнулен');
  Writeln('');
  RectCloud := [PointD(0, 0), PointD(40, 0), PointD(40, 10), PointD(0, 10)];
  CheckClose(MinAreaRectAngle(RectCloud), 0, 'MinArea: лежачий прямоугольник - угол ноль');
  RectCloud := [PointD(0, 0), PointD(10, 0), PointD(10, 40), PointD(0, 40)];
  CheckClose(MinAreaRectAngle(RectCloud), Pi / 2, 'MinArea: стоячий прямоугольник - прямой угол');
  Angle30 := Pi / 6;
  SetLength(RectCloud, 4);
  RectCloud[0] := PointD(0, 0);
  RectCloud[1] := PointD(40 * Cos(Angle30), 40 * Sin(Angle30));
  RectCloud[2] := PointD(40 * Cos(Angle30) - 10 * Sin(Angle30),
                      40 * Sin(Angle30) + 10 * Cos(Angle30));
  RectCloud[3] := PointD(-10 * Sin(Angle30), 10 * Cos(Angle30));
  CheckClose(MinAreaRectAngle(RectCloud), Angle30, 'MinArea: поворот на 30 градусов узнан');
  RectCloud := [PointD(0, 0), PointD(40, 0), PointD(40, 10), PointD(0, 10),
             PointD(20, 5), PointD(3, 7), PointD(38, 2)];
  CheckClose(MinAreaRectAngle(RectCloud), 0, 'MinArea: внутренние точки ответа не меняют');
  Angle30 := 5 * Pi / 6;
  SetLength(RectCloud, 4);
  RectCloud[0] := PointD(0, 0);
  RectCloud[1] := PointD(40 * Cos(Angle30), 40 * Sin(Angle30));
  RectCloud[2] := PointD(40 * Cos(Angle30) - 10 * Sin(Angle30),
                      40 * Sin(Angle30) + 10 * Cos(Angle30));
  RectCloud[3] := PointD(-10 * Sin(Angle30), 10 * Cos(Angle30));
  CheckClose(MinAreaRectAngle(RectCloud), Angle30, 'MinArea: ответ приведен к [0, Pi)');
  RectCloud := [PointD(0, 0), PointD(10, 10)];
  CheckClose(MinAreaRectAngle(RectCloud), Pi / 4, 'MinArea: две точки задают направление');
  RectCloud := [PointD(0, 0), PointD(5, 0), PointD(9, 0), PointD(2, 0)];
  CheckClose(MinAreaRectAngle(RectCloud), 0, 'MinArea: коллинеарные дают направление прямой');
  Check(MinAreaRectAngle(nil) < 0, 'MinArea: пусто - отказ');
  RectCloud := [PointD(3, 4)];
  Check(MinAreaRectAngle(RectCloud) < 0, 'MinArea: одна точка - отказ');
  RectCloud := [PointD(3, 4), PointD(3, 4), PointD(3, 4), PointD(3, 4)];
  Check(MinAreaRectAngle(RectCloud) < 0, 'MinArea: все точки совпали - отказ');
  RectCloud := [PointD(0, 0), PointD(20, 0), PointD(2, 3)];
  Angle := MinAreaRectAngle(RectCloud);
  CheckClose(Angle, 0, 'MinArea: у треугольника рамка по длинной стороне');
  RectCloud := [PointD(0, 0), PointD(10, -10)];
  CheckClose(MinAreaRectAngle(RectCloud), 3 * Pi / 4,
    'MinArea: отрезок вниз приведен к [0, Pi), а не отрицателен');
  RectCloud := [PointD(0, 0), PointD(40, 0), PointD(40, 10), PointD(0, 10)];
  Angle := MinAreaRectAngle(RectCloud, Longer, Shorter);
  CheckClose(Longer, 40, 'MinArea: длинная сторона рамки');
  CheckClose(Shorter, 10, 'MinArea: короткая сторона рамки');
  Check(Longer >= Shorter, 'MinArea: длинная не меньше короткой');
  Angle30 := Pi / 6;
  SetLength(RectCloud, 4);
  RectCloud[0] := PointD(0, 0);
  RectCloud[1] := PointD(40 * Cos(Angle30), 40 * Sin(Angle30));
  RectCloud[2] := PointD(40 * Cos(Angle30) - 10 * Sin(Angle30),
                      40 * Sin(Angle30) + 10 * Cos(Angle30));
  RectCloud[3] := PointD(-10 * Sin(Angle30), 10 * Cos(Angle30));
  Angle := MinAreaRectAngle(RectCloud, Longer, Shorter);
  CheckClose(Longer, 40, 'MinArea: длинная под углом та же');
  CheckClose(Shorter, 10, 'MinArea: короткая под углом та же');
  Angle := MinAreaRectAngle(nil, Longer, Shorter);
  Check((Angle < 0) and (Longer = 0) and (Shorter = 0), 'MinArea: при отказе размеры обнулены');
  Writeln(Format('PASSED %d, FAILED %d', [Passed, Failed]));
  if Failed > 0 then
    Halt(1);
end.
