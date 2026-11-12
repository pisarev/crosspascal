{ ************************************************************************** }
{                                                                            }
{ CrossVision.Binarize                                                       }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                                             }
{                                                                            }
{ ************************************************************************** }

{ SPDX-License-Identifier: MPL-1.1
  Original Code: CrossFPC-Common BinarizeText. Initial Developer: Yuriy Pisarev.
  Original copyright (c) 2024 Yuriy Pisarev. See licenses/MPL-1.1.txt.
  This file is a CrossPascal adaptation. See licenses/CROSSFPCCOMMON-NOTICE.md. }

unit CrossVision.Binarize;

interface

uses
  CrossVision.Image;

function OtsuThreshold(const Src: IImageAccessor): Integer;

function BinarizeOtsu(const Src: IImageAccessor): IImageBuffer;

function BinarizeNiblack(const Src: IImageAccessor; const Radius: Integer;
  const K: Double = -0.2): IImageBuffer;

function BinarizeSauvola(const Src: IImageAccessor; const Radius: Integer; const K: Double = 0.2;
  const R: Double = 128): IImageBuffer;

function BinarizeWolfJolion(const Src: IImageAccessor; const Radius: Integer;
  const K: Double = 0.5): IImageBuffer;

function BinarizeTextBySweep(const Src: IImageAccessor; out ChosenK: Double;
  const Radius: Integer = 10; const MaxK: Double = 0.81; const MinK: Double = 0.01;
  const StepK: Double = 0.05; const CloseW: Integer = 3; const CloseH: Integer = 3;
  const MinChain: Integer = 3; const SpaceRatio: Double = 1.5;
  const FgThreshold: Integer = 128): IImageBuffer;

function ScoreTextRows(const Bin: IImageAccessor; const CloseW: Integer = 3;
  const CloseH: Integer = 3; const MinChain: Integer = 3; const SpaceRatio: Double = 1.5;
  const FgThreshold: Integer = 128): Integer;

implementation

uses
  {$IFDEF FPC}Math{$ELSE}System.Math{$ENDIF}, CrossVision.Morphology, CrossVision.Contour;

type
  TIntegral = record
    W: Integer;
    H: Integer;
    Sum: TArray<Int64>;
    SqSum: TArray<Int64>;
    procedure Build(const Src: IImageAccessor);
    procedure WindowStats(const X, Y, Radius: Integer; out Mean, Std: Double);
  end;

procedure TIntegral.Build(const Src: IImageAccessor);
var
  X, Y, RowW: Integer;
  P: Int64;
begin
  W := Src.GetWidth;
  H := Src.GetHeight;
  RowW := W + 1;
  SetLength(Sum, RowW * (H + 1));
  SetLength(SqSum, RowW * (H + 1));
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      P := Src.GetPixel(X, Y);
      Sum[(Y + 1) * RowW + (X + 1)] := P + Sum[(Y + 1) * RowW + X] + Sum[Y * RowW + (X + 1)] -
        Sum[Y * RowW + X];
      SqSum[(Y + 1) * RowW + (X + 1)] := P * P + SqSum[(Y + 1) * RowW + X] +
        SqSum[Y * RowW + (X + 1)] - SqSum[Y * RowW + X];
    end;
end;

procedure TIntegral.WindowStats(const X, Y, Radius: Integer; out Mean, Std: Double);
var
  X0, Y0, X1, Y1, Area, RowW: Integer;
  S, SQ: Int64;
  V: Double;
begin
  RowW := W + 1;
  X0 := Max(0, X - Radius);
  Y0 := Max(0, Y - Radius);
  X1 := Min(W - 1, X + Radius);
  Y1 := Min(H - 1, Y + Radius);
  Area := (X1 - X0 + 1) * (Y1 - Y0 + 1);
  S := Sum[(Y1 + 1) * RowW + (X1 + 1)] - Sum[Y0 * RowW + (X1 + 1)] - Sum[(Y1 + 1) * RowW + X0] +
    Sum[Y0 * RowW + X0];
  SQ := SqSum[(Y1 + 1) * RowW + (X1 + 1)] - SqSum[Y0 * RowW + (X1 + 1)] -
    SqSum[(Y1 + 1) * RowW + X0] + SqSum[Y0 * RowW + X0];
  Mean := S / Area;
  V := SQ / Area - Mean * Mean;
  if V < 0 then V := 0;
  Std := Sqrt(V);
end;

function OtsuThreshold(const Src: IImageAccessor): Integer;
var
  Hist: array[0..255] of Integer;
  X, Y, T, Total, WB, WF: Integer;
  Sum, SumB, MeanB, MeanF, Between, MaxBetween: Double;
