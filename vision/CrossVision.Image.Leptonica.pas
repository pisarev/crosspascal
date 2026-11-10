{ ************************************************************************** }
{                                                                            }
{ CrossVision.Image.Leptonica                                                }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Image.Leptonica;

interface

uses
  CrossVision.Pix,
  CrossVision.Image;

function GrayPixAccessor(const Src: IPix): IImageAccessor;

function WriteToGrayPix(const Src: IImageAccessor; const Target: IPix): Boolean;

implementation

type
  TPixImageAccessor = class(TInterfacedObject, IImageAccessor)
  private
    FPix: IPix;
    FW: Integer;
    FH: Integer;
  public
    constructor Create(const Src: IPix);
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetPixel(const X, Y: Integer): Byte;
  end;

constructor TPixImageAccessor.Create(const Src: IPix);
begin
  inherited Create;
  FW := 0;
  FH := 0;
  if Src = nil then
    Exit;
  if Src.GetDepth = 8 then
    FPix := Src
  else
    FPix := Src.ConvertTo8;
  if FPix = nil then
    Exit;
  FW := FPix.GetWidth;
  FH := FPix.GetHeight;
end;

function TPixImageAccessor.GetWidth: Integer;
begin
  Result := FW;
end;

function TPixImageAccessor.GetHeight: Integer;
begin
  Result := FH;
end;

function TPixImageAccessor.GetPixel(const X, Y: Integer): Byte;
begin
  if (FPix = nil) or (X < 0) or (Y < 0) or (X >= FW) or (Y >= FH) then
    Result := 0
  else
    Result := Byte(FPix.GetPixel(X, Y));
end;

function GrayPixAccessor(const Src: IPix): IImageAccessor;
begin
  Result := TPixImageAccessor.Create(Src);
end;

function WriteToGrayPix(const Src: IImageAccessor; const Target: IPix): Boolean;
var
  X, Y: Integer;
begin
  Result := (Src <> nil) and (Target <> nil) and (Target.GetDepth = 8) and
    (Src.GetWidth = Target.GetWidth) and
    (Src.GetHeight = Target.GetHeight);
  if not Result then
    Exit;
  for Y := 0 to Target.GetHeight - 1 do
    for X := 0 to Target.GetWidth - 1 do
      Target.SetPixel(X, Y, Src.GetPixel(X, Y));
end;

end.
