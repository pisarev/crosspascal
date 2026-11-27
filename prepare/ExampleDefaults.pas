unit ExampleDefaults;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

function PreparedValue(const Key: string; const Default: string = ''): string;
function PreparedPath(const Key: string; const Default: string = ''): string;
function HasPreparedExample: Boolean;
function PreparedSdkPath(const RelativePath: string; const IsDirectory: Boolean): string;

implementation

uses
  {$IFDEF MSWINDOWS}{$IFDEF FPC}Windows,{$ELSE}Winapi.Windows,{$ENDIF}{$ENDIF}
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF};

function ExecutablePath: string;
{$IFDEF MSWINDOWS}
var
  Buffer: array[0..32767] of WideChar;
  Count: DWORD;
begin
  Count := GetModuleFileNameW(0, @Buffer[0], Length(Buffer));
  if (Count = 0) or (Count >= DWORD(Length(Buffer))) then
    raise Exception.Create('Cannot read the application path.');
  SetString(Result, PWideChar(@Buffer[0]), Count);
end;
{$ELSE}
begin
  Result := {$IFDEF FPC}UTF8Decode{$ENDIF}(ParamStr(0));
end;
{$ENDIF}

function DefaultsFile: string;
var
  Current, Parent, Candidate, Name, ApplicationPath: string;
  I: Integer;
begin
  Result := '';
  ApplicationPath := ExecutablePath;
  Current := ExcludeTrailingPathDelimiter(ExtractFilePath(ApplicationPath));
  Name := ChangeFileExt(ExtractFileName(ApplicationPath), '.prepared.ini');
  for I := 0 to 10 do
  begin
    Candidate := IncludeTrailingPathDelimiter(Current) + Name;
    if FileExists(Candidate) then Exit(Candidate);
    Parent := ExtractFileDir(Current);
    if SameText(Parent, Current) then Break;
    Current := Parent;
  end;
end;

function ReadDefaults(const Path: string): string;
var
  Stream: TStream;
  Data: TBytes;
  {$IFDEF MSWINDOWS}
  Handle: THandle;{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Handle := CreateFileW(PWideChar(Path), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then RaiseLastOSError;
  try
    Stream := THandleStream.Create(Handle);
  {$ELSE}
    Stream := TFileStream.Create({$IFDEF FPC}UTF8Encode{$ENDIF}(Path), fmOpenRead or fmShareDenyWrite);
  {$ENDIF}
    try
      if Stream.Size > MaxInt then
        raise Exception.Create('Prepared settings file is too large.');
      SetLength(Data, Integer(Stream.Size));
      if Length(Data) > 0 then Stream.ReadBuffer(Data[0], Length(Data));
      Result := TEncoding.UTF8.GetString(Data);
      if (Result <> '') and (Result[1] = #$FEFF) then Delete(Result, 1, 1);
    finally
      Stream.Free;
    end;
  {$IFDEF MSWINDOWS}
  finally
    CloseHandle(Handle);
  end;
  {$ENDIF}
end;

function PreparedValue(const Key, Default: string): string;
var
  Path, Text, Line: string;
  Start, Finish, Split: Integer;
  InExample: Boolean;
begin
  Result := Default;
  Path := DefaultsFile;
  if Path = '' then Exit;
  Text := ReadDefaults(Path);
  InExample := False;
  Start := 1;
  while Start <= Length(Text) do
  begin
    Finish := Start;
    while (Finish <= Length(Text)) and (Text[Finish] <> #13) and (Text[Finish] <> #10) do
      Inc(Finish);
    Line := Trim(Copy(Text, Start, Finish - Start));
    Start := Finish;
    while (Start <= Length(Text)) and ((Text[Start] = #13) or (Text[Start] = #10)) do Inc(Start);
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

function PreparedSdkPath(const RelativePath: string; const IsDirectory: Boolean): string;
var
  Root, Candidate: string;
begin
  Result := '';
  Root := PreparedPath('sdk');
  if Root = '' then Exit;
  Candidate := ExpandFileName(IncludeTrailingPathDelimiter(Root) + RelativePath);
  if (IsDirectory and DirectoryExists(Candidate)) or
    (not IsDirectory and FileExists(Candidate)) then
      Result := Candidate;
end;

end.
