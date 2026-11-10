{ ************************************************************************** }
{                                                                            }
{ CrossVision.Curve                                                          }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

{ SPDX-License-Identifier: MPL-1.1
  Original Code: CrossFPC-Common CompareCurve/GetOverlap. Initial Developer: Yuriy Pisarev.
  Original copyright (c) 2025 Yuriy Pisarev. See licenses/MPL-1.1.txt.
  This file is a CrossPascal adaptation. See licenses/CROSSFPCCOMMON-NOTICE.md. }

unit CrossVision.Curve;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  CrossVision.Geometry.Types;

type
  TPolyline = TArray<TPointI>;

  TPolylineArray = TArray<TPolyline>;

  TCurveStitchParam = record
    MaxGap: Double;
    MaxAngleDeg: Double;
    LookAhead: Integer;
    Passes: Integer;
    AngleWeight: Double;
    CheckCrossing: Boolean;
    SkipCrossPts: Integer;
    CloseLoops: Boolean;
    class function Make(const AMaxGap: Double): TCurveStitchParam; static;
  end;

function StitchCurveFragments(const Fragments: TPolylineArray;
  const Param: TCurveStitchParam): TPolylineArray;

function UnionCurves(const Curves: TPolylineArray; const MaxGap: Double): TPolylineArray;

function CatmullRomPoint(const P0, P1, P2, P3: TPointI; const T: Double): TPointI;

function CatmullRomPointD(const P0, P1, P2, P3: TPointI; const T: Double): TPointD;

function SmoothPolylineCatmullRom(const PointArray: TPolyline; const SmoothFactor: Double): TPolyline;

function QuadraticBezierPoint(const A, B, C: TPointI; const T: Double): TPointI;

function QuadraticBezierCurve(const A, B, C: TPointI; const Steps: Integer): TPolyline;

function PolylineLength(const C: TPolyline): Double;

function RasterizeSegment(const A, B: TPointI): TPolyline;

function ResamplePolyline(const PointArray: TPolyline; const Size: Integer): TPolyline;

function IndexAtArcLength(const Curve: TPolyline; const StartIndex: Integer; Distance: Double;
  const Epsilon: Double = 1e-3): Integer;

function DensifySparsePolyline(const PointArray: TPolyline): TPolyline;

function PolylineAngleProfile(const PointArray: TPolyline; const Radius: Integer): TArray<Double>;

function DetectCornerIndices(const Source: TPolyline; const Sensitivity: Double): TArray<Integer>;

function SplitPolylineAtIndices(const Polyline: TPolyline; const Indices: TArray<Integer>): TPolylineArray;

function DynamicTimeWarpingCost(const A, B: TArray<Double>): Double;

type
  TRepairKind = (rkDuplicates, rkNearPoint, rkNearChord, rkSpike, rkBacktrack, rkCluster);
  TRepairKinds = set of TRepairKind;

  TRepairParam = record
    Kinds: TRepairKinds;
    SpikePerp: Double;
    SpikePerpHard: Double;
    SpikeCos: Double;
    BacktrackMargin: Double;
    ClusterStep: Double;
    ClusterCos: Double;
    class function Make(const AKinds: TRepairKinds; const ASpikePerp: Double = 1.75;
      const ASpikePerpHard: Double = 3; const ASpikeCos: Double = 0.5; const ABacktrackMargin: Double = 0.15;
      const AClusterStep: Double = 0.2; const AClusterCos: Double = 0.85): TRepairParam; static;
  end;

function RepairPolyline(const PointArray: TPolyline; const Param: TRepairParam): TPolyline;

function ResampleLineByEndpoints(const PointArray: TPolyline; const NewSize: Integer): TPolyline;

function DistanceFactorTortuosity(const C: TPolyline): Double;

function SmoothPolylineGaussian(const PointArray: TPolyline; const Factor: Double): TPolyline;

function Make4Connected(const PointArray: TPolyline): TPolyline;

function StraightenPolyline(const PointArray: TPolyline; const Threshold: Double;
  const Connect4: Boolean): TPolyline;

function UntwistPolyline(const PointArray: TPolyline; const Radius: Double;
  const Connect4: Boolean): TPolyline;

function BuildCrossSections(const PointArray: TPolyline; const AngleArray: TArray<Double>;
  const Angle: Double; const Radius: Integer): TPolylineArray;

type
  TCurveMetric = (cmHausdorff, cmDtw);

function HausdorffDistance(const A, B: TPolyline): Double;

function CompareCurveShapes(const A, B: TPolyline; const Metric: TCurveMetric): Double;

function AngleVariationTortuosity(const C: TPolyline; const Radius: Integer): Double;

type
  TOverlapParam = record
    Radius: Integer;
    AngleTolerance: Double;
    class function Make(const Width, Height: Integer): TOverlapParam; static;
  end;

function PolylineOverlapScore(const A, B: TPolylineArray;
  const Width, Height: Integer): Double; overload;
function PolylineOverlapScore(const A, B: TPolylineArray; const Width, Height: Integer;
  const Param: TOverlapParam): Double; overload;

implementation

uses
  {$IFDEF FPC}
  Types, Math, Generics.Collections, Generics.Defaults,
  {$ELSE}
  System.Types, System.Math, System.Generics.Collections, System.Generics.Defaults,
  {$ENDIF}
  CrossVision.Geometry;

type
  TEndKind = (ekStart, ekEnd);

  TEndpoint = record
    Curve: Integer;
    Kind: TEndKind;
    P: TPointI;
    Dir: TPointD;
  end;

  TStitchCandidate = record
    A: Integer;
    B: Integer;
    Score: Double;
  end;

function VecDot(const A, B: TPointD): Double;
begin
  Result := A.X * B.X + A.Y * B.Y;
end;

function VecNorm(const V: TPointD): Double;
begin
  Result := Sqrt(V.X * V.X + V.Y * V.Y);
end;

function VecUnit(const V: TPointD): TPointD;
var
  N: Double;
begin
  N := VecNorm(V);
  if N <= 1e-9 then
    Result := PointD(0, 0)
  else
    Result := PointD(V.X / N, V.Y / N);
end;

function AngleBetween(const A, B: TPointD): Double;
begin
  Result := ArcCos(EnsureRange(VecDot(A, B), -1.0, 1.0));
end;

function SamePoint(const A, B: TPointI): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

function PointDistSqr(const A, B: TPointI): Double;
var
  Dx, Dy: Double;
begin
  Dx := A.X - B.X;
  Dy := A.Y - B.Y;
  Result := Dx * Dx + Dy * Dy;
end;

procedure RemoveConsecutiveDups(var C: TPolyline);
var
  I, K: Integer;
begin
  if Length(C) < 2 then Exit;
  K := 1;
  for I := 1 to High(C) do
    if not SamePoint(C[I], C[K - 1]) then
    begin
      if K <> I then C[K] := C[I];
      Inc(K);
    end;
  SetLength(C, K);
end;

procedure ReverseCurve(var C: TPolyline);
var
  I, J: Integer;
  T: TPointI;
begin
  I := 0;
  J := High(C);
  while I < J do
  begin
    T := C[I];
    C[I] := C[J];
    C[J] := T;
    Inc(I);
    Dec(J);
  end;
end;

procedure AppendBridge(var C: TPolyline; const A, B: TPointI);
var
  X0, Y0, X1, Y1, Dx, Dy, Sx, Sy, Err, E2, K: Integer;
  P: TPointI;
begin
  X0 := A.X;
  Y0 := A.Y;
  X1 := B.X;
  Y1 := B.Y;
  Dx := Abs(X1 - X0);
  Dy := Abs(Y1 - Y0);
  Sx := 1;
  if X0 > X1 then Sx := -1;
  Sy := 1;
  if Y0 > Y1 then Sy := -1;
  Err := Dx - Dy;
  while not ((X0 = X1) and (Y0 = Y1)) do
  begin
    E2 := 2 * Err;
    if E2 > -Dy then
    begin
      Err := Err - Dy;
      X0 := X0 + Sx;
    end;
    if E2 < Dx then
    begin
      Err := Err + Dx;
      Y0 := Y0 + Sy;
    end;
    P := Point(X0, Y0);
    if SamePoint(P, A) then Continue;
    K := Length(C);
    SetLength(C, K + 1);
    C[K] := P;
  end;
end;

