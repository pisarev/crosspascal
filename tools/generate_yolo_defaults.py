"""Generate YoloModels.Defaults.pas from the final prepared index pins."""
import json
import os
import re
import sys
from pathlib import Path

IDS = ('n', 's', 'm', 'b', 'l', 'x', 'all')
FIELDS = {'id', 'file', 'sha256', 'bytes'}
LIMIT = 1024 * 1024

TEMPLATE = r"""unit YoloModels.Defaults;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  YoloModels.Config;

const
  YoloPreparedIndexSHA256 = '@N_SHA256@';
  YoloPreparedIndexBytes = @N_BYTES@;

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
@ROWS@
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
"""


def index_file(kit):
    if kit == 'n':
        return 'index.json'
    if kit == 'all':
        return 'index-all.json'
    return 'index-' + kit + '.json'


def unique_object(pairs):
    result = dict(pairs)
    if len(result) != len(pairs):
        raise ValueError('A pin record repeats a field.')
    return result


def load_pins(path):
    rows = json.loads(path.read_bytes().decode('utf-8'), object_pairs_hook=unique_object)
    if type(rows) is not list or len(rows) != len(IDS):
        raise ValueError('Expected exactly seven index pins.')
    pins = {}
    digests = set()
    for row in rows:
        if type(row) is not dict or set(row) != FIELDS:
            raise ValueError('A pin needs exactly id, file, sha256 and bytes.')
        kit, digest, size = row['id'], row['sha256'], row['bytes']
        if type(kit) is not str or kit not in IDS or kit in pins:
            raise ValueError('Unknown or repeated kit id: %r' % (kit,))
        if row['file'] != index_file(kit):
            raise ValueError('Unexpected index file for kit ' + kit)
        if type(digest) is not str or not re.fullmatch('[0-9a-f]{64}', digest):
            raise ValueError('Invalid SHA-256 for kit ' + kit)
        if digest in digests:
            raise ValueError('Two kits have the same index SHA-256.')
        if type(size) is not int or not 0 < size <= LIMIT:
            raise ValueError('Invalid index size for kit ' + kit)
        digests.add(digest)
        pins[kit] = (digest, size)
    return pins


def render(pins):
    rows = []
    for kit in IDS:
        digest, size = pins[kit]
        sha = 'YoloPreparedIndexSHA256' if kit == 'n' else "'" + digest + "'"
        count = 'YoloPreparedIndexBytes' if kit == 'n' else str(size)
        rows.append("    (ID: '%s'; IndexMember: '%s';\n      SHA256: %s;\n      Bytes: %s)"
                    % (kit, index_file(kit), sha, count))
    text = TEMPLATE.replace('@N_SHA256@', pins['n'][0])
    text = text.replace('@N_BYTES@', str(pins['n'][1]))
    return text.replace('@ROWS@', ',\n'.join(rows))


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: generate_yolo_defaults.py PINS.json OUTPUT.pas')
    output = Path(sys.argv[2])
    body = render(load_pins(Path(sys.argv[1]))).replace('\n', '\r\n').encode('utf-8')
    partial = output.with_name(output.name + '.partial')
    partial.write_bytes(body)
    os.replace(partial, output)


if __name__ == '__main__':
    main()
