{ ************************************************************************** }
{                                                                            }
{ CrossVision.Image.OpenCV                                                   }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Image.OpenCV;

interface

uses
  OpenCVTypes,
  CrossVision.Image;

function GrayMatAccessor(const Mat: TMat): IImageAccessor;

function WriteToGrayMat(const Src: IImageAccessor; const Mat: TMat): Boolean;

implementation

uses
  OpenCV;

type
  TMatImageAccessor = class(TInterfacedObject, IImageAccessor)
  private
    FW: Integer;
    FH: Integer;
    FStep: Integer;
    FData: PByte;
  public
    constructor Create(const Mat: TMat);
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetPixel(const X, Y: Integer): Byte;
  end;

constructor TMatImageAccessor.Create(const Mat: TMat);
var
  P: Pointer;
begin
  inherited Create;
  FW := 0;
  FH := 0;
  FStep := 0;
  P := nil;
  CV.Core.GetMatHSize(Mat, @FW);
  CV.Core.GetMatVSize(Mat, @FH);
  CV.Core.GetMatStep(Mat, @FStep);
  CV.Core.GetMatData(Mat, @P);
  FData := P;
end;

function TMatImageAccessor.GetWidth: Integer;
begin
  Result := FW;
end;

function TMatImageAccessor.GetHeight: Integer;
begin
  Result := FH;
end;

function TMatImageAccessor.GetPixel(const X, Y: Integer): Byte;
begin
  if (FData = nil) or (X < 0) or (Y < 0) or (X >= FW) or (Y >= FH) then
    Result := 0
  else
    Result := PByte(NativeInt(FData) + Y * FStep + X)^;
end;

function GrayMatAccessor(const Mat: TMat): IImageAccessor;
begin
  Result := TMatImageAccessor.Create(Mat);
end;

function WriteToGrayMat(const Src: IImageAccessor; const Mat: TMat): Boolean;
var
  W, H, Step, X, Y: Integer;
  P: Pointer;
  D: PByte;
begin
  W := 0;
  H := 0;
  Step := 0;
  P := nil;
  CV.Core.GetMatHSize(Mat, @W);
  CV.Core.GetMatVSize(Mat, @H);
  CV.Core.GetMatStep(Mat, @Step);
  CV.Core.GetMatData(Mat, @P);
  D := P;
  Result := (D <> nil) and (W = Src.GetWidth) and (H = Src.GetHeight);
  if not Result then Exit;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
      PByte(NativeInt(D) + Y * Step + X)^ := Src.GetPixel(X, Y);
end;

end.