procedure AppendPoints(var Dst: TPolyline; const Src: TPolyline);
var
  N, M: Integer;
begin
  M := Length(Src);
  if M = 0 then Exit;
  N := Length(Dst);
  SetLength(Dst, N + M);
  Move(Src[0], Dst[N], M * SizeOf(TPointI));
end;

type
  TCurveStitcher = class
  private
    FParam: TCurveStitchParam;
    FCurves: TPolylineArray;
    FAlive: TArray<Byte>;
    FEnds: TArray<TEndpoint>;
    function OutwardDir(const C: TPolyline; const Kind: TEndKind): TPointD;
    procedure AddEndpoint(const CurveIdx: Integer; const Kind: TEndKind);
    function BridgeHitsAnyCurve(const A, B: TPointI): Boolean;
    function BuildCandidate(const EA, EB: Integer; out Cand: TStitchCandidate): Boolean;
    procedure MergeByEndpoints(const EA, EB: Integer);
    procedure TryCloseLoop(const CurveIdx: Integer);
  public
    function Stitch(const Fragments: TPolylineArray; const Param: TCurveStitchParam): TPolylineArray;
  end;

function TCurveStitcher.OutwardDir(const C: TPolyline; const Kind: TEndKind): TPointD;
var
  N, K, I0, I1: Integer;
begin
  Result := PointD(0, 0);
  N := Length(C);
  if N < 2 then Exit;
  K := FParam.LookAhead;
  if K < 1 then K := 1;
  if K > N - 1 then K := N - 1;
  if Kind = ekStart then
  begin
    I0 := 0;
    I1 := K;
  end
  else begin
    I0 := N - 1;
    I1 := N - 1 - K;
  end;
  Result := VecUnit(PointD(C[I0].X - C[I1].X, C[I0].Y - C[I1].Y));
end;

procedure TCurveStitcher.AddEndpoint(const CurveIdx: Integer; const Kind: TEndKind);
var
  E, N: Integer;
begin
  N := Length(FCurves[CurveIdx]);
  if N < 2 then Exit;
  E := Length(FEnds);
  SetLength(FEnds, E + 1);
  FEnds[E].Curve := CurveIdx;
  FEnds[E].Kind := Kind;
  if Kind = ekStart then
    FEnds[E].P := FCurves[CurveIdx][0]
  else
    FEnds[E].P := FCurves[CurveIdx][N - 1];
  FEnds[E].Dir := OutwardDir(FCurves[CurveIdx], Kind);
end;

function TCurveStitcher.BridgeHitsAnyCurve(const A, B: TPointI): Boolean;
var
  Ci, I0, I1, I: Integer;
  S0, S1: TPointI;
begin
  Result := False;
  for Ci := 0 to High(FCurves) do
  begin
    if FAlive[Ci] = 0 then Continue;
    if Length(FCurves[Ci]) < 2 then Continue;
    I0 := FParam.SkipCrossPts;
    I1 := High(FCurves[Ci]) - FParam.SkipCrossPts;
    if I0 < 0 then I0 := 0;
    if I1 > High(FCurves[Ci]) - 1 then I1 := High(FCurves[Ci]) - 1;
    if I1 < I0 then Continue;
    for I := I0 to I1 do
    begin
      S0 := FCurves[Ci][I];
      S1 := FCurves[Ci][I + 1];
      if SamePoint(S0, A) or SamePoint(S1, A) or SamePoint(S0, B) or SamePoint(S1, B) then
        Continue;
      if SegmentsIntersect(A, B, S0, S1) then
        Exit(True);
    end;
  end;
end;

function TCurveStitcher.BuildCandidate(const EA, EB: Integer; out Cand: TStitchCandidate): Boolean;
var
  Pa, Pb: TPointI;
  D2, D, MaxAng, Ang1, Ang2: Double;
  U: TPointD;
begin
  Result := False;
  Pa := FEnds[EA].P;
  Pb := FEnds[EB].P;
  D2 := PointDistSqr(Pa, Pb);
  if D2 < 1e-9 then Exit;
  if D2 > FParam.MaxGap * FParam.MaxGap then Exit;
  if (VecNorm(FEnds[EA].Dir) < 0.5) or (VecNorm(FEnds[EB].Dir) < 0.5) then Exit;
  D := Sqrt(D2);
  U := VecUnit(PointD(Pb.X - Pa.X, Pb.Y - Pa.Y));
  MaxAng := DegToRad(FParam.MaxAngleDeg);
  Ang1 := AngleBetween(FEnds[EA].Dir, U);
  Ang2 := AngleBetween(FEnds[EB].Dir, PointD(-U.X, -U.Y));
  if (Ang1 > MaxAng) or (Ang2 > MaxAng) then Exit;
  if FParam.CheckCrossing then
    if BridgeHitsAnyCurve(Pa, Pb) then Exit;
  Cand.A := EA;
  Cand.B := EB;
  Cand.Score := D + FParam.AngleWeight * (Ang1 + Ang2);
  Result := True;
end;

procedure TCurveStitcher.MergeByEndpoints(const EA, EB: Integer);
var
  Ia, Ib, NA, AddLen: Integer;
  Ka, Kb: TEndKind;
  ACurve, BCurve: TPolyline;
  Pa, Pb: TPointI;
begin
  Ia := FEnds[EA].Curve;
  Ib := FEnds[EB].Curve;
  Ka := FEnds[EA].Kind;
  Kb := FEnds[EB].Kind;
  if (FAlive[Ia] = 0) or (FAlive[Ib] = 0) then Exit;
  if Ia = Ib then Exit;
  ACurve := FCurves[Ia];
  BCurve := FCurves[Ib];
  if Ka = ekStart then ReverseCurve(ACurve);
  if Kb = ekEnd then ReverseCurve(BCurve);
  Pa := ACurve[High(ACurve)];
  Pb := BCurve[0];
  if not SamePoint(Pa, Pb) then
    AppendBridge(ACurve, Pa, Pb);
  if Length(BCurve) > 1 then
  begin
    NA := Length(ACurve);
    AddLen := Length(BCurve) - 1;
    SetLength(ACurve, NA + AddLen);
    Move(BCurve[1], ACurve[NA], AddLen * SizeOf(TPointI));
  end;
  RemoveConsecutiveDups(ACurve);
  FCurves[Ia] := ACurve;
  FCurves[Ib] := nil;
  FAlive[Ib] := 0;
end;

procedure TCurveStitcher.TryCloseLoop(const CurveIdx: Integer);
var
  C: TPolyline;
  A, B: TPointI;
  D2, MaxAng, Ang1, Ang2: Double;
  DirA, DirB, U: TPointD;
begin
  if not FParam.CloseLoops then Exit;
  if FAlive[CurveIdx] = 0 then Exit;
  C := FCurves[CurveIdx];
  if Length(C) < 4 then Exit;
  A := C[0];
  B := C[High(C)];
  D2 := PointDistSqr(A, B);
  if D2 > FParam.MaxGap * FParam.MaxGap then Exit;
  DirA := OutwardDir(C, ekStart);
  DirB := OutwardDir(C, ekEnd);
  if (VecNorm(DirA) < 0.5) or (VecNorm(DirB) < 0.5) then Exit;
  U := VecUnit(PointD(A.X - B.X, A.Y - B.Y));
  MaxAng := DegToRad(FParam.MaxAngleDeg);
  Ang1 := AngleBetween(DirB, U);
  Ang2 := AngleBetween(DirA, PointD(-U.X, -U.Y));
  if (Ang1 > MaxAng) or (Ang2 > MaxAng) then Exit;
  if FParam.CheckCrossing then
    if BridgeHitsAnyCurve(B, A) then Exit;
  if not SamePoint(B, A) then
  begin
    AppendBridge(C, B, A);
    RemoveConsecutiveDups(C);
    FCurves[CurveIdx] := C;
  end;
end;

function StitchCandidateLess(const A, B: TStitchCandidate): Boolean; inline;
begin
  Result := A.Score < B.Score;
end;

procedure SortStitchCandidates(var Items: TArray<TStitchCandidate>; const Min, Max: Integer);
var
  I, J: Integer;
  Pivot, Swap: TStitchCandidate;
