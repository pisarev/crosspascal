program TestDisjointSet;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  CrossVision.DisjointSet;

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

var
  DS: TDisjointSet;
begin
  DS.Init(5);
  Check(DS.Count = 5, 'Init: 5 elements');
  Check(DS.SetCount = 5, 'Init: 5 distinct sets');
  Check(not DS.Connected(0, 1), 'Initially: 0 and 1 are not connected');
  DS.Union(0, 1);
  DS.Union(1, 2);
  Check(DS.Connected(0, 2), 'After Union(0,1),(1,2): 0 and 2 are connected');
  Check(not DS.Connected(0, 3), '0 and 3 are not connected yet');
  Check(DS.SetCount = 3, '3 sets: {0,1,2},{3},{4}');
  DS.Union(3, 4);
  Check(DS.Connected(3, 4) and not DS.Connected(2, 4), '{3,4} is separate from {0,1,2}');
  DS.Union(2, 3);
  Check(DS.Connected(0, 4), 'After Union(2,3): all elements are connected');
  Check(DS.SetCount = 1, 'One set contains all elements');
  Writeln('');
  Writeln(Format('PASSED %d, FAILED %d', [Passed, Failed]));
  if Failed > 0 then
    Halt(1);
end.
