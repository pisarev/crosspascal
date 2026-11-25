{ ************************************************************************** }
{                                                                            }
{ YoloModels.Render                                                           }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                       }
{                                                                            }
{ ************************************************************************** }

unit YoloModels.Render;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  CrossVision.Mat, TVM.CpuGraph, YoloModels.Run;

type
  TYoloTextMode = (ytAuto, ytAll, ytNone);
  TYoloRGB = record
    Red: Byte;
    Green: Byte;
    Blue: Byte;
  end;
  TYoloViewLabel = record
    X: Integer;
    Y: Integer;
    Text: string;
    Color: TYoloRGB;
  end;
  TYoloViewLegend = record
    ClassID: Integer;
    Text: string;
    Pixels: Int64;
    Color: TYoloRGB;
  end;
  TYoloViewStyle = record
    MaskOpacity: Single;
    KeypointConfidence: Single;
    class function Defaults: TYoloViewStyle; static;
    procedure Validate;
  end;
  TYoloViewFrame = record
    Image: IMat;
    Labels: TArray<TYoloViewLabel>;
    Legend: TArray<TYoloViewLegend>;
    HasDepthScale: Boolean;
    DepthMinimum: Single;
    DepthMaximum: Single;
  end;

{ Draws on a clone at original image resolution. The GUI paints the returned
  Unicode labels using its native text renderer; masks and geometry need no
  widget handles. Source pixels and lossless result maps remain unchanged. }
function RenderYoloFrame(const Source: IMat; const Value: TYoloExampleResult;
  const Style: TYoloViewStyle; const ShouldStop: TCpuGraphStop = nil): TYoloViewFrame;
function YoloClassColor(const ClassID: Integer): TYoloRGB;

implementation

uses
  {$IFDEF FPC}SysUtils, Math{$ELSE}System.SysUtils, System.Math{$ENDIF},
  OpenCVTypes, OpenCVConsts, CrossVision.ML.Depth, CrossVision.Geometry.Types,
  CrossPascal.Json, TVM.Yolo.Profile, TVM.Yolo.Identity, TVM.Yolo.RunOptions;

type
  TYoloPixelSurface = record
    DataPtr: Pointer;
    Step: NativeUInt;
    Width: Integer;
    Height: Integer;
  end;

const
  { Human COCO-17 joint topology, using zero-based keypoint indices. }
  HumanPoseLinks: array[0..18, 0..1] of Byte = (
    (15, 13), (13, 11), (16, 14), (14, 12), (11, 12),
    (5, 11), (6, 12), (5, 6), (5, 7), (6, 8), (7, 9), (8, 10),
    (1, 2), (0, 1), (0, 2), (1, 3), (2, 4), (3, 5), (4, 6));

class function TYoloViewStyle.Defaults: TYoloViewStyle;
begin
  Result.MaskOpacity := 0.45;
  Result.KeypointConfidence := 0.5;
end;

procedure TYoloViewStyle.Validate;
begin
  RequireCpu(not IsNan(MaskOpacity) and not IsInfinite(MaskOpacity) and
    (MaskOpacity >= 0) and (MaskOpacity <= 1) and
    not IsNan(KeypointConfidence) and not IsInfinite(KeypointConfidence) and
    (KeypointConfidence >= 0) and (KeypointConfidence <= 1), 'Invalid YOLO display settings.');
end;

function HueColor(const Hue: Double): TYoloRGB;
var
  Position, Fraction, P, Q, T: Double;
  Sector: Integer;
  R, G, B: Double;
begin
  Position := (Hue - Floor(Hue)) * 6;
  Sector := Floor(Position);
  Fraction := Position - Sector;
  P := 0.95 * 0.25;
  Q := 0.95 * (1 - Fraction * 0.75);
  T := 0.95 * (1 - (1 - Fraction) * 0.75);
  case Sector of
    0:
      begin
        R := 0.95;
        G := T;
        B := P;
      end;
    1:
      begin
        R := Q;
        G := 0.95;
        B := P;
      end;
    2:
      begin
        R := P;
        G := 0.95;
        B := T;
      end;
    3:
      begin
        R := P;
        G := Q;
        B := 0.95;
      end;
    4:
      begin
        R := T;
        G := P;
        B := 0.95;
      end;
  else begin
      R := 0.95;
      G := P;
      B := Q;
    end;
  end;
  Result.Red := Round(R * 255);
  Result.Green := Round(G * 255);
  Result.Blue := Round(B * 255);