begin
  I := Min;
  J := Max;
  Pivot := Items[(Min + Max) shr 1];
  repeat
    while StitchCandidateLess(Items[I], Pivot) do Inc(I);
    while StitchCandidateLess(Pivot, Items[J]) do Dec(J);
    if I <= J then
    begin
      if I < J then
      begin
        Swap := Items[I];
        Items[I] := Items[J];
        Items[J] := Swap;
      end;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if Min < J then SortStitchCandidates(Items, Min, J);
  if I < Max then SortStitchCandidates(Items, I, Max);
end;

function TCurveStitcher.Stitch(const Fragments: TPolylineArray;
  const Param: TCurveStitchParam): TPolylineArray;
var
  I, J, K, Pass, EA, EB, Merged, AliveCount: Integer;
  Cand: TStitchCandidate;
  Cands, Accepted: TArray<TStitchCandidate>;
  BestIdx: TArray<Integer>;
  BestScore: TArray<Double>;
  UsedCurve: TArray<Byte>;
begin
  FParam := Param;
  SetLength(FCurves, Length(Fragments));
  for I := 0 to High(Fragments) do
    FCurves[I] := Copy(Fragments[I]);
  SetLength(FAlive, Length(FCurves));
  for I := 0 to High(FCurves) do
  begin
    FAlive[I] := 1;
    if Length(FCurves[I]) > 1 then
    begin
      RemoveConsecutiveDups(FCurves[I]);
      if Length(FCurves[I]) < 2 then FAlive[I] := 0;
    end
    else
      FAlive[I] := 0;
  end;
  for Pass := 0 to FParam.Passes - 1 do
  begin
    for I := 0 to High(FCurves) do
      if FAlive[I] <> 0 then
        TryCloseLoop(I);
    SetLength(FEnds, 0);
    for I := 0 to High(FCurves) do
      if FAlive[I] <> 0 then
      begin
        if Length(FCurves[I]) < 2 then Continue;
        AddEndpoint(I, ekStart);
        AddEndpoint(I, ekEnd);
      end;
    if Length(FEnds) < 2 then Break;
    Cands := nil;
    SetLength(BestIdx, Length(FEnds));
    SetLength(BestScore, Length(FEnds));
    for I := 0 to High(BestIdx) do
    begin
      BestIdx[I] := -1;
      BestScore[I] := 1e100;
    end;
    for I := 0 to High(FEnds) do
      for J := I + 1 to High(FEnds) do
      begin
        if FEnds[I].Curve = FEnds[J].Curve then Continue;
        if BuildCandidate(I, J, Cand) then
        begin
          K := Length(Cands);
          SetLength(Cands, K + 1);
          Cands[K] := Cand;
          if Cand.Score < BestScore[Cand.A] then
          begin
            BestScore[Cand.A] := Cand.Score;
            BestIdx[Cand.A] := K;
          end;
          if Cand.Score < BestScore[Cand.B] then
          begin
            BestScore[Cand.B] := Cand.Score;
            BestIdx[Cand.B] := K;
          end;
        end;
      end;
    if Length(Cands) = 0 then Break;
    Accepted := nil;
    for K := 0 to High(Cands) do
    begin
      EA := Cands[K].A;
      EB := Cands[K].B;
      if (BestIdx[EA] = K) and (BestIdx[EB] = K) then
      begin
        I := Length(Accepted);
        SetLength(Accepted, I + 1);
        Accepted[I] := Cands[K];
      end;
    end;
    if Length(Accepted) = 0 then Break;
    if Length(Accepted) > 1 then
      SortStitchCandidates(Accepted, 0, High(Accepted));
    SetLength(UsedCurve, Length(FCurves));
    if Length(UsedCurve) > 0 then
      FillChar(UsedCurve[0], Length(UsedCurve), 0);
    Merged := 0;
    for K := 0 to High(Accepted) do
    begin
      EA := Accepted[K].A;
      EB := Accepted[K].B;
      if (FAlive[FEnds[EA].Curve] = 0) or (FAlive[FEnds[EB].Curve] = 0) then Continue;
      if UsedCurve[FEnds[EA].Curve] <> 0 then Continue;
      if UsedCurve[FEnds[EB].Curve] <> 0 then Continue;
      UsedCurve[FEnds[EA].Curve] := 1;
      UsedCurve[FEnds[EB].Curve] := 1;
      MergeByEndpoints(EA, EB);
      Inc(Merged);
    end;
    if Merged = 0 then Break;
  end;
  AliveCount := 0;
  for I := 0 to High(FCurves) do
    if FAlive[I] <> 0 then Inc(AliveCount);
  SetLength(Result, AliveCount);
  J := 0;
  for I := 0 to High(FCurves) do
    if FAlive[I] <> 0 then
    begin
      Result[J] := FCurves[I];
      Inc(J);
    end;
end;

class function TCurveStitchParam.Make(const AMaxGap: Double): TCurveStitchParam;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MaxGap := AMaxGap;
  Result.MaxAngleDeg := 60.0;
  Result.LookAhead := 6;
  Result.Passes := 8;
  Result.AngleWeight := 18.0;
  Result.CheckCrossing := True;
  Result.SkipCrossPts := 3;
  Result.CloseLoops := True;
end;

function StitchCurveFragments(const Fragments: TPolylineArray;
  const Param: TCurveStitchParam): TPolylineArray;
var
  Stitcher: TCurveStitcher;
begin
  Stitcher := TCurveStitcher.Create;
  try
    Result := Stitcher.Stitch(Fragments, Param);
  finally
    Stitcher.Free;
  end;
end;

function UnionCurves(const Curves: TPolylineArray; const MaxGap: Double): TPolylineArray;
begin
  Result := StitchCurveFragments(Curves, TCurveStitchParam.Make(MaxGap));
end;

function CatmullRomPoint(const P0, P1, P2, P3: TPointI; const T: Double): TPointI;
var
  P: TPointD;
begin
  P := CatmullRomPointD(P0, P1, P2, P3, T);
  Result.X := Round(P.X);
  Result.Y := Round(P.Y);
end;

function CatmullRomPointD(const P0, P1, P2, P3: TPointI; const T: Double): TPointD;
var
  T2, T3: Double;
begin
  T2 := T * T;
  T3 := T2 * T;
  Result.X := 0.5 * (2 * P1.X + (-P0.X + P2.X) * T + (2 * P0.X - 5 * P1.X + 4 * P2.X - P3.X) * T2 + (-P0.X + 3 * P1.X - 3 * P2.X + P3.X) * T3);
  Result.Y := 0.5 * (2 * P1.Y + (-P0.Y + P2.Y) * T + (2 * P0.Y - 5 * P1.Y + 4 * P2.Y - P3.Y) * T2 + (-P0.Y + 3 * P1.Y - 3 * P2.Y + P3.Y) * T3);
end;

function SmoothPolylineCatmullRom(const PointArray: TPolyline; const SmoothFactor: Double): TPolyline;
var
  Closed: Boolean;
  Step: Double;
  I, J, Count, StepCount, K: Integer;
begin
  if Length(PointArray) < 3 then Exit(Copy(PointArray));
  if (SmoothFactor <= 0) or (SmoothFactor >= 1) then Exit(Copy(PointArray));
  Closed := SamePoint(PointArray[0], PointArray[High(PointArray)]);
  Step := 1 - SmoothFactor;
  StepCount := Trunc(1 / Step);
  if StepCount < 1 then StepCount := 1;
  Count := Length(PointArray);
  if Closed then Dec(Count);
  SetLength(Result, Count * StepCount);
  K := 0;
  for I := 0 to Count - 1 do
    for J := 0 to StepCount - 1 do
    begin
      if Closed then
        Result[K] := CatmullRomPoint(PointArray[(I - 1 + Count) mod Count], PointArray[I mod Count],
          PointArray[(I + 1) mod Count], PointArray[(I + 2) mod Count], J * Step)
      else if I = 0 then
          Result[K] := PointArray[0]
        else if I = Count - 2 then
            Result[K] := CatmullRomPoint(PointArray[I - 1], PointArray[I], PointArray[I + 1],
              PointArray[I + 1], J * Step)
          else if I = Count - 1 then
              Result[K] := PointArray[Count - 1]
            else
              Result[K] := CatmullRomPoint(PointArray[I - 1], PointArray[I], PointArray[I + 1],
                PointArray[I + 2], J * Step);
      Inc(K);
    end;
  SetLength(Result, K);
  RemoveConsecutiveDups(Result);
end;

