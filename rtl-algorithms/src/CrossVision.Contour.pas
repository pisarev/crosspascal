{ ************************************************************************** }
{                                                                            }
{ CrossVision.Contour                                                        }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                                             }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Contour;

interface

uses CrossVision.Image, CrossVision.Curve,
  {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF};

function FindContours(const Src: IImageAccessor; const FgThreshold: Integer = 128): TArray<TPolyline>;

type
  TComponentInfo = record
    Bounds: TRect;
    Area: Integer;
    Perimeter: Integer;
  end;
  TComponentInfoArray = TArray<TComponentInfo>;

function LabelComponents(const Src: IImageAccessor; out Labels: TArray<Integer>;
  const EightWay: Boolean = True; const FgThreshold: Integer = 128): TComponentInfoArray;

implementation

uses
  CrossVision.DisjointSet;

const
  DX: array[0..7] of Integer = (0, 1, 1, 1, 0, -1, -1, -1);
  DY: array[0..7] of Integer = (-1, -1, 0, 1, 1, 1, 0, -1);

function IsForeground(const Src: IImageAccessor; const W, H, X, Y, FgThreshold: Integer): Boolean;
begin
  Result := (X >= 0) and (Y >= 0) and (X < W) and (Y < H) and (Src.GetPixel(X, Y) < FgThreshold);
end;

function Fg_At(const Fg: TArray<Boolean>; const W, H, X, Y: Integer): Boolean;
begin
  Result := (X >= 0) and (Y >= 0) and (X < W) and (Y < H) and Fg[Y * W + X];
end;

function FindContours(const Src: IImageAccessor; const FgThreshold: Integer): TArray<TPolyline>;
var
  W, H, X, Y, SX, SY, CX, CY, B, D, K, NX, NY, Steps, MaxSteps: Integer;
  Visited: TArray<Boolean>;
  Contour: TPolyline;
  Found: Boolean;
begin
  W := Src.GetWidth;
  H := Src.GetHeight;
  SetLength(Visited, W * H);
  Result := nil;
  MaxSteps := 4 * (W + H) + 16;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
      if IsForeground(Src, W, H, X, Y, FgThreshold) and (not Visited[Y * W + X]) and
        (not IsForeground(Src, W, H, X - 1, Y, FgThreshold)) then
        begin
          Contour := nil;
          SX := X;
          SY := Y;
          CX := X;
          CY := Y;
          SetLength(Contour, 1);
          Contour[0] := Point(CX, CY);
          Visited[CY * W + CX] := True;
          B := 6;
          Steps := 0;
          repeat
            Found := False;
            for K := 1 to 8 do
            begin
              D := (B + K) mod 8;
              NX := CX + DX[D];
              NY := CY + DY[D];
              if IsForeground(Src, W, H, NX, NY, FgThreshold) then
              begin
                CX := NX;
                CY := NY;
                B := (D + 4) mod 8;
                Found := True;
                Break;
              end;
            end;
            if not Found then Break;
            Inc(Steps);
            if (CX = SX) and (CY = SY) then Break;
            SetLength(Contour, Length(Contour) + 1);
            Contour[High(Contour)] := Point(CX, CY);
            Visited[CY * W + CX] := True;
          until Steps > MaxSteps;
          if Length(Contour) >= 2 then
          begin
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Contour;
          end;
        end;
end;

function LabelComponents(const Src: IImageAccessor; out Labels: TArray<Integer>;
  const EightWay: Boolean; const FgThreshold: Integer): TComponentInfoArray;
var
  W, H, X, Y, I, N, Root, Idx, Next: Integer;
  Sets: TDisjointSet;
  Provisional: TArray<Integer>;
  Compact: TArray<Integer>;
  Fg: TArray<Boolean>;

  function Provisional_At(const AX, AY: Integer): Integer;
  begin
    if (AX < 0) or (AY < 0) or (AX >= W) or (AY >= H) then
      Result := 0
    else
      Result := Provisional[AY * W + AX];
  end;

  procedure Attach(const Current, AX, AY: Integer);
  var
    Other: Integer;
  begin
    Other := Provisional_At(AX, AY);
    if Other <> 0 then
      Sets.Union(Current - 1, Other - 1);
  end;

begin
  Result := nil;
  Labels := nil;
  W := Src.GetWidth;
  H := Src.GetHeight;
  if (W <= 0) or (H <= 0) then
    Exit;
  SetLength(Fg, W * H);
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
      Fg[Y * W + X] := Src.GetPixel(X, Y) < FgThreshold;
  SetLength(Provisional, W * H);
  Sets.Init(W * H);
  N := 0;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
      if Fg[Y * W + X] then
      begin
        Inc(N);
        Provisional[Y * W + X] := N;
        Attach(N, X - 1, Y);
        Attach(N, X, Y - 1);
        if EightWay then
        begin
          Attach(N, X - 1, Y - 1);
          Attach(N, X + 1, Y - 1);
        end;
      end;
  if N = 0 then
  begin
    SetLength(Labels, W * H);
    Exit;
  end;
  SetLength(Compact, N + 1);
  Next := 0;
  SetLength(Labels, W * H);
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      I := Provisional[Y * W + X];
      if I = 0 then
        Continue;
      Root := Sets.Find(I - 1) + 1;
      if Compact[Root] = 0 then
      begin
        Inc(Next);
        Compact[Root] := Next;
        SetLength(Result, Next);
        Result[Next - 1].Bounds := Rect(X, Y, X, Y);
        Result[Next - 1].Area := 0;
        Result[Next - 1].Perimeter := 0;
      end;
      Labels[Y * W + X] := Compact[Root];
    end;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      Idx := Labels[Y * W + X];
      if Idx = 0 then
        Continue;
      Dec(Idx);
      if X < Result[Idx].Bounds.Left then Result[Idx].Bounds.Left := X;
      if X > Result[Idx].Bounds.Right then Result[Idx].Bounds.Right := X;
      if Y < Result[Idx].Bounds.Top then Result[Idx].Bounds.Top := Y;
      if Y > Result[Idx].Bounds.Bottom then Result[Idx].Bounds.Bottom := Y;
      Inc(Result[Idx].Area);
      if (not Fg_At(Fg, W, H, X - 1, Y)) or (not Fg_At(Fg, W, H, X + 1, Y)) or
        (not Fg_At(Fg, W, H, X, Y - 1)) or (not Fg_At(Fg, W, H, X, Y + 1)) then
          Inc(Result[Idx].Perimeter);
    end;
end;

end.
