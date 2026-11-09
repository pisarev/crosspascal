unit ExampleDefaults;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

interface

function PreparedValue(const Key: string; const Default: string = ''): string;
function PreparedPath(const Key: string; const Default: string = ''): string;
function HasPreparedExample: Boolean;

implementation

uses
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF};

function DefaultsFile: string;
var
  Current, Parent, Candidate, Name: string;
  I: Integer;
begin
  Result := '';
  Current := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Name := ChangeFileExt(ExtractFileName(ParamStr(0)), '.prepared.ini');
  for I := 0 to 10 do
  begin
    Candidate := IncludeTrailingPathDelimiter(Current) + Name;
    if FileExists(Candidate) then Exit(Candidate);
    Parent := ExtractFileDir(Current);
    if SameText(Parent, Current) then Break;
    Current := Parent;
  end;
end;

function PreparedValue(const Key, Default: string): string;
var
  Path, Line: string;
  Settings: TStringList;
  I, Split: Integer;
  InExample: Boolean;
begin
  Result := Default;
  Path := DefaultsFile;
  if Path = '' then Exit;
  Settings := TStringList.Create;
  try
    Settings.LoadFromFile(Path, TEncoding.UTF8);
    InExample := False;
    for I := 0 to Settings.Count - 1 do
    begin
      Line := Trim(Settings[I]);
      if Line = '' then Continue;
      if Line[1] = '[' then
        InExample := SameText(Line, '[example]')
      else if InExample then
        begin
          Split := Pos('=', Line);
          if (Split > 0) and SameText(Trim(Copy(Line, 1, Split - 1)), Key) then
            Exit(Trim(Copy(Line, Split + 1, MaxInt)));
        end;
    end;
  finally
    Settings.Free;
  end;
end;

function PreparedPath(const Key, Default: string): string;
var
  Value: string;
begin
  Value := PreparedValue(Key, Default);
  if Value = '' then Exit('');
  if (ExtractFileDrive(Value) <> '') or (Copy(Value, 1, 2) = '\\') then
    Result := ExpandFileName(Value)
  else
    Result := ExpandFileName(ExtractFilePath(DefaultsFile) + Value);
end;

function HasPreparedExample: Boolean;
begin
  Result := DefaultsFile <> '';
end;

end.