end;

function YoloClassColor(const ClassID: Integer): TYoloRGB;
begin
  RequireCpu(ClassID >= 0, 'Invalid display class ID.');
  Result := HueColor((ClassID + 1.0) * 0.6180339887498949);
end;

function Pixel(const Image: TYoloPixelSurface; const X, Y: Integer): PByte;
begin
  Result := PByte(NativeUInt(Image.DataPtr) + NativeUInt(Y) * NativeUInt(Image.Step) +
    NativeUInt(X) * 3);
end;

procedure SetPixel(const Image: TYoloPixelSurface; const X, Y: Integer; const Color: TYoloRGB);
var
  Target: PByte;
begin
  if (X < 0) or (X >= Image.Width) or (Y < 0) or (Y >= Image.Height) then Exit;
  Target := Pixel(Image, X, Y);
  Target^ := Color.Blue;
  PByte(NativeUInt(Target) + 1)^ := Color.Green;
  PByte(NativeUInt(Target) + 2)^ := Color.Red;
end;

procedure BlendPixel(const Image: TYoloPixelSurface; const X, Y, Alpha: Integer; const Color: TYoloRGB);
var
  Target: PByte;
begin
  Target := Pixel(Image, X, Y);
  Target^ := (Target^ * (255 - Alpha) + Color.Blue * Alpha + 127) div 255;
  Inc(Target);
  Target^ := (Target^ * (255 - Alpha) + Color.Green * Alpha + 127) div 255;
  Inc(Target);
  Target^ := (Target^ * (255 - Alpha) + Color.Red * Alpha + 127) div 255;
end;

function OutsideCode(const X, Y: Double; const Width, Height: Integer): Integer;
begin
  Result := 0;
  if X < 0 then Result := Result or 1;
  if X > Width - 1 then Result := Result or 2;
  if Y < 0 then Result := Result or 4;
  if Y > Height - 1 then Result := Result or 8;
end;

procedure DrawLine(const Image: TYoloPixelSurface; X1, Y1, X2, Y2: Double; const Width: Integer;
  const Color: TYoloRGB);
var
  First, Second, Code, X, Y, LastX, LastY, DX, DY, SX, SY, Error, Twice, I, J: Integer;
  IntersectionX, IntersectionY: Double;
begin
  RequireCpu(not IsNan(X1) and not IsInfinite(X1) and not IsNan(Y1) and not IsInfinite(Y1) and
    not IsNan(X2) and not IsInfinite(X2) and not IsNan(Y2) and not IsInfinite(Y2),
    'Nonfinite YOLO display geometry.');
  while True do
  begin
    First := OutsideCode(X1, Y1, Image.Width, Image.Height);
    Second := OutsideCode(X2, Y2, Image.Width, Image.Height);
    if (First or Second) = 0 then Break;
    if (First and Second) <> 0 then Exit;
    Code := First;
    if Code = 0 then Code := Second;
    if (Code and 4) <> 0 then
    begin
      IntersectionY := 0;
      IntersectionX := X1 + (X2 - X1) * (IntersectionY - Y1) / (Y2 - Y1);
    end
    else if (Code and 8) <> 0 then
    begin
      IntersectionY := Image.Height - 1;
      IntersectionX := X1 + (X2 - X1) * (IntersectionY - Y1) / (Y2 - Y1);
    end
    else begin
      IntersectionX := 0;
      if (Code and 2) <> 0 then IntersectionX := Image.Width - 1;
      IntersectionY := Y1 + (Y2 - Y1) * (IntersectionX - X1) / (X2 - X1);
    end;
    if Code = First then
    begin
      X1 := IntersectionX;
      Y1 := IntersectionY;
    end
    else begin
      X2 := IntersectionX;
      Y2 := IntersectionY;
    end;
  end;
  X := Round(X1);
  Y := Round(Y1);
  LastX := Round(X2);
  LastY := Round(Y2);
  DX := Abs(LastX - X);
  DY := -Abs(LastY - Y);
  SX := 1;
  if X > LastX then SX := -1;
  SY := 1;
  if Y > LastY then SY := -1;
  Error := DX + DY;
  while True do
  begin
    for I := -(Width div 2) to Width div 2 do
      for J := -(Width div 2) to Width div 2 do SetPixel(Image, X + I, Y + J, Color);
    if (X = LastX) and (Y = LastY) then Break;
    Twice := Error * 2;
    if Twice >= DY then
    begin
      Error := Error + DY;
      X := X + SX;
    end;
    if Twice <= DX then
    begin
      Error := Error + DX;
      Y := Y + SY;
    end;
  end;
