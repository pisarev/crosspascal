{ ************************************************************************** }
{                                                                            }
{ CrossVision.Image                                                          }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Image;

interface

type
  IImageAccessor = interface
    ['{6B1F0E10-1A2B-4C3D-9E4F-AA5566778801}']
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetPixel(const X, Y: Integer): Byte;
  end;

  IImageBuffer = interface(IImageAccessor)
    ['{6B1F0E10-1A2B-4C3D-9E4F-AA5566778802}']
    procedure SetPixel(const X, Y: Integer; const Value: Byte);
    function GetData: TArray<Byte>;
  end;

  TMemoryImage = class(TInterfacedObject, IImageAccessor, IImageBuffer)
  private
    FWidth: Integer;
    FHeight: Integer;
    FData: TArray<Byte>;
  public
    constructor Create(const AWidth, AHeight: Integer); overload;
    constructor Create(const AWidth, AHeight: Integer; const AData: TArray<Byte>); overload;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetPixel(const X, Y: Integer): Byte;
    procedure SetPixel(const X, Y: Integer; const Value: Byte);
    function GetData: TArray<Byte>;
  end;

function MemoryImage(const AWidth, AHeight: Integer): IImageBuffer;

implementation

constructor TMemoryImage.Create(const AWidth, AHeight: Integer);
begin
  inherited Create;
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FData, AWidth * AHeight);
end;

constructor TMemoryImage.Create(const AWidth, AHeight: Integer; const AData: TArray<Byte>);
begin
  Create(AWidth, AHeight);
  if Length(AData) = Length(FData) then
    FData := Copy(AData);
end;

function TMemoryImage.GetWidth: Integer;
begin
  Result := FWidth;
end;

function TMemoryImage.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TMemoryImage.GetPixel(const X, Y: Integer): Byte;
begin
  if (X < 0) or (Y < 0) or (X >= FWidth) or (Y >= FHeight) then
    Result := 0
  else
    Result := FData[Y * FWidth + X];
end;

procedure TMemoryImage.SetPixel(const X, Y: Integer; const Value: Byte);
begin
  if (X >= 0) and (Y >= 0) and (X < FWidth) and (Y < FHeight) then
    FData[Y * FWidth + X] := Value;
end;

function TMemoryImage.GetData: TArray<Byte>;
begin
  Result := FData;
end;

function MemoryImage(const AWidth, AHeight: Integer): IImageBuffer;
begin
  Result := TMemoryImage.Create(AWidth, AHeight);
end;

end.