function QuadraticBezierPoint(const A, B, C: TPointI; const T: Double): TPointI;
var
  Mt: Double;
begin
  Mt := 1 - T;
  Result.X := Round(Mt * Mt * A.X + 2 * Mt * T * B.X + T * T * C.X);
  Result.Y := Round(Mt * Mt * A.Y + 2 * Mt * T * B.Y + T * T * C.Y);
end;

function QuadraticBezierCurve(const A, B, C: TPointI; const Steps: Integer): TPolyline;
var
  I: Integer;
begin
  if Steps < 1 then Exit(nil);
  SetLength(Result, Steps + 1);
  for I := 0 to Steps do
    Result[I] := QuadraticBezierPoint(A, B, C, I / Steps);
end;

function PolylineLength(const C: TPolyline): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to High(C) do
    Result := Result + Sqrt(PointDistSqr(C[I - 1], C[I]));
end;

function RasterizeSegment(const A, B: TPointI): TPolyline;
var
  Count, I, J: Integer;
  XStep, YStep, X, Y: Double;
begin
  Count := Ceil(Sqrt(PointDistSqr(A, B)));
  if Count = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := B;
    Exit;
  end;
  XStep := (B.X - A.X) / Count;
  YStep := (B.Y - A.Y) / Count;
  X := A.X;
  Y := A.Y;
  J := 0;
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
  begin
    X := X + XStep;
    Y := Y + YStep;
    Result[J] := Point(Round(X), Round(Y));
    if (J > 0) and SamePoint(Result[J], Result[J - 1]) then Continue;
    Inc(J);
  end;
  SetLength(Result, J);
end;

function ResamplePolyline(const PointArray: TPolyline; const Size: Integer): TPolyline;
var
  I, J, K: Integer;
  Ratio, Fraction: Double;
begin
  if Size <= 0 then Exit(nil);
  SetLength(Result, Size);
  case Length(PointArray) of
    0: Exit;
    1:
      begin
        for I := 0 to Size - 1 do Result[I] := PointArray[0];
        Exit;
      end;
  end;
  if Size = 1 then
  begin
    Result[0] := PointArray[0];
    Exit;
  end;
  if Size > Length(PointArray) then
    for I := 0 to Size - 1 do
    begin
      Ratio := (I * (Length(PointArray) - 1)) / (Size - 1);
      J := Trunc(Ratio);
      K := J + 1;
      if K > High(PointArray) then K := High(PointArray);
      Fraction := Ratio - J;
      Result[I].X := Round(PointArray[J].X + Fraction * (PointArray[K].X - PointArray[J].X));
      Result[I].Y := Round(PointArray[J].Y + Fraction * (PointArray[K].Y - PointArray[J].Y));
    end
  else begin
    Ratio := (Length(PointArray) - 1) / (Size - 1);
    for I := 0 to Size - 1 do
    begin
      J := Round(I * Ratio);
      if J > High(PointArray) then J := High(PointArray);
      Result[I] := PointArray[J];
    end;
  end;
end;

function IndexAtArcLength(const Curve: TPolyline; const StartIndex: Integer; Distance: Double;
  const Epsilon: Double): Integer;
var
  GoForward: Boolean;
  I, Count, L, M, H: Integer;
  Sums: TArray<Double>;
begin
  if (StartIndex < 0) or (StartIndex >= Length(Curve)) then Exit(-1);
  GoForward := Distance > 0;
  Distance := Abs(Distance);
  if Distance < Epsilon then Exit(StartIndex);
  if GoForward then
    Count := Length(Curve) - StartIndex
  else
    Count := StartIndex + 1;
  if Count < 2 then Exit(-1);
  SetLength(Sums, Count);
  for I := 1 to Count - 1 do
    if GoForward then
      Sums[I] := Sums[I - 1] + Sqrt(PointDistSqr(Curve[StartIndex + I], Curve[StartIndex + I - 1]))
    else
      Sums[I] := Sums[I - 1] + Sqrt(PointDistSqr(Curve[StartIndex - I + 1], Curve[StartIndex - I]));
  L := 0;
  H := Count - 1;
  while L <= H do
  begin
    M := (L + H) div 2;
    if Abs(Sums[M] - Distance) < Epsilon then
    begin
      if GoForward then
        Exit(StartIndex + M)
      else
        Exit(StartIndex - M);
    end
    else if Sums[M] < Distance then
        L := M + 1
      else
        H := M - 1;
  end;
  if L < Count then
  begin
    if GoForward then
      Result := StartIndex + L
    else
      Result := StartIndex - L;
  end
  else
    Result := -1;
end;

function DensifySparsePolyline(const PointArray: TPolyline): TPolyline;
var
  I: Integer;
begin
  if Length(PointArray) < 2 then Exit(Copy(PointArray));
  SetLength(Result, 1);
  Result[0] := PointArray[0];
  for I := 1 to High(PointArray) do
    if (Abs(PointArray[I].X - PointArray[I - 1].X) <= 1) and (Abs(PointArray[I].Y - PointArray[I - 1].Y) <= 1) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := PointArray[I];
    end
    else
      AppendPoints(Result, RasterizeSegment(PointArray[I - 1], PointArray[I]));
end;

function PolylineAngleProfile(const PointArray: TPolyline; const Radius: Integer): TArray<Double>;
var
  I, Last, L, R: Integer;
begin
  if (Radius < 1) or (Length(PointArray) = 0) then Exit(nil);
  Last := High(PointArray);
  SetLength(Result, Length(PointArray));
  for I := 0 to Last do
  begin
    L := Max(I - Radius, 0);
    R := Min(I + Radius, Last);
    Result[I] := DirectionAngle(PointD(PointArray[R]), PointD(PointArray[L]));
  end;
end;

function DynamicTimeWarpingCost(const A, B: TArray<Double>): Double;
var
  Matrix: TArray<TArray<Double>>;
  I, J, Count: Integer;
  Value: Double;
  StepDown, StepRight: Boolean;
begin
  Result := 0;
  if (Length(A) = 0) or (Length(B) = 0) then Exit;
  SetLength(Matrix, Length(A), Length(B));
  for I := 0 to High(Matrix) do
    for J := 0 to High(Matrix[I]) do
      Matrix[I, J] := Abs(A[I] - B[J]);
  for I := 0 to High(Matrix) do
    for J := 0 to High(Matrix[I]) do
    begin
      if (I > 0) and (J > 0) then
      begin
        Value := Min(Matrix[I - 1, J], Matrix[I, J - 1]);
        if Matrix[I - 1, J - 1] < Value then Value := Matrix[I - 1, J - 1];
      end
      else if I > 0 then
          Value := Matrix[I - 1, J]
        else if J > 0 then
            Value := Matrix[I, J - 1]
          else
            Value := 0;
      Matrix[I, J] := Matrix[I, J] + Value;
    end;
  Count := 0;
  I := 0;
  J := 0;
  while (I < High(Matrix)) or (J < High(Matrix[I])) do
  begin
    if (I < High(Matrix)) and (J < High(Matrix[I])) then
    begin
      StepDown := False;
      StepRight := False;
      if Matrix[I + 1, J] < Matrix[I, J + 1] then
      begin
        Value := Matrix[I + 1, J];
        StepDown := True;
      end
      else begin
        Value := Matrix[I, J + 1];
        StepRight := True;
      end;
      if Matrix[I + 1, J + 1] < Value then
      begin
        Value := Matrix[I + 1, J + 1];
        StepDown := True;
        StepRight := True;
      end;
      if StepDown then Inc(I);
      if StepRight then Inc(J);
      Result := Result + Value;
    end
    else if I < High(Matrix) then
      begin
        Result := Result + Matrix[I + 1, J];
        Inc(I);
      end
      else begin
        Result := Result + Matrix[I, J + 1];
        Inc(J);
      end;
    Inc(Count);
  end;
  if Count > 0 then Result := Result / Count;
end;

function SortedQuantile(const A: TArray<Double>; const Q: Double): Double;
var
  N, J: Integer;
  T: Double;
begin
  N := Length(A);
  if N = 0 then Exit(0);
  if Q <= 0 then Exit(A[0]);
  if Q >= 1 then Exit(A[N - 1]);
  T := Q * (N - 1);
  J := Trunc(T);
  if J >= N - 1 then
    Result := A[N - 1]
  else
    Result := A[J] + (A[J + 1] - A[J]) * (T - J);
end;