end;

procedure DrawBox(const Image: TYoloPixelSurface; const Box: TRectI; const Width: Integer;
  const Color: TYoloRGB);
begin
  DrawLine(Image, Box.Left, Box.Top, Box.Right, Box.Top, Width, Color);
  DrawLine(Image, Box.Right, Box.Top, Box.Right, Box.Bottom, Width, Color);
  DrawLine(Image, Box.Right, Box.Bottom, Box.Left, Box.Bottom, Width, Color);
  DrawLine(Image, Box.Left, Box.Bottom, Box.Left, Box.Top, Width, Color);
end;

procedure AddLabel(var Frame: TYoloViewFrame; const X, Y: Integer; const Text: string;
  const Color: TYoloRGB);
var
  I: Integer;
begin
  I := Length(Frame.Labels);
  SetLength(Frame.Labels, I + 1);
  Frame.Labels[I].X := Max(0, Min(Frame.Image.Width - 1, X));
  Frame.Labels[I].Y := Max(0, Min(Frame.Image.Height - 1, Y));
  Frame.Labels[I].Text := Text;
  Frame.Labels[I].Color := Color;
end;

function Caption(const Name: string; const Score: Double): string;
begin
  Result := Name + ' ' + Format('%.1f%%', [Score * 100], JSONInvariantFormat);
end;

procedure RequireMap(const Image: IMat; const Width, Height, MatType: Integer);
begin
  RequireCpu((Image <> nil) and not Image.IsEmpty and (Image.Width = Width) and
    (Image.Height = Height) and (Image.MatType = MatType) and (Image.DataPtr <> nil) and
    (Image.Step >= Int64(Width) * Image.ElemSize), 'Invalid YOLO display map.');
end;

function RenderYoloFrame(const Source: IMat; const Value: TYoloExampleResult;
  const Style: TYoloViewStyle; const ShouldStop: TCpuGraphStop): TYoloViewFrame;
var
  Surface: TYoloPixelSurface;
  Color, LimbColor, JointColor, OutlineColor: TYoloRGB;
  I, J, K, X, Y, Scale, Alpha, Count, BarX, BarY, BarHeight, FirstJoint, LastJoint: Integer;
  Row: PByte;
  DepthRow: Pointer;
  Seen: TBytes;
  Pixels: Int64;
  Angle, AxisX, AxisY, CrossX, CrossY, TX, TY, MinimumX, MinimumY, Fraction: Double;
  CornersX, CornersY: array[0..3] of Double;
  Depth: Single;

  function VisibleJoint(const Index: Integer): Boolean;
  begin
    Result := not IsNan(Value.Poses[I].Keypoints[Index].X) and
      not IsInfinite(Value.Poses[I].Keypoints[Index].X) and
      not IsNan(Value.Poses[I].Keypoints[Index].Y) and
      not IsInfinite(Value.Poses[I].Keypoints[Index].Y) and
      not IsNan(Value.Poses[I].Keypoints[Index].Visibility) and
      not IsInfinite(Value.Poses[I].Keypoints[Index].Visibility) and
      (Value.Poses[I].Keypoints[Index].X >= 0) and
      (Value.Poses[I].Keypoints[Index].X < Value.Width) and
      (Value.Poses[I].Keypoints[Index].Y >= 0) and
      (Value.Poses[I].Keypoints[Index].Y < Value.Height) and
      (Value.Poses[I].Keypoints[Index].Visibility >= Style.KeypointConfidence);
  end;

