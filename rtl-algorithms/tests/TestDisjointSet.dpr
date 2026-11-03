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
  Check(DS.Count = 5, 'Init: 5 элементов');
  Check(DS.SetCount = 5, 'Init: 5 различных множеств');
  Check(not DS.Connected(0, 1), 'Старт: 0 и 1 не связаны');
  DS.Union(0, 1);
  DS.Union(1, 2);
  Check(DS.Connected(0, 2), 'После Union(0,1),(1,2): 0 и 2 связаны');
  Check(not DS.Connected(0, 3), '0 и 3 ещё не связаны');
  Check(DS.SetCount = 3, '3 множества: {0,1,2},{3},{4}');
  DS.Union(3, 4);
  Check(DS.Connected(3, 4) and not DS.Connected(2, 4), '{3,4} отдельно от {0,1,2}');
  DS.Union(2, 3);
  Check(DS.Connected(0, 4), 'После Union(2,3): все связаны');
  Check(DS.SetCount = 1, 'Одно множество на всех');
  Writeln('');
  Writeln(Format('PASSED %d, FAILED %d', [Passed, Failed]));
  if Failed > 0 then
    Halt(1);
end.