begin
  for T := 0 to 255 do Hist[T] := 0;
  for Y := 0 to Src.GetHeight - 1 do
    for X := 0 to Src.GetWidth - 1 do
      Inc(Hist[Src.GetPixel(X, Y)]);
  Total := Src.GetWidth * Src.GetHeight;
  if Total = 0 then Exit(0);
  Sum := 0;
  for T := 0 to 255 do Sum := Sum + T * Hist[T];
  WB := 0;
  SumB := 0;
  MaxBetween := -1;
  Result := 0;
  for T := 0 to 255 do
  begin
    Inc(WB, Hist[T]);
    if WB = 0 then Continue;
    WF := Total - WB;
    if WF = 0 then Break;
    SumB := SumB + T * Hist[T];
    MeanB := SumB / WB;
    MeanF := (Sum - SumB) / WF;
    Between := WB * WF * Sqr(MeanB - MeanF);
    if Between > MaxBetween then
    begin
      MaxBetween := Between;
      Result := T;
    end;
  end;
end;

function BinarizeOtsu(const Src: IImageAccessor): IImageBuffer;
var
  T, X, Y: Integer;
begin
  T := OtsuThreshold(Src);
  Result := MemoryImage(Src.GetWidth, Src.GetHeight);
  for Y := 0 to Src.GetHeight - 1 do
    for X := 0 to Src.GetWidth - 1 do
      if Src.GetPixel(X, Y) <= T then
        Result.SetPixel(X, Y, 0)
      else
        Result.SetPixel(X, Y, 255);
end;

function BinarizeNiblack(const Src: IImageAccessor; const Radius: Integer; const K: Double): IImageBuffer;
var
  II: TIntegral;
  X, Y: Integer;
  Mean, Std, T: Double;
begin
  II.Build(Src);
  Result := MemoryImage(II.W, II.H);
  for Y := 0 to II.H - 1 do
    for X := 0 to II.W - 1 do
    begin
      II.WindowStats(X, Y, Radius, Mean, Std);
      T := Mean + K * Std;
      if Src.GetPixel(X, Y) < T then
        Result.SetPixel(X, Y, 0)
      else
        Result.SetPixel(X, Y, 255);
    end;
end;

function BinarizeSauvola(const Src: IImageAccessor; const Radius: Integer; const K, R: Double): IImageBuffer;
var
  II: TIntegral;
  X, Y: Integer;
  Mean, Std, T: Double;
begin
  II.Build(Src);
  Result := MemoryImage(II.W, II.H);
  for Y := 0 to II.H - 1 do
    for X := 0 to II.W - 1 do
    begin
      II.WindowStats(X, Y, Radius, Mean, Std);
      T := Mean * (1 + K * (Std / R - 1));
      if Src.GetPixel(X, Y) < T then
        Result.SetPixel(X, Y, 0)
      else
        Result.SetPixel(X, Y, 255);
    end;
end;

function BinarizeWolfJolion(const Src: IImageAccessor; const Radius: Integer; const K: Double): IImageBuffer;
var
  II: TIntegral;
  X, Y: Integer;
  Mean, Std, T, MaxStd, MinGray: Double;
  P: Byte;
begin
  II.Build(Src);
  MaxStd := 0;
  MinGray := 255;
  for Y := 0 to II.H - 1 do
    for X := 0 to II.W - 1 do
    begin
      II.WindowStats(X, Y, Radius, Mean, Std);
      if Std > MaxStd then MaxStd := Std;
      P := Src.GetPixel(X, Y);
      if P < MinGray then MinGray := P;
    end;
  if MaxStd <= 0 then MaxStd := 1;
  Result := MemoryImage(II.W, II.H);
  for Y := 0 to II.H - 1 do
    for X := 0 to II.W - 1 do
    begin
      II.WindowStats(X, Y, Radius, Mean, Std);
      T := Mean - K * (1 - Std / MaxStd) * (Mean - MinGray);
      if Src.GetPixel(X, Y) < T then
        Result.SetPixel(X, Y, 0)
      else
        Result.SetPixel(X, Y, 255);
    end;
end;

function ScoreTextRows(const Bin: IImageAccessor; const CloseW, CloseH, MinChain: Integer;
  const SpaceRatio: Double; const FgThreshold: Integer): Integer;
