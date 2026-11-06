{ ************************************************************************** }
{                                                                            }
{ CrossVision.DisjointSet                                                    }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.DisjointSet;

interface

type
  TDisjointSet = record
  private
    FParent: TArray<Integer>;
    FRank: TArray<Byte>;
  public
    procedure Init(const Count: Integer);
    function Find(const X: Integer): Integer;
    procedure Union(const A, B: Integer);
    function Connected(const A, B: Integer): Boolean;
    function Count: Integer;
    function SetCount: Integer;
  end;

implementation

procedure TDisjointSet.Init(const Count: Integer);
var
  I: Integer;
begin
  SetLength(FParent, Count);
  SetLength(FRank, Count);
  for I := 0 to Count - 1 do
  begin
    FParent[I] := I;
    FRank[I] := 0;
  end;
end;

function TDisjointSet.Find(const X: Integer): Integer;
var
  Root, Node, Next: Integer;
begin
  Root := X;
  while FParent[Root] <> Root do
    Root := FParent[Root];
  Node := X;
  while FParent[Node] <> Root do
  begin
    Next := FParent[Node];
    FParent[Node] := Root;
    Node := Next;
  end;
  Result := Root;
end;

procedure TDisjointSet.Union(const A, B: Integer);
var
  RA, RB, T: Integer;
begin
  RA := Find(A);
  RB := Find(B);
  if RA = RB then Exit;
  if FRank[RA] < FRank[RB] then
  begin
    T := RA;
    RA := RB;
    RB := T;
  end;
  FParent[RB] := RA;
  if FRank[RA] = FRank[RB] then
    Inc(FRank[RA]);
end;

function TDisjointSet.Connected(const A, B: Integer): Boolean;
begin
  Result := Find(A) = Find(B);
end;

function TDisjointSet.Count: Integer;
begin
  Result := Length(FParent);
end;

function TDisjointSet.SetCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FParent) do
    if FParent[I] = I then
      Inc(Result);
end;

end.
