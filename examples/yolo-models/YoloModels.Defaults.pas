unit YoloModels.Defaults;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  YoloModels.Config;

const
  YoloPreparedIndexSHA256 = 'e64ec6b047a15f32db2678b8ccb329b87b1333f283691008e2c9e0b8a577687f';
  YoloPreparedIndexBytes = 27726;

{ yolo-kit.txt only selects one of the indexes compiled into this unit.
  Without that file the n kit is used. Conversion uses the complete index. }
function CreateYoloPreparedConfig(const Directory: string;
  const ForConversion: Boolean = False): TYoloExampleConfig;

implementation

uses
  {$IFDEF UNIX}BaseUnix{$ELSE}{$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF}{$ENDIF},
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF}, CrossPascal.NativeIO;

type
  TYoloPreparedIndex = record
    ID: string;
    IndexMember: string;
    SHA256: string;
    Bytes: Int64;
  end;

const
  YoloKitMaxBytes = 64;
  YoloPreparedIndexes: array[0..6] of TYoloPreparedIndex = (
    (ID: 'n'; IndexMember: 'index.json';
      SHA256: YoloPreparedIndexSHA256;
      Bytes: YoloPreparedIndexBytes),
    (ID: 's'; IndexMember: 'index-s.json';
      SHA256: 'a5dab130035b4f2580810a85ce9b3d88be6ce40f7194d0399f3bcee7064a9d2f';
      Bytes: 27728),
    (ID: 'm'; IndexMember: 'index-m.json';
      SHA256: 'a83c919a647fda773a57857d188054ab022c577c241eee2dc0fc0ab8f19541be';
      Bytes: 26565),
    (ID: 'b'; IndexMember: 'index-b.json';
      SHA256: 'b215b52d3da17a0096f3da7ff0e450fe206cb0426ec6f3f99d82a45277a22b68';
      Bytes: 1640),
    (ID: 'l'; IndexMember: 'index-l.json';
      SHA256: '2c2ba96274780710e1eeec2bded389e90ce541586802fe28c767011fa9b0cf17';
      Bytes: 27728),
    (ID: 'x'; IndexMember: 'index-x.json';
      SHA256: '550b92d440b8675f0922bfd57f6a250eb8f354218ce4750d6f2f959a1b158738';
      Bytes: 27728),
    (ID: 'all'; IndexMember: 'index-all.json';
      SHA256: '3b3775612149905f42cec29a062d2187927152678076ba312143dcc6bfe43d74';
      Bytes: 136726)
  );

function YoloKitExists(const FileName: string): Boolean;
{$IFDEF UNIX}
var
  Info: Stat;
  Code: Integer;
begin
  Result := fpStat(PAnsiChar(UTF8Encode(FileName)), Info) = 0;
  if Result then Exit;
  Code := fpGetErrNo;
  if Code <> ESysENOENT then RaiseLastOSError(Code);
end;
{$ELSE}
var
  Code: DWORD;
begin
  Result := GetFileAttributesW(PWideChar(FileName)) <> $FFFFFFFF;
  if Result then Exit;
  Code := GetLastError;
  if Code <> ERROR_FILE_NOT_FOUND then RaiseLastOSError(Integer(Code));
end;
{$ENDIF}

function ReadYoloKit(const FileName: string): string;
var
  Stream: TNativeReadStream;
  Content: TBytes;
  Size: Int64;
  First, Last, I: Integer;
begin
  Stream := TNativeReadStream.Create(FileName);
  try
    Size := Stream.Size;
    if (Size < 1) or (Size > YoloKitMaxBytes) then
      raise EArgumentException.Create('yolo-kit.txt must contain 1 to 64 bytes.');
    SetLength(Content, Integer(Size));
    Stream.ReadBuffer(Content[0], Length(Content));
  finally
    Stream.Free;
  end;
  First := 0;
  if (Length(Content) >= 3) and (Content[0] = $EF) and (Content[1] = $BB) and
    (Content[2] = $BF) then First := 3;
  Last := High(Content);
  if (Last >= First) and (Content[Last] = 10) then
  begin
    Dec(Last);
    if (Last >= First) and (Content[Last] = 13) then Dec(Last);
  end;
  Result := '';
  for I := First to Last do
    Result := Result + Char(Content[I]);
end;

function CreateYoloPreparedConfig(const Directory: string;
  const ForConversion: Boolean): TYoloExampleConfig;
var
  ID, FileName: string;
  I: Integer;
begin
  ID := 'n';
  if ForConversion then
    ID := 'all'
  else
  begin
    FileName := YoloPreparedPath(Directory, 'yolo-kit.txt');
    if YoloKitExists(FileName) then ID := ReadYoloKit(FileName);
  end;
  for I := Low(YoloPreparedIndexes) to High(YoloPreparedIndexes) do
    if YoloPreparedIndexes[I].ID = ID then
      Exit(TYoloExampleConfig.Create(Directory, YoloPreparedIndexes[I].SHA256,
        YoloPreparedIndexes[I].Bytes, YoloPreparedIndexes[I].IndexMember));
  raise EArgumentException.Create('yolo-kit.txt must contain n, s, m, b, l, x, or all.');
end;

end.
