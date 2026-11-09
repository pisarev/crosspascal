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
  CheckClose(PolygonArea(Triangle), 6, 'PolygonArea: triangle (BUGFIX: the original returned 0)');
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
    'CircularMean: wrapping across zero gives zero, not Pi');
  CheckClose(CircularMean([Pi - 0.02, Pi - 0.01, Pi + 0.01, Pi + 0.02]), Pi,
    'CircularMean: without wrapping, matches the arithmetic mean');
  CheckClose(CircularMean([1.234]), 1.234, 'CircularMean: a single angle is unchanged');
  CheckClose(CircularMean([3.99, 4.0, 4.01]), 4.0,
    'CircularMean: result is normalized to [0, 2*Pi), not negative');
  Angle := CircularMean([0.0, Pi]);
  Check((Angle >= 0) and (Angle < 2 * Pi),
    Format('CircularMean: opposite angles give a result in [0,2Pi) (got %.6f)', [Angle]));
  CheckClose(CircularMean([]), 0,
    'CircularMean: empty input gives zero; see the declaration caveat');
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
  CheckClose(BB.Top, 0, 'BoundingBox Top (BUGFIX: the original float T/B used .X)');
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
  Check(PointInAnyPolygon(PointD(2, 2), [Square, Triangle]), 'PointInAnyPolygon: inside the first polygon');
  Check(PointInAnyPolygon(PointD(12, 1), [Square, Triangle]), 'PointInAnyPolygon: inside the second polygon');
  Check(not PointInAnyPolygon(PointD(7, 2), [Square, Triangle]),
    'PointInAnyPolygon: between the polygons is outside');
  Check(not PointInAnyPolygon(PointD(2, 2), []), 'PointInAnyPolygon: an empty list gives False');
  Cloud := [PointD(1, 1), PointD(2, 2), PointD(3, 3)];
  Check(PointsOnSegment(Cloud, PointD(0, 0), PointD(4, 4)), 'PointsOnSegment: all points lie on the segment');
  Cloud := [PointD(1, 1), PointD(2, 2.5), PointD(3, 3)];
  Check(not PointsOnSegment(Cloud, PointD(0, 0), PointD(4, 4)),
    'PointsOnSegment: one point off the segment gives False');
  Cloud := [PointD(1, 1), PointD(9, 9)];
  Check(not PointsOnSegment(Cloud, PointD(0, 0), PointD(4, 4)),
    'PointsOnSegment: a point beyond the endpoint gives False');
  Check(PointsOnSegment([], PointD(0, 0), PointD(4, 4)), 'PointsOnSegment: an empty set gives True');
  Check(PointsOnSegment([PointD(2, 2)], PointD(2, 2), PointD(2, 2)),
    'PointsOnSegment: a degenerate segment with a matching point');
  Check(not PointsOnSegment([PointD(2, 3)], PointD(2, 2), PointD(2, 2)),
    'PointsOnSegment: a degenerate segment with a different point');
  Poly := ClosePolygon([PointD(0, 0), PointD(4, 0), PointD(4, 4)]);
  Check(Length(Poly) = 4, 'ClosePolygon: an open polygon gains one vertex');
  CheckClose(Poly[3].X, 0, 'ClosePolygon: the last vertex matches the first in X');
  CheckClose(Poly[3].Y, 0, 'ClosePolygon: the last vertex matches the first in Y');
  Poly := ClosePolygon([PointD(0, 0), PointD(4, 0), PointD(4, 4), PointD(0, 0)]);
  Check(Length(Poly) = 4, 'ClosePolygon: an already closed polygon does not grow');
  Check(Length(ClosePolygon([])) = 0, 'ClosePolygon: empty input gives empty output');
  Cloud := [PointD(0, 0), PointD(1, 5), PointD(2, 9)];
  Poly := ReversePolyline(Cloud);
  Check(Length(Poly) = 3, 'ReversePolyline: length is preserved');
  CheckClose(Poly[0].Y, 9, 'ReversePolyline: the last point becomes the first');
  CheckClose(Poly[2].Y, 0, 'ReversePolyline: the first point becomes the last');
  CheckClose(Cloud[0].Y, 0, 'ReversePolyline: input is unchanged');
  Check(Length(ReversePolyline([])) = 0, 'ReversePolyline: empty input gives empty output');
  Check(IsInfinite(SanitizeSlope(PointD(2, 0), PointD(2, 10))),
    'SanitizeSlope: a vertical line gives Infinity');
  CheckClose(SanitizeSlope(PointD(0, 3), PointD(10, 3)), 0, 'SanitizeSlope: a horizontal line gives zero');
  CheckClose(SanitizeSlope(PointD(0, 0), PointD(2, 4)), 2, 'SanitizeSlope: an ordinary slope');
  Check(LineSlope(PointD(0, 0), PointD(10, 1e-12)) <> 0,
    'SanitizeSlope: LineSlope of a nearly horizontal line is nonzero');
  Check(SanitizeSlope(PointD(0, 0), PointD(10, 1e-12)) = 0,
    'SanitizeSlope: a nearly horizontal line gives exactly zero');
  CheckClose(SlopeToAngle(0), 0, 'SlopeToAngle: zero gives zero');
  CheckClose(SlopeToAngle(1), Pi / 4, 'SlopeToAngle: one gives 45 degrees');
  CheckClose(SlopeToAngle(Infinity), Pi / 2, 'SlopeToAngle: Infinity gives 90 degrees');
  CheckClose(AngleToSlope(0), 0, 'AngleToSlope: zero gives zero');
  CheckClose(AngleToSlope(Pi), 0, 'AngleToSlope: Pi gives exactly zero');
  CheckClose(AngleToSlope(Pi / 4), 1, 'AngleToSlope: 45 degrees gives one');
  Check(IsInfinite(AngleToSlope(Pi / 2)), 'AngleToSlope: 90 degrees gives Infinity');
  CheckClose(SlopeToAngle(AngleToSlope(Pi / 6)), Pi / 6, 'SlopeToAngle(AngleToSlope) round trip');
  C := PointD(10, 10);
  Check(QuadrantOf(C, PointD(15, 5)) = qkRightTop, 'QuadrantOf: upper right');
  Check(QuadrantOf(C, PointD(5, 5)) = qkLeftTop, 'QuadrantOf: upper left');
  Check(QuadrantOf(C, PointD(5, 15)) = qkLeftBottom, 'QuadrantOf: lower left');
  Check(QuadrantOf(C, PointD(15, 15)) = qkRightBottom, 'QuadrantOf: lower right');
  Check(QuadrantOf(C, PointD(10, 5)) = qkRightTop, 'QuadrantOf: on the vertical axis counts as right');
  Check(QuadrantOf(C, PointD(15, 10)) = qkRightBottom, 'QuadrantOf: on the horizontal axis counts as lower');
  Check(QuadrantOf(C, C) = qkRightBottom, 'QuadrantOf: the center itself');
  Half := ToPolar(C, PointD(20, 10));
  CheckClose(Half.Distance, 10, 'ToPolar: distance to the right');
  CheckClose(Half.Angle, 0, 'ToPolar: angle to the right is zero');
  Half := ToPolar(C, PointD(10, 20));
  CheckClose(Half.Distance, 10, 'ToPolar: distance downwards');
  CheckClose(Half.Angle, Pi / 2, 'ToPolar: angle downwards is 90 degrees (screen coordinates)');
  Half := ToPolar(C, PointD(0, 10));
  CheckClose(Half.Angle, Pi, 'ToPolar: angle to the left is Pi, not minus Pi');
  Half := ToPolar(C, C);
  CheckClose(Half.Distance, 0, 'ToPolar: the center has zero distance');
  P := PointD(13, 17);
  Half := ToPolar(C, P);
  P := PointAtAngleDistance(C, Half.Angle, Half.Distance);
  CheckClose(P.X, 13, 'ToPolar round trip: X');
  CheckClose(P.Y, 17, 'ToPolar round trip: Y');
  P := PointD(4, 2);
  Half := ToPolar(C, P);
  P := PointAtAngleDistance(C, Half.Angle, Half.Distance);
  CheckClose(P.X, 4, 'ToPolar round trip in another quadrant: X');
  CheckClose(P.Y, 2, 'ToPolar round trip in another quadrant: Y');
  CheckClose(CounterClockwiseAngle(qkRightTop, 0.5), 0.5, 'CCW: upper right requires no addition');
  CheckClose(CounterClockwiseAngle(qkLeftTop, 0.5), Pi + 0.5, 'CCW: upper left adds Pi');
  CheckClose(CounterClockwiseAngle(qkLeftBottom, 0.5), Pi + 0.5, 'CCW: lower left adds Pi');
  CheckClose(CounterClockwiseAngle(qkRightBottom, 0.5), 2 * Pi + 0.5,
    'CCW: lower right adds a full turn');
  CheckClose(CounterClockwiseAngle(qkLeftTop, 1.0), CounterClockwiseAngle(qkLeftBottom, 1.0),
    'CCW: both left quadrants add the same value');
  Check(RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(5, -1), PointD(5, 1), P),
    'RayLine: intersection ahead of the ray');
  CheckClose(P.X, 5, 'RayLine: X of the forward intersection');
  Check(not RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(-5, -1), PointD(-5, 1), P),
    'RayLine: intersection behind the ray gives False');
  Check(LinesIntersectionPoint(PointD(0, 0), PointD(1, 0), PointD(-5, -1), PointD(-5, 1), P),
    'RayLine: the infinite line finds that same intersection');
  Check(not RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(0, 3), PointD(4, 3), P),
    'RayLine: parallel lines give False');
  Check(RayLineIntersection(PointD(0, 0), PointD(1, 0), PointD(0, -1), PointD(0, 1), P),
    'RayLine: intersection at the ray origin gives True');
  N := LineCircleIntersection(PointD(-10, 0), PointD(10, 0), PointD(0, 0), 5, Q1, Q2);
  Check(N = 2, 'LineCircle: a secant through the center gives two points');
  CheckClose(Abs(Q1.X), 5, 'LineCircle: absolute X of the first secant point');
  CheckClose(Abs(Q2.X), 5, 'LineCircle: absolute X of the second secant point');
  N := LineCircleIntersection(PointD(-10, 5), PointD(10, 5), PointD(0, 0), 5, Q1, Q2);
  Check(N = 1, 'LineCircle: tangency gives one point');
  CheckClose(Q1.Y, 5, 'LineCircle: Y at tangency');
  CheckClose(Q1.X, Q2.X, 'LineCircle: both outputs match at tangency');
  Check(LineCircleIntersection(PointD(-10, 9), PointD(10, 9), PointD(0, 0), 5, Q1, Q2) = 0,
    'LineCircle: a miss gives zero');
  Check(LineCircleIntersection(PointD(3, 3), PointD(3, 3), PointD(0, 0), 5, Q1, Q2) = 0,
    'LineCircle: a degenerate segment gives zero');
  Check(LineCircleIntersection(PointD(-10, 0), PointD(10, 0), PointD(0, 0), 0, Q1, Q2) = 1,
    'LineCircle: zero radius through the center gives one');
  Check(LineCircleIntersection(PointD(-10, 0), PointD(10, 0), PointD(0, 0), -5, Q1, Q2) = 0,
    'LineCircle: a negative radius gives zero');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(8, 0), 5, Q1, Q2) = 2,
    'CircleCircle: intersecting circles give two points');
  Check(Distance(Q1, Q2) > 1e-6, 'CircleCircle: the two points differ');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(10, 0), 5, Q1, Q2) = 1,
    'CircleCircle: external tangency gives one point');
  CheckClose(Q1.X, 5, 'CircleCircle: X at external tangency');
  Check(CircleCircleIntersection(PointD(0, 0), 10, PointD(5, 0), 5, Q1, Q2) = 1,
    'CircleCircle: internal tangency gives one point');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(20, 0), 5, Q1, Q2) = 0,
    'CircleCircle: distant circles give zero');
  Check(CircleCircleIntersection(PointD(0, 0), 10, PointD(1, 0), 2, Q1, Q2) = 0,
    'CircleCircle: one circle inside the other gives zero');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(0, 0), 5, Q1, Q2) = 0,
    'CircleCircle: coincident circles give zero, not two arbitrary points');
  Check(CircleCircleIntersection(PointD(0, 0), 5, PointD(0, 0), 3, Q1, Q2) = 0,
    'CircleCircle: concentric circles of different radii give zero');
  Check(CircleCircleIntersection(PointD(0, 0), 0, PointD(4, 0), 4, Q1, Q2) = 1,
    'CircleCircle: zero radius on the second circle gives one point');
  Check(CircleCircleIntersection(PointD(0, 0), -5, PointD(8, 0), 5, Q1, Q2) = 0,
    'CircleCircle: a negative radius gives zero');
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
  Check(Idx > 100, Format('CircleCircle sweep: cases with intersection points (%d)', [Idx]));
  Check(Failures = 0,
    Format('CircleCircle sweep: points lie on both circles (misses %d)', [Failures]));
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
  Check(Idx > 100, Format('LineCircle sweep: cases with intersection points (%d)', [Idx]));
  Check(Failures = 0,
    Format('LineCircle sweep: points lie on the circle and line (misses %d)', [Failures]));
  Cloud := [PointD(0, 0), PointD(10, 0), PointD(0, 10)];
  Poly := ShearPoints(Cloud, Pi / 4, 0);
  CheckClose(Poly[0].X, 0, 'ShearPoints: the origin stays in place');
  CheckClose(Poly[1].X, 10, 'ShearPoints: a point on the X axis does not move');
  CheckClose(Poly[2].X, 10, 'ShearPoints: a point on the Y axis moves by tan*Y');
  CheckClose(Poly[2].Y, 10, 'ShearPoints: Y is unchanged when shearing only along X');
  CheckClose(Cloud[2].X, 0, 'ShearPoints: input is unchanged');
  Poly := ShearPoints(ShearPoints(Cloud, 0.3, 0), -0.3, 0);
  CheckClose(Poly[2].X, 0, 'ShearPoints round trip along one axis: X');
  CheckClose(Poly[2].Y, 10, 'ShearPoints round trip along one axis: Y');
  Poly := ShearPoints(ShearPoints(Cloud, 0.3, 0.3), -0.3, -0.3);
  CheckClose(Poly[2].X, 0, 'ShearPoints: with both axes, X still returns');
  Check(Abs(Poly[2].Y - 10) > 1e-6, 'ShearPoints: with both axes, Y does NOT return');
  Check(Length(ShearPoints([], 0.3, 0)) = 0, 'ShearPoints: empty input gives empty output');
  Cloud := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10)];
  Poly := ScalePointsAboutMeanPoint(Cloud, 2);
  CheckClose(Poly[0].X, -5, 'ScalePoints: a corner moves twice as far in X');
  CheckClose(Poly[0].Y, -5, 'ScalePoints: a corner moves twice as far in Y');
  CheckClose(MeanPoint(Poly).X, 5, 'ScalePoints: the mean point does not move in X');
  CheckClose(MeanPoint(Poly).Y, 5, 'ScalePoints: the mean point does not move in Y');
  Poly := ScalePointsAboutMeanPoint(ScalePointsAboutMeanPoint(Cloud, 3), 1 / 3);
  CheckClose(Poly[2].X, 10, 'ScalePoints round trip: X');
  CheckClose(Poly[2].Y, 10, 'ScalePoints round trip: Y');
  Poly := ScalePointsAboutMeanPoint(Cloud, 0);
  CheckClose(Poly[0].X, 5, 'ScalePoints: a zero factor collapses all points to the mean');
  Check(Length(ScalePointsAboutMeanPoint([], 2)) = 0, 'ScalePoints: empty input gives empty output');
  Poly := TurnPointsAboutMeanPoint(Cloud, Pi / 2);
  CheckClose(MeanPoint(Poly).X, 5, 'TurnPoints: the mean point does not move');
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
  CheckClose(Poly[0].X, 0, 'TurnPoints: four quarter turns restore the original X');
  CheckClose(Poly[0].Y, 0, 'TurnPoints: four quarter turns restore the original Y');
  Check(Length(TurnPointsAboutMeanPoint([], 1)) = 0, 'TurnPoints: empty input gives empty output');
  Poly := TurnPointsAboutMeanPoint(Cloud, 0.7);
  Hull := RotatePoints(Cloud, 0.7, MeanPoint(Cloud));
  CheckClose(Poly[1].X, Hull[1].X, 'TurnPoints: matches RotatePoints with an explicit center, X');
  CheckClose(Poly[1].Y, Hull[1].Y, 'TurnPoints: matches RotatePoints with an explicit center, Y');
  Cloud := [PointD(0, 0), PointD(1, 0), PointD(2, 0), PointD(9, 0), PointD(0, 9)];
  Check(Abs(MeanPoint(Cloud).X - PolygonCentroid(Cloud).X) > 0.5,
    'TurnPoints: the chosen set has DIFFERENT mean point and centroid');
  Poly := TurnPointsAboutMeanPoint(Cloud, Pi / 2);
  Hull := RotatePoints(Cloud, Pi / 2, MeanPoint(Cloud));
  CheckClose(Poly[3].X, Hull[3].X, 'TurnPoints: the pivot is specifically the mean point');
  Base := Rect(10, 10, 20, 20);
  Check(RectRelativeAlignment(Base, Rect(0, 0, 5, 5)) = akTL, 'Alignment: upper left');
  Check(RectRelativeAlignment(Base, Rect(25, 0, 30, 5)) = akTR, 'Alignment: upper right');
  Check(RectRelativeAlignment(Base, Rect(0, 25, 5, 30)) = akLB, 'Alignment: lower left');
  Check(RectRelativeAlignment(Base, Rect(25, 25, 30, 30)) = akRB, 'Alignment: lower right');
  Check(RectRelativeAlignment(Base, Rect(12, 0, 18, 5)) = akT, 'Alignment: above');
  Check(RectRelativeAlignment(Base, Rect(12, 25, 18, 30)) = akB, 'Alignment: below');
  Check(RectRelativeAlignment(Base, Rect(0, 12, 5, 18)) = akL, 'Alignment: left');
  Check(RectRelativeAlignment(Base, Rect(25, 12, 30, 18)) = akR, 'Alignment: right');
  Check(RectRelativeAlignment(Base, Rect(12, 12, 18, 18)) = akNone, 'Alignment: inside gives no alignment');
  Check(RectRelativeAlignment(Base, Rect(0, 12, 10, 18)) = akL,
    'Alignment: touching the left edge already counts as left');
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
  Check(Idx = 1024, Format('Alignment sweep: cases completed (%d, expected 1024)', [Idx]));
  Check(Mismatches = 0,
    Format('Alignment: matches the literal original on all pairs (differences %d)', [Mismatches]));
  SecondIdx := Rect(25, 12, 5, 18);
  Check(RectRelativeAlignment(Base, SecondIdx) = akNone,
    'Alignment: inverted input is normalized and covers the base');
  Check(ReferenceCases(Base, SecondIdx) = akL,
    'Alignment: the literal original says left for that input; documented difference');
  Base := Rect(0, 0, 10, 10);
  Check(RectsWithinMargin(Base, Rect(5, 5, 15, 15), 0, 0), 'WithinMargin: overlapping rectangles give True');
  Check(not RectsWithinMargin(Base, Rect(20, 0, 30, 10), 0, 0),
    'WithinMargin: distant rectangles give False');
  Check(RectsWithinMargin(Base, Rect(15, 0, 25, 10), 3, 0),
    'WithinMargin: gap 5 with margin 3 gives True because BOTH expand');
  Check(not RectsWithinMargin(Base, Rect(15, 0, 25, 10), 2, 0),
    'WithinMargin: gap 5 with margin 2 gives False');
  Check(not RectsWithinMargin(Base, Rect(16, 0, 26, 10), 3, 0),
    'WithinMargin: gap exactly twice the margin is contact and gives False');
  Check(RectsWithinMargin(Base, Rect(16, 0, 26, 10), 4, 0),
    'WithinMargin: the same gap with margin 4 gives True');
  Check(not RectsWithinMargin(Base, Rect(0, 20, 10, 30), 20, 0),
    'WithinMargin: a generous X margin does not bridge the Y gap');
  Check(RectsWithinMargin(Base, Rect(0, 20, 10, 30), 0, 6),
    'WithinMargin: a Y margin bridges that same gap');
  Check(not RectsWithinMargin(Rect(0, 20, 10, 30), Rect(0, 0, 10, 10), 20, 0),
    'WithinMargin: a generous X margin does not reach the neighbor above');
  Check(RectsWithinMargin(Rect(0, 20, 10, 30), Rect(0, 0, 10, 10), 0, 6),
    'WithinMargin: a Y margin reaches the neighbor above');
  Check(RectsWithinMargin(Base, Rect(15, 15, 5, 5), 0, 0),
    'WithinMargin: inverted input is normalized');
  Check(LargestTileSizeForCount(10, 10, 4, N, Idx), 'TileSize: a solution is found');
  Check((10 div N) * (10 div Idx) >= 4, 'TileSize: tile count is at least the requested count');
  Check(N * Idx = 25, Format('TileSize: maximum possible area, 5x5 (got %dx%d)', [N, Idx]));
  Check(LargestTileSizeForCount(7, 3, 1, N, Idx), 'TileSize: a single tile is found');
  Check(N * Idx = 21, Format('TileSize: one tile occupies the entire source (got %dx%d)', [N, Idx]));
  Check(not LargestTileSizeForCount(4, 4, 100, N, Idx), 'TileSize: too many tiles gives False');
  Check(N = 0, Format('TileSize: failure resets the width to zero (got %d)', [N]));
  Check(not LargestTileSizeForCount(0, 10, 1, N, Idx), 'TileSize: a zero source gives False');
  Check(not LargestTileSizeForCount(10, 10, 0, N, Idx), 'TileSize: zero tiles gives False');
  Check(LargestTileSizeForCount(10, 10, 3, N, Idx), 'TileSize: three tiles have a solution');
  Check(N * Idx = 30, Format('TileSize: each axis loses its remainder, 30 (got %dx%d)', [N, Idx]));
  Check(LargestTileSizeForCount(12, 2, 6, N, Idx), 'TileSize: a narrow strip has a solution');
  Check((12 div N) * (2 div Idx) >= 6, 'TileSize: a narrow strip contains enough tiles');
  N := 0;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0, N, Point(0, 0));
  Check((Pt.X = 1) and (Pt.Y = 0), 'NextOnRay: to the right gives the adjacent pixel');
  Check(N = 1, Format('NextOnRay: distance increases to 1 (got %d)', [N]));
  N := 0;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0.05, N, Point(0, 0));
  Check((Pt.X <> 0) or (Pt.Y <> 0), 'NextOnRay: a shallow ray still advances');
  Check(N >= 1, 'NextOnRay: distance increases');
  N := 0;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0, N, Point(1, 0));
  Check((Pt.X = 2) and (Pt.Y = 0), 'NextOnRay: a step matching the previous point is skipped');
  Check(N = 2, Format('NextOnRay: distance skips past the matching step (got %d)', [N]));
  Second := NextDistinctPointOnRay(PointD(0, 0), 0.05, N, Pt);
  Check((Second.X <> Pt.X) or (Second.Y <> Pt.Y), 'NextOnRay: the next point differs from the previous one');
  N := 7;
  Pt := NextDistinctPointOnRay(PointD(0, 0), 0 / 0.0, N, Point(3, 3));
  Check((Pt.X = 3) and (Pt.Y = 3), 'NextOnRay: NaN leaves the point unchanged');
  Check(N = 7, Format('NextOnRay: NaN leaves distance unchanged (got %d)', [N]));
  Square := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10), PointD(0, 0)];
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(15, 5), Square, csInside);
  Check(Length(Pieces) = 1, Format('ClipSegment: one inner piece (got %d)', [Length(Pieces)]));
  if Length(Pieces) = 1 then
  begin
    CheckClose(Pieces[0][0].X, 0, 'ClipSegment: the inner piece starts at the boundary');
    CheckClose(Pieces[0][1].X, 10, 'ClipSegment: and ends at the opposite boundary');
  end;
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(15, 5), Square, csOutside);
  Check(Length(Pieces) = 2, Format('ClipSegment: two outer pieces (got %d)', [Length(Pieces)]));
  Pieces := ClipSegmentByPolygon(PointD(2, 5), PointD(8, 5), Square, csInside);
  Check(Length(Pieces) = 1, 'ClipSegment: a segment entirely inside gives one piece');
  if Length(Pieces) = 1 then
    CheckClose(Pieces[0][0].X, 2, 'ClipSegment: the piece starts at the segment origin');
  Pieces := ClipSegmentByPolygon(PointD(20, 5), PointD(30, 5), Square, csInside);
  Check(Length(Pieces) = 0, 'ClipSegment: a segment entirely outside gives no inner pieces');
  Pieces := ClipSegmentByPolygon(PointD(20, 5), PointD(30, 5), Square, csOutside);
  Check(Length(Pieces) = 1, 'ClipSegment: a segment entirely outside gives one outer piece');
  Check(Length(ClipSegmentByPolygon(PointD(0, 0), PointD(9, 9), [PointD(1, 1)], csInside)) = 0,
    'ClipSegment: one vertex gives empty output');
  Poly := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10)];
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(5, 5), Poly, csInside);
  Check(Length(Pieces) = 1, 'ClipSegment: open input still gives one piece');
  CheckClose(Pieces[0][0].X, -5,
    'ClipSegment: without the closing edge the left boundary is NOT found; starts at origin');
  Pieces := ClipSegmentByPolygon(PointD(-5, 5), PointD(5, 5), ClosePolygon(Poly), csInside);
  CheckClose(Pieces[0][0].X, 0, 'ClipSegment: ClosePolygon makes the left boundary detectable');
  Rays := BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, Pi / 180);
  Check(Length(Rays) = 360, Format('RadialScan: a full circle gives 360 rays (got %d)', [Length(Rays)]));
  Check((Length(Rays) > 0) and (Length(Rays[0]) = 2), 'RadialScan: a ray has exactly two points');
  if Length(Rays) > 0 then
  begin
    CheckClose(Rays[0][0].X, 50, 'RadialScan: the ray starts at the center in X');
    CheckClose(Rays[0][0].Y, 50, 'RadialScan: the ray starts at the center in Y');
  end;
  Rays := BuildRadialScanLines(PointD(50, 50), 101, 101, 0, Pi / 4, Pi / 2);
  Check(Length(Rays) = 1, 'RadialScan: one step gives one ray');
  C := RayEnd(0, 101, 101);
  CheckClose(C.X, 100, 'RadialScan: angle 0 reaches the right edge');
  CheckClose(C.Y, 50, 'RadialScan: angle 0 runs horizontally');
  C := RayEnd(Pi / 2, 101, 101);
  CheckClose(C.Y, 0, 'RadialScan: a quarter turn reaches the TOP edge');
  CheckClose(C.X, 50, 'RadialScan: a quarter turn runs vertically');
  C := RayEnd(Pi, 101, 101);
  CheckClose(C.X, 0, 'RadialScan: a half turn reaches the left edge');
  C := RayEnd(3 * Pi / 2, 101, 101);
  CheckClose(C.Y, 100, 'RadialScan: three quarter turns reach the BOTTOM edge');
  C := RayEnd(7 * Pi / 4, 101, 101);
  CheckClose(C.X, 100, 'RadialScan: a diagonal reaches the lower right corner in X');
  CheckClose(C.Y, 100, 'RadialScan: a diagonal reaches the lower right corner in Y');
  C := RayEnd(0, 21, 11);
  CheckClose(C.X, 20, 'RadialScan: a wide image has its right edge at 20, not 10');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 0, Pi / 2)) = 0,
    'RadialScan: an empty interval gives no rays');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, Pi / 2, Pi / 2)) = 1,
    'RadialScan: the upper bound is exclusive; one ray, not two');
  Check(Length(BuildRadialScanLines(PointD(500, 500), 101, 101, 0, 2 * Pi, Pi / 180)) = 0,
    'RadialScan: a center outside the image gives no rays');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 0, 101, 0, 2 * Pi, Pi / 180)) = 0,
    'RadialScan: zero width gives empty output');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, 0)) = 0,
    'RadialScan: zero step gives empty output, not an infinite loop');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, -1)) = 0,
    'RadialScan: a negative step gives empty output');
  Check(Length(BuildRadialScanLines(PointD(50, 50), 101, 101, 0 / 0.0, 2 * Pi, Pi / 180)) = 0,
    'RadialScan: a NaN angle gives empty output');
  Rays := BuildRadialScanLines(PointD(50, 50), 101, 101, 0, 2 * Pi, Pi / 180);
  Failures := 0;
  for I := 0 to High(Rays) do
    if not ((Abs(Rays[I][1].X) < 1e-6) or (Abs(Rays[I][1].X - 100) < 1e-6) or
      (Abs(Rays[I][1].Y) < 1e-6) or (Abs(Rays[I][1].Y - 100) < 1e-6)) then
        Inc(Failures);
  Check(Failures = 0, Format('RadialScan: all endpoints lie on an edge (misses %d)', [Failures]));
  Mismatches := 0;
  for I := 0 to High(Rays) do
  begin
    C := PointD(Rays[I][1].X - 50, Rays[I][1].Y - 50);
    if Abs(AngularDifference(ArcTan2(-C.Y, C.X), I * Pi / 180)) > 1e-6 then
      Inc(Mismatches);
  end;
  Check(Mismatches = 0, Format('RadialScan: direction matches the angle (misses %d)', [Mismatches]));
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
  Check(Length(Ribbon) = 7, Format('Ribbon: three and three give seven vertices (got %d)', [Length(Ribbon)]));
  CheckClose(Ribbon[0].X, 0, 'Ribbon: starts at the first point of the left edge');
  CheckClose(Ribbon[2].X, 10, 'Ribbon: the left edge is traversed FORWARDS');
  CheckClose(Ribbon[3].X, 10, 'Ribbon: the right edge starts at its END');
  CheckClose(Ribbon[3].Y, 4, 'Ribbon: this is the right edge, not the left');
  CheckClose(Ribbon[5].X, 0, 'Ribbon: the right edge is traversed BACKWARDS');
  CheckClose(Ribbon[6].X, Ribbon[0].X, 'Ribbon: the contour is closed in X');
  CheckClose(Ribbon[6].Y, Ribbon[0].Y, 'Ribbon: the contour is closed in Y');
  CheckClose(PolygonArea(Ribbon), 40, 'Ribbon: area matches a rectangle, not a figure eight');
  Ribbon := BuildRibbonPolygon([PointD(0, 0), PointD(10, 0)], [PointD(0, 4), PointD(10, 4)]);
  Check(Length(Ribbon) = 5, Format('Ribbon: two and two give five vertices (got %d)', [Length(Ribbon)]));
  CheckClose(PolygonArea(Ribbon), 40, 'Ribbon: the smallest ribbon has the same area');
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
  Check(Length(Ribbon) = 7, Format('Ribbon: four and two give seven vertices (got %d)', [Length(Ribbon)]));
  CheckClose(Ribbon[4].Y, 4, 'Ribbon: four and two start the right edge at its end');
  CheckClose(PolygonArea(Ribbon), 40, 'Ribbon: four and two have the same area');
  Ribbon := BuildRibbonPolygon([PointD(0, 0), PointD(10, 0)], [PointD(0, 0), PointD(10, 4)]);
  Check(Length(Ribbon) = 4,
    Format('Ribbon: closed input does not duplicate the vertex (got %d)', [Length(Ribbon)]));
  if Length(Ribbon) = 4 then
  begin
    CheckClose(Ribbon[3].X, Ribbon[0].X, 'Ribbon: closed input still gives a contour closed in X');
    CheckClose(Ribbon[3].Y, Ribbon[0].Y, 'Ribbon: and also in Y');
  end;
  Check(Length(BuildRibbonPolygon([PointD(0, 0)], [PointD(0, 4), PointD(10, 4)])) = 0,
    'Ribbon: one point on the left gives empty output');
  Check(Length(BuildRibbonPolygon([PointD(0, 0), PointD(10, 0)], [])) = 0,
    'Ribbon: an empty right edge gives empty output');
  Check(FitSizePreserveAspect(100, 50, 10, 10, fkContain, N, K),
    'Fit: a wide image fits inside a square');
  Check((N = 10) and (K = 5), Format('Fit: containing a wide image gives 10 by 5 (got %d by %d)', [N, K]));
  Check(FitSizePreserveAspect(100, 50, 10, 10, fkCover, N, K), 'Fit: a wide image covers a square');
  Check((N = 20) and (K = 10),
    Format('Fit: covering with a wide image gives 20 by 10 (got %d by %d)', [N, K]));
  FitSizePreserveAspect(50, 100, 10, 10, fkContain, N, K);
  Check((N = 5) and (K = 10), Format('Fit: containing a tall image gives 5 by 10 (got %d by %d)', [N, K]));
  FitSizePreserveAspect(50, 100, 10, 10, fkCover, N, K);
  Check((N = 10) and (K = 20),
    Format('Fit: covering with a tall image gives 10 by 20 (got %d by %d)', [N, K]));
  FitSizePreserveAspect(100, 50, 20, 10, fkContain, N, K);
  Check((N = 20) and (K = 10),
    Format('Fit: matching ratios fill the box when contained (got %d by %d)', [N, K]));
  FitSizePreserveAspect(100, 50, 20, 10, fkCover, N, K);
  Check((N = 20) and (K = 10),
    Format('Fit: matching ratios fill the box when covering (got %d by %d)', [N, K]));
  FitSizePreserveAspect(100, 50, 30, 30, fkContain, N, K);
  Check((N = 30) and (K = 15), Format('Fit: 100x50 inside 30x30 (got %d by %d)', [N, K]));
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
  Check(Failures = 0, Format('Fit: the contained size stays inside the box (misses %d)', [Failures]));
  Check(Mismatches = 0, Format('Fit: the covering size is at least the box size (misses %d)', [Mismatches]));
  Check(not FitSizePreserveAspect(100, 0, 10, 10, fkContain, N, K),
    'Fit: zero source height fails without division by zero');
  Check((N = 0) and (K = 0), 'Fit: failure resets the size instead of retaining the previous value');
  Check(not FitSizePreserveAspect(0, 50, 10, 10, fkContain, N, K), 'Fit: zero source width fails');
  Check(not FitSizePreserveAspect(-100, -50, 10, 10, fkContain, N, K),
    'Fit: two negative source dimensions fail instead of giving 20 by 10');
  Check(not FitSizePreserveAspect(0, 0, 10, 10, fkContain, N, K),
    'Fit: a zero by zero source fails');
  Check(not FitSizePreserveAspect(100, 50, 0, 10, fkContain, N, K), 'Fit: a zero box fails');
  Check(not FitSizePreserveAspect(100, 50, -3, 10, fkContain, N, K), 'Fit: an inverted box fails');
  Check(not FitSizePreserveAspect(1000, 1, 5, 5, fkContain, N, K),
    'Fit: rounding down to zero fails instead of returning a zero dimension');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 1), PointD(9, 9), 2),
    'MeetByEnds: start meets start');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(9, 9), PointD(0, 1), 2),
    'MeetByEnds: start meets end');
  Check(SegmentsMeetByEnds(PointD(10, 0), PointD(0, 0), PointD(0, 1), PointD(9, 9), 2),
    'MeetByEnds: end meets start');
  Check(SegmentsMeetByEnds(PointD(10, 0), PointD(0, 0), PointD(9, 9), PointD(0, 1), 2),
    'MeetByEnds: end meets end');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 2), PointD(50, 50), 2),
    'MeetByEnds: one pair exactly at the threshold meets');
  Check(not SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 20), PointD(10, 20), 2),
    'MeetByEnds: distant endpoints do not meet');
  Check(SegmentsMeetByEnds(PointD(0, 0), PointD(10, 0), PointD(0, 2), PointD(10, 2), 2),
    'MeetByEnds: endpoints exactly at the threshold meet');
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 10), PointD(0, 0)],
              [PointD(0, 0), PointD(20, 0)]];
  Orientations := [soHorizontal, soVertical, soHorizontal];
  Triples := FindBracketTriples(Segments, Orientations, 2);
  Check(Length(Triples) = 1, Format('Bracket: one U-shaped bracket is found (got %d)', [Length(Triples)]));
  if Length(Triples) = 1 then
  begin
    Check(Triples[0].A = 0, 'Bracket: the first side comes first');
    Check(Triples[0].B = 1, 'Bracket: the transverse side comes second');
    Check(Triples[0].C = 2, 'Bracket: the other outer side comes third');
  end;
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 0), PointD(0, 10)],
              [PointD(0, 0), PointD(20, 0)]];
  Triples := FindBracketTriples(Segments, Orientations, 2);
  Check(Length(Triples) = 1, Format('Bracket: a reversed transverse side still gives one triple (got %d)', [Length(Triples)]));
  if Length(Triples) = 1 then
  begin
    Check((Triples[0].A = 2) and (Triples[0].B = 1) and (Triples[0].C = 0),
      Format('Bracket: the same triple listed from the other end (%d,%d,%d)',
        [Triples[0].A, Triples[0].B, Triples[0].C]));
  end;
  if Length(Triples) = 1 then
  begin
    Check(Triples[0].A = 2, 'Bracket: with reversed traversal, the LOWER outer side is first');
    Check(Triples[0].C = 0, 'Bracket: with reversed traversal, the UPPER outer side is third');
  end;
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(0, 10), PointD(0, 0)]];
  Check(Length(FindBracketTriples(Segments, [soHorizontal, soVertical], 2)) = 0,
    'Bracket: two sides are insufficient');
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 10), PointD(0, 0)],
              [PointD(0, 0), PointD(20, 0)]];
  Check(Length(FindBracketTriples(Segments, [soOther, soVertical, soHorizontal], 2)) = 0,
    'Bracket: a slanted outer side gives no triple');
  Check(Length(FindBracketTriples(Segments, [soOther, soVertical, soOther], 2)) = 0,
    'Bracket: two slanted outer sides give no triple');
  Segments := [[PointD(0, 10), PointD(20, 10)],
              [PointD(0, 10), PointD(0, 0)],
              [PointD(0, 0), PointD(20, 0)],
              [PointD(50, 50), PointD(70, 50)]];
  Check(Length(FindBracketTriples(Segments, Orientations, 2)) = 0,
    'Bracket: different array lengths give empty output even when a bracket exists');
  SetLength(Samples, 5);
  for I := 0 to 4 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Check(SpanWidth(Samples[0]) = 3, 'SpanWidth: from 10 to 12 gives three');
  Samples[2].First := -1;
  Check(SpanWidth(Samples[2]) = 0, 'SpanWidth: no measurement gives zero');
  Check(MeanSpanWidth(Samples, N) and (N = 3), Format('MeanSpanWidth: three (got %d)', [N]));
  Samples[3].Last := 20;
  Check(MeanSpanWidth(Samples, N) and (N = 5),
    Format('MeanSpanWidth: missing measurements do not lower the mean (got %d)', [N]));
  SetLength(Samples, 2);
  Samples[0].First := -1;
  Samples[0].Last := -1;
  Samples[1].First := -1;
  Samples[1].Last := -1;
  Check(not MeanSpanWidth(Samples, N), 'MeanSpanWidth: no valid measurements fails');
  SetLength(Samples, 10);
  for I := 0 to 9 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[4].Last := 20;
  Bulges := FindSpanBulges(Samples, 3, 1.2);
  Check(Length(Bulges) = 1, Format('Bulges: one bulge (got %d)', [Length(Bulges)]));
  if Length(Bulges) = 1 then
    Check(Bulges[0] = 4, Format('Bulges: the bulge is at position 4 (got %d)', [Bulges[0]]));
  Check(Length(FindSpanBulges(Samples, 0, 1.2)) = 0, 'Bulges: no mean width gives empty output');
  Samples[4].Last := 13;
  Check(Length(FindSpanBulges(Samples, 3, 1.2)) = 0, 'Bulges: exactly at the threshold is NOT a bulge');
  Samples[4].Last := 14;
  Bulges := FindSpanBulges(Samples, 3, 1.2);
  Check(Length(Bulges) = 1, 'Bulges: above the threshold is a bulge');
  if Length(Bulges) = 1 then
    Check(Bulges[0] = 4,
      Format('Bulges: above the threshold, the bulge is at position 4 (got %d)', [Bulges[0]]));
  Samples[4].Last := 12;
  Check(Length(FindSpanBulges(Samples, 3, 1.2)) = 0, 'Bulges: a uniform line has no bulges');
  SetLength(Samples, 100);
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2), 'Classify: a uniform thin line is a ruling');
  Spared := 0;
  for I := 0 to 99 do if Samples[I].Spare then Inc(Spared);
  Check(Spared = 0, Format('Classify: a uniform ruling has nothing to spare (got %d)', [Spared]));
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 23;
    Samples[I].Spare := False;
  end;
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: a line that is too thick is not a ruling');
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 21;
    Samples[I].Spare := False;
  end;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: width EXACTLY at the limit is still a ruling');
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 22;
    Samples[I].Spare := False;
  end;
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: one unit thicker than the limit is not a ruling');
  SetLength(Samples, 101);
  for I := 0 to 100 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[50].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: long uniform sections outweigh the bulge');
  Check(Samples[50].Spare, 'Classify: the bulge itself is spared');
  Check(Samples[45].Spare, 'Classify: its neighborhood within MaxWidth is also spared');
  Check(not Samples[20].Spare, 'Classify: the middle of a long uniform section is not spared');
  SetLength(Samples, 100);
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
    if I mod 20 = 10 then Samples[I].Last := 20;
  end;
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: frequent bulges indicate text, not a ruling');
  Spared := 0;
  for I := 0 to 99 do if Samples[I].Spare then Inc(Spared);
  Check(Spared = 100, Format('Classify: all text is spared (got %d)', [Spared]));
  SetLength(Samples, 60);
  for I := 0 to 59 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[55].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: a long section BEFORE the first bulge also counts');
  SetLength(Samples, 100);
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[98].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: a bulge at the end is outweighed by the long section');
  Check(Samples[99].Spare, 'Classify: the last measurement is spared');
  Check(Samples[91].Spare, 'Classify: the start of the neighborhood is also spared');
  Check(not Samples[89].Spare, 'Classify: beyond the neighborhood is not spared');
  for I := 0 to 99 do
  begin
    Samples[I].First := 10;
    Samples[I].Last := 12;
    Samples[I].Spare := False;
  end;
  Samples[1].Last := 20;
  Check(ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: a bulge at the start is outweighed by the long section');
  Check(Samples[0].Spare, 'Classify: the first measurement is spared');
  Check(not Samples[11].Spare, 'Classify: beyond the neighborhood is not spared');
  SetLength(Samples, 0);
  Check(not ClassifyRuledLine(Samples, 8, 50, 40, 1.5, 1.2),
    'Classify: an empty measurement is not a ruling');
  Border.Found := True;
  Border.FromAngle := 0.2;
  Border.LastAngle := 0.4;
  Border.Slip := 1;
  CheckClose(BorderAngleValue(Border), 0.3, 'BorderAngle: midpoint of the interval');
  Border.FromAngle := -0.4;
  Border.LastAngle := -0.2;
  CheckClose(BorderAngleValue(Border), -0.3, 'BorderAngle: also for negative values');
  Border.Found := False;
  CheckClose(BorderAngleValue(Border), 0, 'BorderAngle: a missing boundary gives zero');
  Border.Found := True;
  Border.FromAngle := 0;
  Border.LastAngle := 0;
  CheckClose(BorderAngleValue(Border), 0, 'BorderAngle: a level boundary also gives zero');
  Check(Border.Found, 'BorderAngle: a level boundary has Found=True, which distinguishes it');
  Border.Found := True;
  Border.Slip := 1.0;
  SecondBorder.Found := True;
  SecondBorder.Slip := 0.5;
  Check(ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: the conflict is resolved');
  Check(not Border.Found, 'Arbitrate: the boundary with the LARGER slip is discarded');
  Check(SecondBorder.Found, 'Arbitrate: the boundary with the smaller slip remains');
  Border.Found := True;
  Border.Slip := 0.25;
  SecondBorder.Found := True;
  SecondBorder.Slip := 1.0;
  Check(ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: the mirrored conflict is resolved');
  Check(Border.Found, 'Arbitrate: in the mirrored case the first boundary remains');
  Check(not SecondBorder.Found, 'Arbitrate: in the mirrored case the second boundary is discarded');
  Border.Found := True;
  Border.Slip := 0.5;
  SecondBorder.Found := True;
  SecondBorder.Slip := 0.5;
  Check(not ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: equal slips do not conflict');
  Check(Border.Found and SecondBorder.Found, 'Arbitrate: both boundaries remain');
  SecondBorder.Slip := 0.5 + 1e-12;
  Check(not ArbitrateOppositeBorders(Border, SecondBorder), 'Arbitrate: nearly equal slips do not conflict');
  Border.Found := False;
  Border.Slip := 1.0;
  SecondBorder.Found := True;
  SecondBorder.Slip := 0.5;
  Check(not ArbitrateOppositeBorders(Border, SecondBorder),
    'Arbitrate: a missing boundary does not conflict');
  Check(SecondBorder.Found, 'Arbitrate: the found boundary is unaffected');
  Angles := [0.1, 9.9];
  Kept := RejectSkewOutliers(Angles, 0.01);
  Check(Length(Kept) = 2, 'RejectOutliers: two angles remain unchanged');
  if Length(Kept) = 2 then
  begin
    CheckClose(Kept[0], 0.1, 'RejectOutliers: the first angle is unchanged');
    CheckClose(Kept[1], 9.9, 'RejectOutliers: the second angle is unchanged');
  end;
  Angles := [7.7];
  Kept := RejectSkewOutliers(Angles, 0.01);
  Check(Length(Kept) = 1, 'RejectOutliers: a single angle remains unchanged');
  if Length(Kept) = 1 then
    CheckClose(Kept[0], 7.7, 'RejectOutliers: its value is unchanged');
  Check(Length(RejectSkewOutliers(nil, 0.01)) = 0, 'RejectOutliers: empty input gives empty output');
  Angles := [5.0, 5.0, 5.1];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 0,
    Format('RejectOutliers: no consistent large angles survive (got %d)', [Length(Kept)]));
  Angles := [0.10, 0.11, 0.12];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 3,
    Format('RejectOutliers: three consistent small angles survive (got %d)', [Length(Kept)]));
  if Length(Kept) = 3 then
  begin
    CheckClose(Kept[0], 0.10, 'RejectOutliers: the first of three angles is unchanged');
    CheckClose(Kept[1], 0.11, 'RejectOutliers: the second of three angles is unchanged');
    CheckClose(Kept[2], 0.12, 'RejectOutliers: the third of three angles is unchanged');
  end;
  Angles := [0.1, 0.2, 9.0];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 2, Format('RejectOutliers: a distant angle saves the small ones, but not itself (got %d)', [Length(Kept)]));
  if Length(Kept) = 2 then
    Check((Kept[0] < 1) and (Kept[1] < 1),
      'RejectOutliers: specifically the small angles survive, not an arbitrary pair');
  Angles := [1.0, 1.0, 5.0];
  Kept := RejectSkewOutliers(Angles, 0.5);
  Check(Length(Kept) = 2,
    Format('RejectOutliers: spread saves the unit angles (got %d)', [Length(Kept)]));
  Angles := [0.1, 0.2, 9.0];
  Kept := RejectSkewOutliers(Angles, 0);
  Check(Length(Kept) = 2,
    Format('RejectOutliers: small angles survive with zero tolerance (got %d)', [Length(Kept)]));
  Kept := RejectSkewOutliers(Angles, -0.001);
  Check(Length(Kept) = 0,
    Format('RejectOutliers: negative tolerance rejects all angles (got %d)', [Length(Kept)]));
  Angles := [0.10, 0.11, 0.12];
  Kept := RejectSkewOutliers(Angles, 0.5);
  if Length(Kept) = 3 then
    Check((Kept[0] < Kept[1]) and (Kept[1] < Kept[2]),
      'RejectOutliers: surviving angles retain their order');
  Angles := [0.2, 0.4, 0.6];
  Check(CombineSkewAngles(Angles, spMean, 1, Skew), 'Combine: mean succeeds');
  CheckClose(Skew, 0.4, 'Combine: mean of three angles');
  Check(CombineSkewAngles(Angles, spMaximum, 1, Skew), 'Combine: maximum succeeds');
  CheckClose(Skew, 0.6, 'Combine: maximum of three angles');
  Angles := [0.2, -0.9, 0.6];
  CombineSkewAngles(Angles, spMaximum, 1, Skew);
  CheckClose(Skew, -0.9, 'Combine: the maximum is by ABSOLUTE VALUE and retains its sign');
  CombineSkewAngles(Angles, spMean, 1, Skew);
  CheckClose(Skew, -0.1 / 3 * 1, 'Combine: mean includes signs');
  Skew := 7;
  Check(not CombineSkewAngles([0.5, 0.5], spMean, 3, Skew),
    'Combine: two angles are insufficient when three are required');
  CheckClose(Skew, 0, 'Combine: failure resets the skew to zero');
  Check(not CombineSkewAngles(nil, spMean, 1, Skew), 'Combine: empty input fails');
  Check(CombineSkewAngles([0.5, 0.5], spMean, 2, Skew), 'Combine: exactly the required count is sufficient');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(25, 10), PointD(50, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 10, 5);
  Check(Length(MergedLines) = 1, Format('Merge: two pieces join into one (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].X, 0, 'Merge: the joined line starts at the left edge');
    CheckClose(MergedLines[0][1].X, 50, 'Merge: and ends at the right edge');
    CheckClose(MergedLines[0][0].Y, 10, 'Merge: the transverse coordinate is the midpoint of the first line');
  end;
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(45, 10), PointD(50, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 2,
    'Merge: a gap exceeding tolerance prevents joining');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(21, 30), PointD(50, 30)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 2,
    'Merge: different heights prevent joining');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(25, 12), PointD(50, 12)]];
  MergedLines := MergeCollinearLines(Segments, True, 3, 10, 5);
  Check(Length(MergedLines) = 1, 'Merge: heights differing within tolerance allow joining');
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].Y, 10, 'Merge: one endpoint is at the height of the first line');
    CheckClose(MergedLines[0][1].Y, 12,
      'Merge: the other is at the height of the second; the joined line is SLANTED');
  end;
  Segments := [[PointD(0, 10), PointD(3, 10)], [PointD(5, 10), PointD(8, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 50)) = 2,
    'Merge: a join shorter than the limit leaves the inputs unchanged');
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 1,
    'Merge: the same input joins with a smaller limit');
  Segments := [[PointD(0, 10), PointD(10, 10)], [PointD(15, 10), PointD(25, 10)],
              [PointD(30, 10), PointD(40, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 10, 5);
  Check(Length(MergedLines) = 1, Format('Merge: three pieces join into one (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
    CheckClose(MergedLines[0][1].X, 40, 'Merge: the line joined from three pieces reaches the far edge');
  Segments := [[PointD(0, 10), PointD(50, 10)], [PointD(10, 10), PointD(20, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 0, 5);
  Check(Length(MergedLines) = 1,
    Format('Merge: the nested line is absorbed (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].X, 0, 'Merge: the long line survives, not the short one');
    CheckClose(MergedLines[0][1].X, 50, 'Merge: the entire long line survives');
  end;
  Segments := [[PointD(10, 10), PointD(20, 10)], [PointD(0, 12), PointD(50, 12)]];
  MergedLines := MergeCollinearLines(Segments, True, 3, 0, 5);
  Check(Length(MergedLines) = 1, 'Merge: a nested line at a different height still gives one line');
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].Y, 12, 'Merge: the ENTIRE survivor is at the height of the long line');
    CheckClose(MergedLines[0][1].Y, 12, 'Merge: the second endpoint is also at that height; no slant');
  end;
  Segments := [[PointD(10, 10), PointD(20, 10)], [PointD(0, 10), PointD(50, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 0, 5);
  Check(Length(MergedLines) = 1, 'Merge: the nested line is also absorbed in reverse order');
  if Length(MergedLines) = 1 then
    CheckClose(MergedLines[0][1].X - MergedLines[0][0].X, 50,
      'Merge: the long line survives in reverse order too');
  Segments := [[PointD(0, 10), PointD(30, 10)], [PointD(20, 10), PointD(50, 10)]];
  MergedLines := MergeCollinearLines(Segments, True, 2, 0, 5);
  Check(Length(MergedLines) = 1, 'Merge: overlapping lines merge into one');
  if Length(MergedLines) = 1 then
    CheckClose(MergedLines[0][1].X - MergedLines[0][0].X, 50, 'Merge: the merged line spans both inputs');
  Segments := [[PointD(10, 0), PointD(10, 20)], [PointD(10, 25), PointD(10, 50)]];
  MergedLines := MergeCollinearLines(Segments, False, 2, 10, 5);
  Check(Length(MergedLines) = 1, Format('Merge: vertical lines join (got %d)', [Length(MergedLines)]));
  if Length(MergedLines) = 1 then
  begin
    CheckClose(MergedLines[0][0].Y, 0, 'Merge: the vertical line starts at the top');
    CheckClose(MergedLines[0][1].Y, 50, 'Merge: and reaches the bottom');
  end;
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 2,
    'Merge: treating vertical lines as horizontal prevents joining');
  Check(Length(MergeCollinearLines(nil, True, 2, 10, 5)) = 0, 'Merge: empty input gives empty output');
  Segments := [[PointD(0, 10), PointD(20, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, 2, 10, 5)) = 1,
    'Merge: a single line remains a single line');
  Segments := [[PointD(0, 10), PointD(20, 10)], [PointD(25, 10), PointD(50, 10)]];
  Check(Length(MergeCollinearLines(Segments, True, -1, 10, 5)) = 0,
    'Merge: negative transverse tolerance fails');
  Check(Length(MergeCollinearLines(Segments, True, 2, -1, 5)) = 0, 'Merge: a negative gap fails');
  Contour := [PointD(0, 0), PointD(50, 0), PointD(50, 40), PointD(0, 40), PointD(0, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals);
  Check(N = 4, Format('AxisLines: a rectangle has four sides (got %d)', [N]));
  Check(Length(Horizontals) = 2, Format('AxisLines: two horizontal lines (got %d)', [Length(Horizontals)]));
  Check(Length(Verticals) = 2, Format('AxisLines: two vertical lines (got %d)', [Length(Verticals)]));
  if Length(Horizontals) = 2 then
  begin
    CheckClose(Horizontals[0][0].X, 0, 'AxisLines: the first horizontal line starts at zero');
    CheckClose(Horizontals[0][1].X, 50, 'AxisLines: and ends at fifty');
    CheckClose(Horizontals[0][0].Y, 0, 'AxisLines: it is specifically the top line');
  end;
  if Length(Verticals) = 2 then
    CheckClose(Verticals[0][0].X, 50, 'AxisLines: the first vertical line is on the right');
  Contour := [PointD(0, 0), PointD(50, 30), PointD(20, 60), PointD(0, 0)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: a slanted contour has no axis-aligned lines');
  Check((Length(Horizontals) = 0) and (Length(Verticals) = 0),
    'AxisLines: both arrays are empty, with no stale entries');
  Contour := [PointD(0, 0), PointD(50, 5)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: a slope outside tolerance is not axis-aligned');
  Check(ExtractAxisLinesFromContour(Contour, 0.15, 10, 5, Horizontals, Verticals) = 1,
    'AxisLines: the same slope is axis-aligned with a larger tolerance');
  Contour := [PointD(0, 0), PointD(5, 0)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: a short side is excluded');
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 3, 5, Horizontals, Verticals) = 1,
    'AxisLines: that same side is included with a smaller length limit');
  Contour := [PointD(0, 0), PointD(2, 0), PointD(4, 0), PointD(6, 0), PointD(50, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals);
  Check(N = 1, Format('AxisLines: small steps do not fragment a line (got %d)', [N]));
  if Length(Horizontals) = 1 then
  begin
    CheckClose(Horizontals[0][0].X, 0, 'AxisLines: the line starts at the very beginning');
    CheckClose(Horizontals[0][1].X, 50, 'AxisLines: and reaches the very end');
  end;
  Contour := [PointD(0, 0), PointD(20, 12), PointD(24, 12), PointD(50, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 40, Horizontals, Verticals);
  Check(N >= 1, Format('AxisLines: lookahead finds an axis-aligned line (got %d)', [N]));
  Contour := [PointD(0, 0), PointD(20, 12), PointD(5, 0), PointD(50, 0)];
  N := ExtractAxisLinesFromContour(Contour, 0.05, 10, 40, Horizontals, Verticals);
  Check(N >= 1, Format('AxisLines: lookahead past a short segment finds an axis-aligned line (got %d)', [N]));
  if Length(Horizontals) >= 1 then
    CheckClose(Horizontals[0][1].X, 50,
      'AxisLines: the LONG line is taken, not the fragment ending at the fifth point');
  Contour := [PointD(0, 0), PointD(20, 12), PointD(24, 12), PointD(50, 0)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 2, Horizontals, Verticals) = 0,
    'AxisLines: a small gap limit prevents lookahead from reaching the line');
  Check(ExtractAxisLinesFromContour(nil, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: an empty contour gives zero');
  Contour := [PointD(7, 7)];
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: one point gives zero');
  Contour := [PointD(0, 0), PointD(50, 0)];
  Check(ExtractAxisLinesFromContour(Contour, -1, 10, 5, Horizontals, Verticals) = 0,
    'AxisLines: a negative angle tolerance fails');
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 0, 5, Horizontals, Verticals) = 0,
    'AxisLines: a zero length limit fails');
  Check(ExtractAxisLinesFromContour(Contour, 0.05, 10, -1, Horizontals, Verticals) = 0,
    'AxisLines: a negative gap fails');
  RR := NormalizeRect(RectD(30, 40, 10, 20));
  CheckClose(RR.Left, 10, 'Normalize: left becomes the smaller value');
  CheckClose(RR.Right, 30, 'Normalize: right becomes the larger value');
  CheckClose(RR.Top, 20, 'Normalize: top becomes the smaller value');
  CheckClose(RR.Bottom, 40, 'Normalize: bottom becomes the larger value');
  RR := NormalizeRect(RectD(10, 20, 30, 40));
  Check((RR.Left = 10) and (RR.Right = 30) and (RR.Top = 20) and (RR.Bottom = 40),
    'Normalize: ordered input is unchanged');
  CheckClose(RectHeight(RectD(10, 20, 30, 45)), 25, 'RectHeight: height is 25');
  CheckClose(RectHeight(RectD(10, 45, 30, 20)), -25,
    'RectHeight: an inverted rectangle has NEGATIVE height, not an absolute value');
  Check(RectIsEmpty(RectD(10, 20, 10, 45)), 'RectIsEmpty: zero width is empty');
  Check(RectIsEmpty(RectD(10, 20, 30, 20)), 'RectIsEmpty: zero height is empty');
  Check(not RectIsEmpty(RectD(10, 20, 30, 45)), 'RectIsEmpty: a valid rectangle is not empty');
  Check(RectIsEmpty(RectD(30, 20, 10, 45)), 'RectIsEmpty: a rectangle inverted in X is empty');
  Square := [PointD(0, 0), PointD(10, 0), PointD(10, 10), PointD(0, 10)];
  Check(PolygonSignedArea(Square) <> 0, 'SignedArea: a square has nonzero area');
  CheckClose(Abs(PolygonSignedArea(Square)), 100, 'SignedArea: its absolute area is one hundred');
  CheckClose(PolygonSignedArea(ReversePolyline(Square)), -PolygonSignedArea(Square),
    'SignedArea: reverse traversal gives the opposite SIGN');
  CheckClose(PolygonSignedArea([PointD(0, 0), PointD(10, 0)]), 0,
    'SignedArea: a segment has no area');
  R1 := RectD(0, 0, 10, 10);
  R2 := RectD(15, 0, 25, 10);
  Check(RectsCloserThan(R1, R2, 6), 'CloserThan: gap 5 with tolerance 6 is close enough');
  Check(not RectsCloserThan(R1, R2, 4), 'CloserThan: the same gap with tolerance 4 is not close enough');
  Check(RectsCloserThan(R1, R2, 5),
    'CloserThan: exactly at tolerance is close enough; threshold is inclusive');
  Check(RectsCloserThan(R1, RectD(5, 5, 15, 15), 0),
    'CloserThan: overlapping rectangles qualify with zero tolerance');
  CheckClose(WrapAngle180(0.3), 0.3, 'Wrap180: an in-range angle stays unchanged');
  CheckClose(WrapAngle180(Pi + 0.3), 0.3, 'Wrap180: an angle beyond Pi wraps');
  CheckClose(WrapAngle180(-0.3), Pi - 0.3, 'Wrap180: a negative angle wraps UPWARDS');
  CheckClose(WrapAngle180(2 * Pi + 0.3), 0.3, 'Wrap180: two turns also wrap');
  CheckClose(WrapAngle180(Pi), 0, 'Wrap180: exactly Pi gives zero; the interval is HALF-OPEN');
  Check(RotatedBoundingSize(100, 40, 0, N, K), 'RotBounds: succeeds');
  Check((N = 100) and (K = 40), Format('RotBounds: zero degrees preserves the size (got %d by %d)', [N, K]));
  RotatedBoundingSize(100, 40, Pi / 2, N, K);
  Check((N = 40) and (K = 100),
    Format('RotBounds: a quarter turn swaps the dimensions (got %d by %d)', [N, K]));
  RotatedBoundingSize(100, 40, Pi, N, K);
  Check((N = 100) and (K = 40), Format('RotBounds: a half turn preserves the size (got %d by %d)', [N, K]));
  RotatedBoundingSize(100, 40, Pi / 4, N, K);
  Check(K > 40, Format('RotBounds: an oblique frame is TALLER than the source (got %d)', [K]));
  Check(N < 100, Format('RotBounds: and NARROWER than the source (got %d)', [N]));
  CheckClose(N, K, 'RotBounds: at 45 degrees the dimensions are equal');
  RotatedBoundingSize(100, 40, 0.3, N, K);
  RotatedBoundingSize(100, 40, -0.3, I, J);
  Check((N = I) and (K = J), 'RotBounds: the angle sign does not change the bounds');
  Check(not RotatedBoundingSize(0, 40, 0.3, N, K), 'RotBounds: zero width fails');
  Check((N = 0) and (K = 0), 'RotBounds: failure resets both dimensions');
  Check(not RotatedBoundingSize(100, 40, 0 / 0.0, N, K), 'RotBounds: a NaN angle fails');
  Pt := InverseRotateMapPoint(Point(70, 30), Point(50, 20), Point(60, 25), qkRightTop, 0);
  Check((Pt.X = 60) and (Pt.Y = 25),
    Format('InvRotate: a zero angle translates the centers (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(60, 25), Point(50, 20), Point(60, 25), qkRightTop, 0.3);
  Check((Pt.X = 50) and (Pt.Y = 20),
    Format('InvRotate: the target center maps to the source center (got %d,%d)',
      [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(60, 25), Point(50, 20), Point(60, 25), qkLeftBottom, -0.7);
  Check((Pt.X = 50) and (Pt.Y = 20),
    'InvRotate: another quadrant and angle also map center to center');
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkRightTop, 0.4);
  Check((Pt.X = 65) and (Pt.Y = 10),
    Format('InvRotate: upper right gives 65,10 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkLeftTop, 0.4);
  Check((Pt.X = 47) and (Pt.Y = 38),
    Format('InvRotate: upper left gives 47,38 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkLeftBottom, 0.4);
  Check((Pt.X = 35) and (Pt.Y = 30),
    Format('InvRotate: lower left gives 35,30 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 10), Point(50, 20), Point(60, 25), qkRightBottom, 0.4);
  Check((Pt.X = 53) and (Pt.Y = 2),
    Format('InvRotate: lower right gives 53,2 (got %d,%d)', [Pt.X, Pt.Y]));
  Pt := InverseRotateMapPoint(Point(70, 30), Point(50, 20), Point(60, 25), qkRightTop, 1e-12);
  Check((Pt.X = 60) and (Pt.Y = 25), 'InvRotate: a nearly zero angle also translates');
  Second := InverseRotateMapPoint(Point(70, 30), Point(50, 20), Point(60, 25), qkRightTop, 0.5);
  Check((Second.X <> Pt.X) or (Second.Y <> Pt.Y), 'InvRotate: beyond the threshold, rotation is calculated');
  Check(ZoneGridSize(100, 60, 20, 20, N, K), 'ZoneGrid: succeeds');
  Check((N = 5) and (K = 3),
    Format('ZoneGrid: 100 by 60 with size 20 gives five by three (got %d by %d)', [N, K]));
  ZoneGridSize(101, 61, 20, 20, N, K);
  Check((N = 6) and (K = 4),
    Format('ZoneGrid: a remainder adds one zone along each axis (got %d by %d)', [N, K]));
  ZoneGridSize(10, 10, 50, 50, N, K);
  Check((N = 1) and (K = 1),
    Format('ZoneGrid: a zone larger than the page gives one zone (got %d by %d)', [N, K]));
  ZoneGridSize(100, 60, 20, 30, N, K);
  Check((N = 5) and (K = 2), Format('ZoneGrid: different zone sizes along the axes (got %d by %d)', [N, K]));
  Check(not ZoneGridSize(0, 60, 20, 20, N, K), 'ZoneGrid: zero width fails');
  Check(not ZoneGridSize(100, 60, 0, 20, N, K), 'ZoneGrid: a zero zone size fails');
  Check((N = 0) and (K = 0), 'ZoneGrid: failure resets the counts');
  Writeln('');
  RectCloud := [PointD(0, 0), PointD(40, 0), PointD(40, 10), PointD(0, 10)];
  CheckClose(MinAreaRectAngle(RectCloud), 0, 'MinArea: a horizontal rectangle has zero angle');
  RectCloud := [PointD(0, 0), PointD(10, 0), PointD(10, 40), PointD(0, 40)];
  CheckClose(MinAreaRectAngle(RectCloud), Pi / 2, 'MinArea: a vertical rectangle has a right angle');
  Angle30 := Pi / 6;
  SetLength(RectCloud, 4);
  RectCloud[0] := PointD(0, 0);
  RectCloud[1] := PointD(40 * Cos(Angle30), 40 * Sin(Angle30));
  RectCloud[2] := PointD(40 * Cos(Angle30) - 10 * Sin(Angle30),
                      40 * Sin(Angle30) + 10 * Cos(Angle30));
  RectCloud[3] := PointD(-10 * Sin(Angle30), 10 * Cos(Angle30));
  CheckClose(MinAreaRectAngle(RectCloud), Angle30, 'MinArea: a 30-degree rotation is recognized');
  RectCloud := [PointD(0, 0), PointD(40, 0), PointD(40, 10), PointD(0, 10),
             PointD(20, 5), PointD(3, 7), PointD(38, 2)];
  CheckClose(MinAreaRectAngle(RectCloud), 0, 'MinArea: interior points do not change the answer');
  Angle30 := 5 * Pi / 6;
  SetLength(RectCloud, 4);
  RectCloud[0] := PointD(0, 0);
  RectCloud[1] := PointD(40 * Cos(Angle30), 40 * Sin(Angle30));
  RectCloud[2] := PointD(40 * Cos(Angle30) - 10 * Sin(Angle30),
                      40 * Sin(Angle30) + 10 * Cos(Angle30));
  RectCloud[3] := PointD(-10 * Sin(Angle30), 10 * Cos(Angle30));
  CheckClose(MinAreaRectAngle(RectCloud), Angle30, 'MinArea: the answer is normalized to [0, Pi)');
  RectCloud := [PointD(0, 0), PointD(10, 10)];
  CheckClose(MinAreaRectAngle(RectCloud), Pi / 4, 'MinArea: two points define a direction');
  RectCloud := [PointD(0, 0), PointD(5, 0), PointD(9, 0), PointD(2, 0)];
  CheckClose(MinAreaRectAngle(RectCloud), 0, 'MinArea: collinear points give the line direction');
  Check(MinAreaRectAngle(nil) < 0, 'MinArea: empty input fails');
  RectCloud := [PointD(3, 4)];
  Check(MinAreaRectAngle(RectCloud) < 0, 'MinArea: one point fails');
  RectCloud := [PointD(3, 4), PointD(3, 4), PointD(3, 4), PointD(3, 4)];
  Check(MinAreaRectAngle(RectCloud) < 0, 'MinArea: all coincident points fail');
  RectCloud := [PointD(0, 0), PointD(20, 0), PointD(2, 3)];
  Angle := MinAreaRectAngle(RectCloud);
  CheckClose(Angle, 0, 'MinArea: a triangle has its frame along the long side');
  RectCloud := [PointD(0, 0), PointD(10, -10)];
  CheckClose(MinAreaRectAngle(RectCloud), 3 * Pi / 4,
    'MinArea: a downward segment is normalized to [0, Pi), not negative');
  RectCloud := [PointD(0, 0), PointD(40, 0), PointD(40, 10), PointD(0, 10)];
  Angle := MinAreaRectAngle(RectCloud, Longer, Shorter);
  CheckClose(Longer, 40, 'MinArea: the long side of the frame');
  CheckClose(Shorter, 10, 'MinArea: the short side of the frame');
  Check(Longer >= Shorter, 'MinArea: the long side is at least as long as the short side');
  Angle30 := Pi / 6;
  SetLength(RectCloud, 4);
  RectCloud[0] := PointD(0, 0);
  RectCloud[1] := PointD(40 * Cos(Angle30), 40 * Sin(Angle30));
  RectCloud[2] := PointD(40 * Cos(Angle30) - 10 * Sin(Angle30),
                      40 * Sin(Angle30) + 10 * Cos(Angle30));
  RectCloud[3] := PointD(-10 * Sin(Angle30), 10 * Cos(Angle30));
  Angle := MinAreaRectAngle(RectCloud, Longer, Shorter);
  CheckClose(Longer, 40, 'MinArea: rotation preserves the long side');
  CheckClose(Shorter, 10, 'MinArea: rotation preserves the short side');
  Angle := MinAreaRectAngle(nil, Longer, Shorter);
  Check((Angle < 0) and (Longer = 0) and (Shorter = 0), 'MinArea: failure resets both dimensions');
  Writeln(Format('PASSED %d, FAILED %d', [Passed, Failed]));
  if Failed > 0 then
    Halt(1);
end.