function RangeMin(const A: TArray<Double>; const L, R: Integer): Double;
var
  I: Integer;
begin
  Result := A[L];
  for I := L + 1 to R do
    if A[I] < Result then Result := A[I];
end;

function DetectCornerIndices(const Source: TPolyline; const Sensitivity: Double): TArray<Integer>;
const
  OneDegree = Pi / 180;
var
  I, J, K, N, Radius, NumValues, NumCands, Num: Integer;
  S, MinPeak, MinProm, ValueHi, ValueLo, Prom: Double;
  Angles, Turn, TurnSm, Values: TArray<Double>;
  Cands: TArray<Integer>;
begin
  N := Length(Source);
  if N < 5 then Exit(nil);
  S := EnsureRange(Sensitivity, 0, 1);
  J := 4;
  if N < 2 * J + 1 then J := Max(1, (N - 1) div 4);
  K := Max(2, J);
  Radius := Max(2, J);
  Angles := PolylineAngleProfile(Source, J);
  if Length(Angles) <> N then Exit(nil);
  SetLength(Turn, N);
  for I := J to N - 1 - J do
    Turn[I] := AngularDifference(Angles[I - J], Angles[I + J]);
  SetLength(TurnSm, N);
  for I := 0 to N - 1 do TurnSm[I] := Turn[I];
  for I := J + 1 to N - 2 - J do TurnSm[I] := (Turn[I - 1] + Turn[I] + Turn[I + 1]) / 3;
  SetLength(Values, N);
  NumValues := 0;
  for I := J to N - 1 - J do
    if TurnSm[I] > (OneDegree / 10) then
    begin
      Values[NumValues] := TurnSm[I];
      Inc(NumValues);
    end;
  if NumValues = 0 then Exit(nil);
  SetLength(Values, NumValues);
  {$IFDEF FPC}TArrayHelper<Double>.Sort{$ELSE}TArray.Sort<Double>{$ENDIF}(Values);
  if Values[NumValues - 1] < OneDegree then Exit(nil);
  ValueHi := SortedQuantile(Values, 0.98);
  ValueLo := SortedQuantile(Values, 0.30);
  MinPeak := ValueHi + (ValueLo - ValueHi) * S;
  MinProm := MinPeak * (0.60 + (0.25 - 0.60) * S);
  if MinProm > MinPeak then MinProm := MinPeak;
  SetLength(Cands, N);
  NumCands := 0;
  for I := J + K to N - 1 - J - K do
  begin
    if TurnSm[I] < MinPeak then Continue;
    if (TurnSm[I] <= TurnSm[I - 1]) or (TurnSm[I] < TurnSm[I + 1]) then Continue;
    Prom := TurnSm[I] - Min(RangeMin(TurnSm, I - K, I - 1), RangeMin(TurnSm, I + 1, I + K));
    if Prom < MinProm then Continue;
    Cands[NumCands] := I;
    Inc(NumCands);
  end;
  if NumCands = 0 then Exit(nil);
  SetLength(Cands, NumCands);
  SetLength(Result, NumCands);
  Num := 0;
  for I := 0 to NumCands - 1 do
  begin
    if Num = 0 then
    begin
      Result[0] := Cands[I];
      Num := 1;
      Continue;
    end;
    if Cands[I] - Result[Num - 1] <= Radius then
    begin
      if TurnSm[Cands[I]] > TurnSm[Result[Num - 1]] then
        Result[Num - 1] := Cands[I];
    end
    else begin
      Result[Num] := Cands[I];
      Inc(Num);
    end;
  end;
  SetLength(Result, Num);
end;

function SplitPolylineAtIndices(const Polyline: TPolyline; const Indices: TArray<Integer>): TPolylineArray;
var
  N, I, K, StartIndex, BreakIndex, NumCurves: Integer;
  Breaks: TArray<Integer>;
begin
  N := Length(Polyline);
  if N < 2 then Exit(nil);
  if Length(Indices) = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := Copy(Polyline);
    Exit;
  end;
  Breaks := Copy(Indices);
  {$IFDEF FPC}TArrayHelper<Integer>.Sort{$ELSE}TArray.Sort<Integer>{$ENDIF}(Breaks);
  K := 0;
  for I := 0 to High(Breaks) do
  begin
    BreakIndex := Breaks[I];
    if (BreakIndex <= 0) or (BreakIndex >= N - 1) then Continue;
    if (K = 0) or (BreakIndex <> Breaks[K - 1]) then
    begin
      Breaks[K] := BreakIndex;
      Inc(K);
    end;
  end;
  if K = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := Copy(Polyline);
    Exit;
  end;
  SetLength(Breaks, K);
  SetLength(Result, K + 1);
  NumCurves := 0;
  StartIndex := 0;
  for I := 0 to K - 1 do
  begin
    BreakIndex := Breaks[I];
    if BreakIndex > StartIndex then
    begin
      Result[NumCurves] := Copy(Polyline, StartIndex, BreakIndex - StartIndex + 1);
      Inc(NumCurves);
    end;
    StartIndex := BreakIndex;
  end;
  if StartIndex < N - 1 then
  begin
    Result[NumCurves] := Copy(Polyline, StartIndex, N - StartIndex);
    Inc(NumCurves);
  end;
  if NumCurves = 0 then Exit(nil);
  SetLength(Result, NumCurves);
end;

const
  RepairEps = 1e-12;

function PerpDistToLine(const P, A, B: TPointD): Double;
var
  ABx, ABy, Den: Double;
begin
  ABx := B.X - A.X;
  ABy := B.Y - A.Y;
  Den := Sqrt(ABx * ABx + ABy * ABy);
  if Den <= RepairEps then
    Exit(Sqrt(Sqr(P.X - A.X) + Sqr(P.Y - A.Y)));
  Result := Abs(ABx * (P.Y - A.Y) - ABy * (P.X - A.X)) / Den;
end;

function ProjectionT(const P, A, B: TPointD): Double;
var
  ABx, ABy, Den2: Double;
begin
  ABx := B.X - A.X;
  ABy := B.Y - A.Y;
  Den2 := ABx * ABx + ABy * ABy;
  if Den2 <= RepairEps then Exit(0);
  Result := ((P.X - A.X) * ABx + (P.Y - A.Y) * ABy) / Den2;
end;

function MedianOf(const Values: TArray<Double>): Double;
var
  Tmp: TArray<Double>;
  N, Mid: Integer;
begin
  N := Length(Values);
  if N = 0 then Exit(0);
  Tmp := Copy(Values);
  {$IFDEF FPC}TArrayHelper<Double>.Sort{$ELSE}TArray.Sort<Double>{$ENDIF}(Tmp);
  Mid := N div 2;
  if Odd(N) then
    Result := Tmp[Mid]
  else
    Result := (Tmp[Mid - 1] + Tmp[Mid]) * 0.5;
end;

procedure AppendUnique(var C: TPolyline; const P: TPointI);
var
  N: Integer;
begin
  N := Length(C);
  if (N = 0) or not SamePoint(C[N - 1], P) then
  begin
    SetLength(C, N + 1);
    C[N] := P;
  end;
end;

procedure AppendInterpolatedSegment(var C: TPolyline; const A, B: TPointI; const Count: Integer);
var
  I: Integer;
  T: Double;
  P: TPointI;
begin
  if Count <= 1 then
  begin
    AppendUnique(C, A);
    Exit;
  end;
  for I := 0 to Count - 1 do
  begin
    if I = 0 then
      P := A
    else if I = Count - 1 then
        P := B
      else begin
        T := I / (Count - 1);
        P := Point(Round(A.X + (B.X - A.X) * T), Round(A.Y + (B.Y - A.Y) * T));
      end;
    AppendUnique(C, P);
  end;
end;

function RepairIsBadPoint(const Exact: TArray<TPointD>; const Index: Integer; const BaseStep: Double;
  const Param: TRepairParam): Boolean;
const
  NearPointFactor = 0.05;
  NearChordFactor = 0.10;
  BacktrackStepMin = 0.25;
var
  P0, P1, P2: TPointD;
  V1x, V1y, V2x, V2y, L1, L2, Chord, DistPerp, TProj, Dot12, AngleCos: Double;
  Spike, Backtrack, Cluster: Boolean;