var
  Closed: IImageBuffer;
  Comps: TComponentInfoArray;
  Labels: TArray<Integer>;
  Order: TArray<Integer>;
  Used: TArray<Boolean>;
  I, J, K, Tmp, Chain, Gap: Integer;
  X, Y, Pad, PW, PH: Integer;
  Padded: IImageBuffer;
  Row: TArray<Integer>;

  function OverlapsVertically(const A, B: Integer): Boolean;
  begin
    Result := (Comps[A].Bounds.Top <= Comps[B].Bounds.Bottom) and
      (Comps[B].Bounds.Top <= Comps[A].Bounds.Bottom);
  end;

begin
  Result := 0;
  Pad := CloseW;
  if CloseH > Pad then
    Pad := CloseH;
  if Pad < 1 then
    Pad := 1;
  PW := Bin.GetWidth + 2 * Pad;
  PH := Bin.GetHeight + 2 * Pad;
  if (PW <= 0) or (PH <= 0) then
    Exit;
  Padded := MemoryImage(PW, PH);
  for Y := 0 to PH - 1 do
    for X := 0 to PW - 1 do
      Padded.SetPixel(X, Y, 255);
  for Y := 0 to Bin.GetHeight - 1 do
    for X := 0 to Bin.GetWidth - 1 do
      Padded.SetPixel(X + Pad, Y + Pad, Bin.GetPixel(X, Y));
  Closed := IntersectImages(CloseRect(Padded, CloseW, 1, FgThreshold),
                            CloseRect(Padded, 1, CloseH, FgThreshold),
                            FgThreshold);
  Comps := LabelComponents(Closed, Labels, True, FgThreshold);
  if Length(Comps) = 0 then
    Exit;
  SetLength(Order, Length(Comps));
  for I := 0 to High(Order) do
    Order[I] := I;
  for I := 0 to High(Order) - 1 do
    for J := 0 to High(Order) - 1 - I do
      if Comps[Order[J]].Bounds.Left > Comps[Order[J + 1]].Bounds.Left then
      begin
        Tmp := Order[J];
        Order[J] := Order[J + 1];
        Order[J + 1] := Tmp;
      end;
  SetLength(Used, Length(Comps));
  for I := 0 to High(Order) do
  begin
    if Used[Order[I]] then
      Continue;
    Row := nil;
    SetLength(Row, 1);
    Row[0] := Order[I];
    Used[Order[I]] := True;
    K := Row[0];
    for J := I + 1 to High(Order) do
    begin
      if Used[Order[J]] then
        Continue;
      if not OverlapsVertically(K, Order[J]) then
        Continue;
      Gap := Comps[Order[J]].Bounds.Left - Comps[K].Bounds.Right - 1;
      if Gap < 0 then
        Gap := 0;
      if Gap > Round((Comps[K].Bounds.Right - Comps[K].Bounds.Left + 1) * SpaceRatio) then
        Break;
      SetLength(Row, Length(Row) + 1);
      Row[High(Row)] := Order[J];
      Used[Order[J]] := True;
      K := Order[J];
    end;
    Chain := Length(Row);
    if Chain >= MinChain then
      Inc(Result, Chain);
  end;
end;

function BinarizeTextBySweep(const Src: IImageAccessor; out ChosenK: Double; const Radius: Integer;
  const MaxK, MinK, StepK: Double; const CloseW, CloseH, MinChain: Integer;
  const SpaceRatio: Double; const FgThreshold: Integer): IImageBuffer;
var
  K, BestK: Double;
  Score, Best, Ties, Guard: Integer;
begin
  ChosenK := (MaxK + MinK) / 2;
  if (Src.GetWidth <= 0) or (Src.GetHeight <= 0) then
    Exit(MemoryImage(0, 0));
  if (StepK <= 0) or (MaxK <= MinK) then
    Exit(BinarizeWolfJolion(Src, Radius, ChosenK));
  Best := -1;
  BestK := ChosenK;
  Ties := 0;
  K := MaxK;
  Guard := 0;
  while (K >= MinK) and (Guard < 1000) do
  begin
    Inc(Guard);
    Score := ScoreTextRows(BinarizeWolfJolion(Src, Radius, K),
                           CloseW, CloseH, MinChain, SpaceRatio, FgThreshold);
    if Score > Best then
    begin
      Best := Score;
      BestK := K;
      Ties := 1;
    end
    else if Score = Best then
        Inc(Ties);
    K := K - StepK;
  end;
  if (Best <= 0) or (Ties > 1) then
    ChosenK := (MaxK + MinK) / 2
  else
    ChosenK := BestK;
  Result := BinarizeWolfJolion(Src, Radius, ChosenK);
end;

end.