begin
  Result := Default(TYoloViewFrame);
  Style.Validate;
  Value.Profile.Validate;
  RequireCpu(Value.ProfileIdentity = YoloProfileIdentity(Value.Profile), 'The display profile changed.');
  RequireCpu((Value.Width > 0) and (Value.Height > 0) and
    (Int64(Value.Width) * Value.Height <= 64 * 1024 * 1024), 'The display image is too large.');
  RequireMap(Source, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 3));
  CheckYoloRunStop(ShouldStop);
  try
    Result.Image := Source.Clone;
    RequireMap(Result.Image, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 3));
    Surface.DataPtr := Result.Image.DataPtr;
    Surface.Step := Result.Image.Step;
    Surface.Width := Value.Width;
    Surface.Height := Value.Height;
    Scale := Max(1, Max(Value.Width, Value.Height) div 640);
    Alpha := Round(Style.MaskOpacity * 255);
    case Value.Profile.Task of
      ytClassification:
        for I := 0 to High(Value.Classes) do
          AddLabel(Result, 12 * Scale, (12 + I * 22) * Scale,
            Caption(Value.Classes[I].ClassName, Value.Classes[I].Score),
            YoloClassColor(Value.Classes[I].ClassId));
      ytDetection:
        for I := 0 to High(Value.Detections) do
        begin
          CheckYoloRunStop(ShouldStop);
          Color := YoloClassColor(Value.Detections[I].ClassId);
          DrawBox(Surface, Value.Detections[I].Box, 2 * Scale, Color);
          AddLabel(Result, Value.Detections[I].Box.Left, Value.Detections[I].Box.Top,
            Caption(Value.Detections[I].ClassName, Value.Detections[I].Score), Color);
        end;
      ytInstances, ytSemantic:
        begin
          Count := Length(Value.Instances);
          if Value.Profile.Task = ytSemantic then
          begin
            Count := Length(Value.Semantic);
            SetLength(Seen, Value.Width * Value.Height);
          end;
          for I := 0 to Count - 1 do
          begin
            if Value.Profile.Task = ytSemantic then
            begin
              RequireMap(Value.Semantic[I].Mask, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 1));
              Color := YoloClassColor(Value.Semantic[I].ClassId);
            end
            else begin
              RequireMap(Value.Instances[I].Mask, Value.Width, Value.Height, CV_MAKETYPE(CV_8U, 1));
              Color := YoloClassColor(Value.Instances[I].ClassId);
            end;
            Pixels := 0;
            for Y := 0 to Value.Height - 1 do
            begin
              if (Y and 31) = 0 then CheckYoloRunStop(ShouldStop);
              if Value.Profile.Task = ytSemantic then
                Row := PByte(NativeUInt(Value.Semantic[I].Mask.DataPtr) + NativeUInt(Y) * NativeUInt(Value.Semantic[I].Mask.Step))
              else
                Row := PByte(NativeUInt(Value.Instances[I].Mask.DataPtr) + NativeUInt(Y) * NativeUInt(Value.Instances[I].Mask.Step));
              for X := 0 to Value.Width - 1 do
              begin
                if Row^ <> 0 then
                begin
                  RequireCpu(Row^ = 255, 'Invalid binary display mask value.');
                  if Value.Profile.Task = ytSemantic then
                  begin
                    RequireCpu(Seen[Y * Value.Width + X] = 0, 'Overlapping semantic class planes.');
                    Seen[Y * Value.Width + X] := 1;
                  end;
                  Inc(Pixels);
                  BlendPixel(Surface, X, Y, Alpha, Color);
                end;
                Inc(Row);
              end;
            end;
            if Value.Profile.Task = ytSemantic then
            begin
              if Pixels > 0 then
              begin
                J := Length(Result.Legend);
                SetLength(Result.Legend, J + 1);
                Result.Legend[J].ClassID := Value.Semantic[I].ClassId;
                Result.Legend[J].Text := Value.Semantic[I].ClassName;
                Result.Legend[J].Color := Color;
                Result.Legend[J].Pixels := Pixels;
              end;
            end
            else begin
              DrawBox(Surface, Value.Instances[I].Box, 2 * Scale, Color);
              AddLabel(Result, Value.Instances[I].Box.Left, Value.Instances[I].Box.Top,
                Caption(Value.Instances[I].ClassName, Value.Instances[I].Score), Color);
            end;
          end;
          if Value.Profile.Task = ytSemantic then
            for I := 0 to High(Seen) do
              RequireCpu(Seen[I] = 1, 'Unassigned semantic display pixel.');
        end;
      ytPose:
        for I := 0 to High(Value.Poses) do
        begin
          CheckYoloRunStop(ShouldStop);
          Color := YoloClassColor(Value.Poses[I].ClassId);
          DrawBox(Surface, Value.Poses[I].Box, 2 * Scale, Color);
          AddLabel(Result, Value.Poses[I].Box.Left, Value.Poses[I].Box.Top,
            Caption(Value.Poses[I].ClassName, Value.Poses[I].Score), Color);
          OutlineColor.Red := 0;
          OutlineColor.Green := 0;
          OutlineColor.Blue := 0;
          LimbColor.Red := 80;
          LimbColor.Green := 255;
          LimbColor.Blue := 80;
          JointColor.Red := 255;
          JointColor.Green := 220;
          JointColor.Blue := 40;
          if Length(Value.Poses[I].Keypoints) = 17 then
            for K := Low(HumanPoseLinks) to High(HumanPoseLinks) do
            begin
              FirstJoint := HumanPoseLinks[K, 0];
              LastJoint := HumanPoseLinks[K, 1];
              if VisibleJoint(FirstJoint) and VisibleJoint(LastJoint) then
              begin
                DrawLine(Surface, Value.Poses[I].Keypoints[FirstJoint].X,
                  Value.Poses[I].Keypoints[FirstJoint].Y, Value.Poses[I].Keypoints[LastJoint].X,
                  Value.Poses[I].Keypoints[LastJoint].Y, 5 * Scale, OutlineColor);
                DrawLine(Surface, Value.Poses[I].Keypoints[FirstJoint].X,
                  Value.Poses[I].Keypoints[FirstJoint].Y, Value.Poses[I].Keypoints[LastJoint].X,
                  Value.Poses[I].Keypoints[LastJoint].Y, 3 * Scale, LimbColor);
              end;
            end;
          for K := 0 to High(Value.Poses[I].Keypoints) do
            if VisibleJoint(K) then
            begin
              TX := Value.Poses[I].Keypoints[K].X;
              TY := Value.Poses[I].Keypoints[K].Y;
              if (TX < 0) or (TX >= Value.Width) or (TY < 0) or (TY >= Value.Height) then Continue;
              X := Round(TX);
              Y := Round(TY);
              for J := -6 * Scale to 6 * Scale do
                for Count := -6 * Scale to 6 * Scale do
                  if J * J + Count * Count <= 36 * Scale * Scale then
                  begin
                    Color := OutlineColor;
                    if J * J + Count * Count <= 16 * Scale * Scale then Color := JointColor;
                    SetPixel(Surface, X + J, Y + Count, Color);
                  end;
              AddLabel(Result, X + 7 * Scale, Y, IntToStr(K), JointColor);
            end;
        end;
      ytOriented:
        for I := 0 to High(Value.Oriented) do
        begin
          CheckYoloRunStop(ShouldStop);
          Color := YoloClassColor(Value.Oriented[I].ClassId);
          Angle := Value.Oriented[I].Box.Angle;
          AxisX := Cos(Angle) * Value.Oriented[I].Box.Width / 2;
          AxisY := Sin(Angle) * Value.Oriented[I].Box.Width / 2;
          CrossX := -Sin(Angle) * Value.Oriented[I].Box.Height / 2;
          CrossY := Cos(Angle) * Value.Oriented[I].Box.Height / 2;
          for K := 0 to 3 do
          begin
            TX := -1;
            if K in [1, 2] then TX := 1;
            TY := -1;
            if K in [2, 3] then TY := 1;
            CornersX[K] := Value.Oriented[I].Box.CenterX + TX * AxisX + TY * CrossX;
            CornersY[K] := Value.Oriented[I].Box.CenterY + TX * AxisY + TY * CrossY;
          end;
          MinimumX := CornersX[0];
          MinimumY := CornersY[0];
          for K := 0 to 3 do
          begin
            J := (K + 1) mod 4;
            DrawLine(Surface, CornersX[K], CornersY[K], CornersX[J], CornersY[J], 2 * Scale, Color);
            MinimumX := Min(MinimumX, CornersX[K]);
            MinimumY := Min(MinimumY, CornersY[K]);
          end;
          AddLabel(Result, Round(MinimumX), Round(MinimumY),
            Caption(Value.Oriented[I].ClassName, Value.Oriented[I].Score), Color);
        end;
      ytDepth:
        begin
          RequireCpu(Value.Depth.Units = duMeters, 'Unexpected display depth units.');
          RequireMap(Value.Depth.Values, Value.Width, Value.Height, CV_MAKETYPE(CV_32F, 1));
          Result.HasDepthScale := True;
          Result.DepthMinimum := MaxSingle;
          Result.DepthMaximum := 0;
          for Y := 0 to Value.Height - 1 do
          begin
            if (Y and 31) = 0 then CheckYoloRunStop(ShouldStop);
            DepthRow := Pointer(NativeUInt(Value.Depth.Values.DataPtr) + NativeUInt(Y) * NativeUInt(Value.Depth.Values.Step));
            for X := 0 to Value.Width - 1 do
            begin
              Depth := PSingle(NativeUInt(DepthRow) + NativeUInt(X) * SizeOf(Single))^;
              RequireCpu(not IsNan(Depth) and not IsInfinite(Depth) and (Depth > 0),
                'Invalid display depth value.');
              Result.DepthMinimum := Min(Result.DepthMinimum, Depth);
              Result.DepthMaximum := Max(Result.DepthMaximum, Depth);
            end;
          end;
          for Y := 0 to Value.Height - 1 do
          begin
            if (Y and 31) = 0 then CheckYoloRunStop(ShouldStop);
            DepthRow := Pointer(NativeUInt(Value.Depth.Values.DataPtr) + NativeUInt(Y) * NativeUInt(Value.Depth.Values.Step));
            for X := 0 to Value.Width - 1 do
            begin
              Depth := PSingle(NativeUInt(DepthRow) + NativeUInt(X) * SizeOf(Single))^;
              Fraction := 0.5;
              if Result.DepthMaximum > Result.DepthMinimum then
                Fraction := (Depth - Result.DepthMinimum) / (Result.DepthMaximum - Result.DepthMinimum);
              SetPixel(Surface, X, Y, HueColor(Fraction * 2 / 3));
            end;
          end;
          BarX := Max(0, Value.Width - 22 * Scale);
          BarY := Min(Value.Height - 1, 36 * Scale);
          BarHeight := Max(1, Min(Value.Height - BarY, Value.Height div 3));
          for Y := 0 to BarHeight - 1 do
          begin
            Fraction := 0.5;
            if (BarHeight > 1) and (Result.DepthMaximum > Result.DepthMinimum) then
              Fraction := Y / (BarHeight - 1);
            Color := HueColor(Fraction * 2 / 3);
            for X := BarX to Min(Value.Width - 1, BarX + 12 * Scale) do
              SetPixel(Surface, X, BarY + Y, Color);
          end;
          Color.Red := 255;
          Color.Green := 255;
          Color.Blue := 255;
          AddLabel(Result, 12 * Scale, 12 * Scale, 'Estimated depth, m', Color);
          AddLabel(Result, Max(0, BarX - 130 * Scale), BarY,
            Format('%.2f m', [Result.DepthMinimum], JSONInvariantFormat), Color);
          AddLabel(Result, Max(0, BarX - 130 * Scale), BarY + BarHeight - 1,
            Format('%.2f m', [Result.DepthMaximum], JSONInvariantFormat), Color);
        end;
    end;
    CheckYoloRunStop(ShouldStop);
  except
    Result := Default(TYoloViewFrame);
    raise;
  end;
end;

end.