begin
  P0 := Exact[Index - 1];
  P1 := Exact[Index];
  P2 := Exact[Index + 1];
  V1x := P1.X - P0.X;
  V1y := P1.Y - P0.Y;
  V2x := P2.X - P1.X;
  V2y := P2.Y - P1.Y;
  L1 := Sqrt(V1x * V1x + V1y * V1y);
  L2 := Sqrt(V2x * V2x + V2y * V2y);
  Chord := Sqrt(Sqr(P2.X - P0.X) + Sqr(P2.Y - P0.Y));
  if (rkNearPoint in Param.Kinds) and ((L1 <= BaseStep * NearPointFactor) or
    (L2 <= BaseStep * NearPointFactor)) then
      Exit(True);
  if (rkNearChord in Param.Kinds) and (Chord <= BaseStep * NearChordFactor) then Exit(True);
  DistPerp := PerpDistToLine(P1, P0, P2);
  TProj := ProjectionT(P1, P0, P2);
  Dot12 := V1x * V2x + V1y * V2y;
  if (L1 <= RepairEps) or (L2 <= RepairEps) then
    AngleCos := 1
  else
    AngleCos := Dot12 / (L1 * L2);
  if IsNan(AngleCos) then AngleCos := 1;
  Spike := (rkSpike in Param.Kinds) and (DistPerp > BaseStep * Param.SpikePerp) and
    ((AngleCos < Param.SpikeCos) or (DistPerp > BaseStep * Param.SpikePerpHard));
  Backtrack := (rkBacktrack in Param.Kinds) and ((TProj < -Param.BacktrackMargin) or
    (TProj > 1 + Param.BacktrackMargin) or ((Dot12 < 0) and (L1 > BaseStep * BacktrackStepMin) and
    (L2 > BaseStep * BacktrackStepMin)));
  Cluster := (rkCluster in Param.Kinds) and (L1 < BaseStep * Param.ClusterStep) and
    (L2 < BaseStep * Param.ClusterStep) and (AngleCos < Param.ClusterCos);
  Result := Spike or Backtrack or Cluster;
end;

function RepairPolyline(const PointArray: TPolyline; const Param: TRepairParam): TPolyline;
const
  ShortSegFactor = 0.25;
var
  I, J, K, StepCount, RunMax, AnchorMin, AnchorMax, SegCount: Integer;
  Clean: TPolyline;
  Exact: TArray<TPointD>;
  Steps: TArray<Double>;
  Distance, BaseStep: Double;
  Bad: TArray<Boolean>;
  AnyBad: Boolean;
  APoint, BPoint: TPointI;
begin
  J := Length(PointArray);
  if J < 3 then Exit(Copy(PointArray));
  if rkDuplicates in Param.Kinds then
  begin
    Clean := nil;
    for I := 0 to J - 1 do AppendUnique(Clean, PointArray[I]);
  end
  else
    Clean := Copy(PointArray);
  K := Length(Clean);
  if K < 3 then Exit(Clean);
  SetLength(Exact, K);
  for I := 0 to K - 1 do Exact[I] := PointD(Clean[I]);
  SetLength(Steps, K - 1);
  StepCount := 0;
  for I := 1 to K - 1 do
  begin
    Distance := Sqrt(PointDistSqr(Clean[I - 1], Clean[I]));
    if Distance > RepairEps then
    begin
      Steps[StepCount] := Distance;
      Inc(StepCount);
    end;
  end;
  SetLength(Steps, StepCount);
  BaseStep := MedianOf(Steps);
  if BaseStep <= RepairEps then BaseStep := 1;
  SetLength(Bad, K);
  AnyBad := False;
  for I := 1 to K - 2 do
  begin
    Bad[I] := RepairIsBadPoint(Exact, I, BaseStep, Param);
    AnyBad := AnyBad or Bad[I];
  end;
  if not AnyBad then Exit(Clean);
  Result := nil;
  I := 0;
  while I < K do
  begin
    if (I >= 1) and (I <= K - 2) and Bad[I] then
    begin
      RunMax := I;
      while (RunMax <= K - 2) and Bad[RunMax] do Inc(RunMax);
      Dec(RunMax);
      AnchorMin := I - 1;
      AnchorMax := RunMax + 1;
      SegCount := AnchorMax - AnchorMin + 1;
      APoint := Clean[AnchorMin];
      BPoint := Clean[AnchorMax];
      Distance := Sqrt(PointDistSqr(APoint, BPoint));
      if (SegCount < 3) or (Distance <= BaseStep * ShortSegFactor) then
      begin
        AppendUnique(Result, APoint);
        AppendUnique(Result, BPoint);
      end
      else
        AppendInterpolatedSegment(Result, APoint, BPoint, SegCount);
      I := AnchorMax + 1;
      Continue;
    end;
    AppendUnique(Result, Clean[I]);
    Inc(I);
  end;
end;

class function TRepairParam.Make(const AKinds: TRepairKinds;
  const ASpikePerp, ASpikePerpHard, ASpikeCos, ABacktrackMargin, AClusterStep, AClusterCos: Double): TRepairParam;
begin
  Result.Kinds := AKinds;
  Result.SpikePerp := ASpikePerp;
  Result.SpikePerpHard := ASpikePerpHard;
  Result.SpikeCos := ASpikeCos;
  Result.BacktrackMargin := ABacktrackMargin;
  Result.ClusterStep := AClusterStep;
  Result.ClusterCos := AClusterCos;
end;

function ResampleLineByEndpoints(const PointArray: TPolyline; const NewSize: Integer): TPolyline;
var
  I, OldSize, Diff, Half: Integer;
  MinP, MaxP: TPointI;
  HDiff, VDiff, Step: Double;
  HDominant: Boolean;
begin
  OldSize := Length(PointArray);
  if (OldSize = 0) or (NewSize < 0) then Exit(nil);
  if OldSize = NewSize then Exit(Copy(PointArray, 0, NewSize));
  SetLength(Result, NewSize);
  MinP := PointArray[0];
  MaxP := PointArray[High(PointArray)];
  HDiff := MaxP.X - MinP.X;
  VDiff := MaxP.Y - MinP.Y;
  HDominant := Abs(HDiff) > Abs(VDiff);
  if HDominant then
  begin
    if HDiff = 0 then Exit(nil);
    Step := VDiff / HDiff;
  end
  else begin
    if VDiff = 0 then Exit(nil);
    Step := HDiff / VDiff;
  end;
  Diff := Abs(NewSize - OldSize);
  Half := Diff div 2;
  if OldSize > NewSize then
    for I := 0 to NewSize - 1 do
      Result[I] := PointArray[I + Half]
  else begin
    for I := 0 to Half - 1 do
      if HDominant then
        Result[I] := Point(MinP.X - Sign(HDiff) * (Half - I), Round(MinP.Y - Sign(HDiff) * (Half - I) * Step))
      else
        Result[I] := Point(Round(MinP.X - Sign(VDiff) * (Half - I) * Step),
          MinP.Y - Sign(VDiff) * (Half - I));
    for I := 0 to OldSize - 1 do
      Result[Half + I] := PointArray[I];
    for I := 0 to Diff - Half - 1 do
      if HDominant then
        Result[Half + OldSize + I] := Point(MaxP.X + Sign(HDiff) * (I + 1),
          Round(MaxP.Y + Sign(HDiff) * (I + 1) * Step))
      else
        Result[Half + OldSize + I] := Point(Round(MaxP.X + Sign(VDiff) * (I + 1) * Step),
          MaxP.Y + Sign(VDiff) * (I + 1));
  end;
end;

function DistanceFactorTortuosity(const C: TPolyline): Double;
var
  Chord, Arc: Double;
begin
  if Length(C) < 2 then Exit(0);
  Arc := PolylineLength(C);
  if Arc <= 0 then Exit(0);
  Chord := Sqrt(PointDistSqr(C[0], C[High(C)]));
  Result := 1 - Chord / Arc;
end;

function SmoothPolylineGaussian(const PointArray: TPolyline; const Factor: Double): TPolyline;
var
  I, K, N, WindowSize, MinIdx, MaxIdx: Integer;
  Sigma, WeightSum, Weight, AvgX, AvgY: Double;
begin
  N := Length(PointArray);
  if N <= 2 then Exit(Copy(PointArray));
  WindowSize := Round(Factor * (N div 2));
  if WindowSize < 3 then WindowSize := 3;
  if WindowSize > N div 2 then WindowSize := N div 2;
  if WindowSize > 0 then
    Sigma := WindowSize / 2
  else
    Sigma := 1;
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    MinIdx := Max(0, I - WindowSize);
    MaxIdx := Min(N - 1, I + WindowSize);
    WeightSum := 0;
    AvgX := 0;
    AvgY := 0;
    for K := MinIdx to MaxIdx do
    begin
      Weight := Exp(-0.5 * Sqr((K - I) / Sigma));
      AvgX := AvgX + PointArray[K].X * Weight;
      AvgY := AvgY + PointArray[K].Y * Weight;
      WeightSum := WeightSum + Weight;
    end;
    if WeightSum <> 0 then
      Result[I] := Point(Round(AvgX / WeightSum), Round(AvgY / WeightSum))
    else
      Result[I] := PointArray[I];
  end;
end;

function Make4Connected(const PointArray: TPolyline): TPolyline;
const
  Shift8: array[0..7] of TPointI = (
    (X: 0; Y: -1), (X: 1; Y: -1), (X: 1; Y: 0), (X: 1; Y: 1),
    (X: 0; Y: 1), (X: -1; Y: 1), (X: -1; Y: 0), (X: -1; Y: -1)
  );
var
  I, J, K, Count, Index, NCount: Integer;
  Neighbors: TPolyline;
  P: TPointI;
  Flag: Boolean;
begin
  Result := nil;
  I := 0;
  while I < Length(PointArray) do
  begin
    if (Length(Result) < 1) or not SamePoint(Result[High(Result)], PointArray[I]) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := PointArray[I];
    end;
    if I < High(PointArray) then
    begin
      SetLength(Neighbors, Length(Shift8));
      NCount := 0;
      Count := Min(I + 1 + High(Shift8), High(PointArray));
      for J := 0 to High(Shift8) do
      begin
        P := Point(PointArray[I].X + Shift8[J].X, PointArray[I].Y + Shift8[J].Y);
        Flag := False;
        for Index := I + 1 to Count do
          if SamePoint(P, PointArray[Index]) then
          begin
            Flag := True;
            Break;
          end;
        if Flag then
        begin
          Neighbors[NCount] := P;
          Inc(NCount);
        end;
      end;
      SetLength(Neighbors, NCount);
      if Length(Neighbors) > 1 then
      begin
        Count := Min(I + 1 + High(Neighbors), High(PointArray));
        Index := -1;
        for J := 0 to High(Neighbors) do
          for K := I + 1 to Count do
            if SamePoint(Neighbors[J], PointArray[K]) and ((Index < 0) or (Index < K)) then
              Index := K;
        if Index < 0 then
          Inc(I)
        else
          I := Index;
      end
      else
        Inc(I);
    end
    else
      Inc(I);
  end;
end;

function ClampedRunSize(MinI, MaxI, High0: Integer): Integer;
begin
  if MinI < 0 then
    MinI := 0
  else if MinI > High0 then
      MinI := High0;
  if MaxI < 0 then
    MaxI := 0
  else if MaxI > High0 then
      MaxI := High0;
  if MinI > MaxI then
    Result := 0
  else
    Result := MaxI - MinI + 1;
end;

function StraightenPolyline(const PointArray: TPolyline; const Threshold: Double;
  const Connect4: Boolean): TPolyline;
var
  I, J, High0: Integer;
  Interval: Double;
  Line: TPolyline;
begin
  if Threshold <= 0 then Exit(Copy(PointArray));
  if Length(PointArray) = 0 then Exit(nil);
  High0 := High(PointArray);
  Result := nil;
  J := 0;
  Interval := Length(PointArray);
  for I := 0 to High0 do
  begin
    if Interval > Threshold then Interval := Threshold;
    if (I = 0) or (ClampedRunSize(J, I, High0) >= Interval) then
    begin
      if Length(Result) > 0 then
      begin
        Line := RasterizeSegment(Result[High(Result)], PointArray[I]);
        if Connect4 then Line := Make4Connected(Line);
        AppendPoints(Result, Line);
      end
      else begin
        SetLength(Result, 1);
        Result[0] := PointArray[I];
      end;
      J := I;
      Interval := ClampedRunSize(J, High0, High0);
    end;
  end;
end;

function UntwistPolyline(const PointArray: TPolyline; const Radius: Double;
  const Connect4: Boolean): TPolyline;
var
  Arc: TArray<Double>;
  I, J: Integer;
  Ok: Boolean;
  Line: TPolyline;
begin
  SetLength(Arc, Length(PointArray));
  for I := 1 to High(PointArray) do
    Arc[I] := Sqrt(PointDistSqr(PointArray[I], PointArray[I - 1])) + Arc[I - 1];
  Result := nil;
  Ok := True;
  I := 0;
  while I < Length(PointArray) do
  begin
    if Ok then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := PointArray[I];
    end
    else
      Ok := True;
    J := I + 1;
    while Ok and (J < Length(PointArray)) do
    begin
      if Arc[J] - Arc[I] > Radius then
      begin
        Ok := Sqrt(PointDistSqr(PointArray[I], PointArray[J])) >= Radius;
        if not Ok then
        begin
          while J < High(PointArray) do
          begin
            Inc(J);
            if Sqrt(PointDistSqr(PointArray[I], PointArray[J])) >= Radius then Break;
          end;
          Line := RasterizeSegment(PointArray[I], PointArray[J]);
          if Connect4 then Line := Make4Connected(Line);
          AppendPoints(Result, Line);
          I := J;
        end;
      end;
      if Ok then Inc(J);
    end;
    if Ok then Inc(I);
  end;
end;

function BuildCrossSections(const PointArray: TPolyline; const AngleArray: TArray<Double>;
  const Angle: Double; const Radius: Integer): TPolylineArray;
var
  I: Integer;
  PA, PB: TPointD;
  APoint, BPoint: TPointI;
begin
  if Length(PointArray) <> Length(AngleArray) then Exit(nil);
  SetLength(Result, Length(PointArray));
  for I := 0 to High(PointArray) do
  begin
    PA := PointAtAngleDistance(PointD(PointArray[I]), AngleArray[I] + Angle, Radius);
    PB := PointAtAngleDistance(PointD(PointArray[I]), AngleArray[I] + Angle, -Radius);
    APoint := Point(Round(PA.X), Round(PA.Y));
    BPoint := Point(Round(PB.X), Round(PB.Y));
    Result[I] := ResampleLineByEndpoints(RasterizeSegment(APoint, BPoint), Radius * 2);
  end;
end;

function DirectedHausdorff(const A, B: TPolyline): Double;
var
  I, J: Integer;
  DX, DY: Int64;
  MinD, D, MaxMin: Double;
begin
  MaxMin := 0;
  for I := 0 to High(A) do
  begin
    MinD := MaxDouble;
    for J := 0 to High(B) do
    begin
      DX := A[I].X - B[J].X;
      DY := A[I].Y - B[J].Y;
      D := DX * DX + DY * DY;
      if D < MinD then MinD := D;
    end;
    if MinD > MaxMin then MaxMin := MinD;
  end;
  Result := Sqrt(MaxMin);
end;

function HausdorffDistance(const A, B: TPolyline): Double;
begin
  if (Length(A) = 0) or (Length(B) = 0) then Exit(0);
  Result := Max(DirectedHausdorff(A, B), DirectedHausdorff(B, A));
end;

function CurveDtwDistance(const A, B: TPolyline): Double;
var
  M: TArray<TArray<Double>>;
  I, J: Integer;
  DX, DY: Int64;
  Cost, Best: Double;
begin
  if (Length(A) = 0) or (Length(B) = 0) then Exit(0);
  SetLength(M, Length(A), Length(B));
  for I := 0 to High(A) do
    for J := 0 to High(B) do
    begin
      DX := A[I].X - B[J].X;
      DY := A[I].Y - B[J].Y;
      Cost := Sqrt(DX * DX + DY * DY);
      if (I = 0) and (J = 0) then
        Best := 0
      else if I = 0 then
          Best := M[I][J - 1]
        else if J = 0 then
            Best := M[I - 1][J]
          else
            Best := Min(M[I - 1][J], Min(M[I][J - 1], M[I - 1][J - 1]));
      M[I][J] := Cost + Best;
    end;
  Result := M[High(A)][High(B)] / (Length(A) + Length(B));
end;

function CompareCurveShapes(const A, B: TPolyline; const Metric: TCurveMetric): Double;
begin
  case Metric of
    cmHausdorff: Result := HausdorffDistance(A, B);
    cmDtw: Result := CurveDtwDistance(A, B);
  else
    Result := 0;
  end;
end;

function AngleVariationTortuosity(const C: TPolyline; const Radius: Integer): Double;
var
  Prof: TArray<Double>;
  I, Count: Integer;
  Sum: Double;
begin
  if Length(C) < 3 then Exit(0);
  Prof := PolylineAngleProfile(C, Radius);
  Sum := 0;
  Count := 0;
  for I := 1 to High(Prof) do
  begin
    Sum := Sum + AngularDifference(Prof[I - 1], Prof[I]);
    Inc(Count);
  end;
  if Count = 0 then Exit(0);
  Result := Sum / Count;
end;

type
  TOverlapChord = record
    Head: TPointI;
    Tail: TPointI;
    Angle: Double;
  end;

  TOverlapChords = TArray<TOverlapChord>;

class function TOverlapParam.Make(const Width, Height: Integer): TOverlapParam;
var
  Side: Integer;
begin
  if Width > Height then
    Side := Width
  else
    Side := Height;
  Result.Radius := 2 + (Side div 50);
  if Result.Radius < 2 then
    Result.Radius := 2;
  if Result.Radius > 6 then
    Result.Radius := 6;
  Result.AngleTolerance := Pi / 18;
end;

procedure OverlapPaintDisc(var Mask: TArray<Boolean>;
  const Width, Height, CenterX, CenterY, Radius: Integer);
var
  X, Y, DX, DY, Square: Integer;
begin
  Square := Radius * Radius;
  for Y := CenterY - Radius to CenterY + Radius do
  begin
    if (Y < 0) or (Y >= Height) then
      Continue;
    DY := Y - CenterY;
    for X := CenterX - Radius to CenterX + Radius do
    begin
      if (X < 0) or (X >= Width) then
        Continue;
      DX := X - CenterX;
      if DX * DX + DY * DY <= Square then
        Mask[Y * Width + X] := True;
    end;
  end;
end;

function OverlapThinPoints(const Source: TPolylineArray; const Width, Height: Integer): TPolyline;
var
  Taken: TArray<Boolean>;
  I, J, X, Y, DX, DY, Count, Total: Integer;
  Busy: Boolean;
begin
  Result := nil;
  Total := 0;
  for I := 0 to High(Source) do
    Inc(Total, Length(Source[I]));
  if Total = 0 then
    Exit;
  SetLength(Taken, Width * Height);
  SetLength(Result, Total);
  Count := 0;
  for I := 0 to High(Source) do
    for J := 0 to High(Source[I]) do
    begin
      X := Source[I][J].X;
      Y := Source[I][J].Y;
      if (X < 0) or (Y < 0) or (X >= Width) or (Y >= Height) then
        Continue;
      Busy := False;
      for DY := -1 to 1 do
        for DX := -1 to 1 do
          if DX * DX + DY * DY <= 1 then
            if (X + DX >= 0) and (X + DX < Width) and (Y + DY >= 0) and (Y + DY < Height) then
              if Taken[(Y + DY) * Width + X + DX] then
                Busy := True;
      if Busy then
        Continue;
      Taken[Y * Width + X] := True;
      Result[Count].X := X;
      Result[Count].Y := Y;
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function OverlapMakeChords(const Source: TPolylineArray;
  const Width, Height, Radius: Integer): TOverlapChords;
var
  I, J, Count, Total, DX, DY: Integer;
  Head: TPointI;
  Point: TPointI;
  Started: Boolean;
  Angle: Double;
begin
  Result := nil;
  Total := 0;
  for I := 0 to High(Source) do
    Inc(Total, Length(Source[I]));
  if Total = 0 then
    Exit;
  SetLength(Result, Total);
  Count := 0;
  Head.X := 0;
  Head.Y := 0;
  for I := 0 to High(Source) do
  begin
    Started := False;
    for J := 0 to High(Source[I]) do
    begin
      Point := Source[I][J];
      if (Point.X < 0) or (Point.Y < 0) or (Point.X >= Width) or (Point.Y >= Height) then
        Continue;
      if not Started then
      begin
        Head := Point;
        Started := True;
        Continue;
      end;
      DX := Point.X - Head.X;
      DY := Point.Y - Head.Y;
      if DX * DX + DY * DY < Radius * Radius then
        Continue;
      Angle := ArcTan2(DY, DX);
      if Angle < 0 then
        Angle := Angle + Pi;
      if Angle >= Pi then
        Angle := Angle - Pi;
      Result[Count].Head := Head;
      Result[Count].Tail := Point;
      Result[Count].Angle := Angle;
      Inc(Count);
      Head := Point;
    end;
  end;
  SetLength(Result, Count);
end;

function OverlapAngleGap(const First, Second: Double): Double;
begin
  Result := Abs(First - Second);
  if Result > Pi / 2 then
    Result := Pi - Result;
end;

function OverlapShare(const Curve: TPolyline; const Ignore, Common: TArray<Boolean>;
  const Width: Integer): Double;
var
  I, Index, Hit, Total: Integer;
begin
  Hit := 0;
  Total := 0;
  for I := 0 to High(Curve) do
  begin
    Index := Curve[I].Y * Width + Curve[I].X;
    if Ignore[Index] then
      Continue;
    if Common[Index] then
      Inc(Hit);
    Inc(Total);
  end;
  if Total = 0 then
    Result := 0
  else
    Result := Hit / Total;
end;

function PolylineOverlapScore(const A, B: TPolylineArray; const Width, Height: Integer;
  const Param: TOverlapParam): Double;
var
  CurveA, CurveB: TPolyline;
  ChordsA, ChordsB: TOverlapChords;
  IgnoreA, IgnoreB, MaskA, MaskB, Both, Common: TArray<Boolean>;
  I, J, X, Y, Cells, Radius: Integer;
begin
  Result := 0;
  if (Width <= 0) or (Height <= 0) then
    Exit;
  Radius := Param.Radius;
  if Radius < 1 then
    Exit;
  CurveA := OverlapThinPoints(A, Width, Height);
  CurveB := OverlapThinPoints(B, Width, Height);
  if (Length(CurveA) = 0) or (Length(CurveB) = 0) then
    Exit;
  Cells := Width * Height;
  SetLength(IgnoreA, Cells);
  SetLength(IgnoreB, Cells);
  ChordsA := OverlapMakeChords(A, Width, Height, Radius);
  ChordsB := OverlapMakeChords(B, Width, Height, Radius);
  for I := 0 to High(ChordsA) do
    for J := 0 to High(ChordsB) do
      if OverlapAngleGap(ChordsA[I].Angle, ChordsB[J].Angle) >= Param.AngleTolerance then
        if SegmentsIntersect(ChordsA[I].Head, ChordsA[I].Tail,
                             ChordsB[J].Head, ChordsB[J].Tail) then
          begin
            OverlapPaintDisc(IgnoreA, Width, Height, ChordsA[I].Tail.X, ChordsA[I].Tail.Y, Radius);
            OverlapPaintDisc(IgnoreB, Width, Height, ChordsB[J].Tail.X, ChordsB[J].Tail.Y, Radius);
          end;
  SetLength(MaskA, Cells);
  SetLength(MaskB, Cells);
  for I := 0 to High(CurveA) do
    OverlapPaintDisc(MaskA, Width, Height, CurveA[I].X, CurveA[I].Y, Radius);
  for I := 0 to High(CurveB) do
    OverlapPaintDisc(MaskB, Width, Height, CurveB[I].X, CurveB[I].Y, Radius);
  SetLength(Both, Cells);
  for I := 0 to Cells - 1 do
    Both[I] := MaskA[I] and MaskB[I];
  SetLength(Common, Cells);
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
      if Both[Y * Width + X] then
        OverlapPaintDisc(Common, Width, Height, X, Y, Radius);
  Result := OverlapShare(CurveA, IgnoreA, Common, Width) *
    OverlapShare(CurveB, IgnoreB, Common, Width);
end;

function PolylineOverlapScore(const A, B: TPolylineArray; const Width, Height: Integer): Double;
begin
  Result := PolylineOverlapScore(A, B, Width, Height, TOverlapParam.Make(Width, Height));
end;

end.
