{ ************************************************************************** }
{                                                                            }
{ YoloModels.WindowsText                                                      }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                       }
{                                                                            }
{ ************************************************************************** }

unit YoloModels.WindowsText;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  TVM.CpuGraph, YoloModels.Render;

type
  TYoloTextMode = YoloModels.Render.TYoloTextMode;

{ Memory DC only: no window or desktop control. Pixels are top-down BGR8.
  The caller passes its preview, never an original image or a result map. }
procedure PaintYoloWindowsText(const Pixels: Pointer; const Bytes, Step: NativeInt;
  const Width, Height: Integer; const Labels: TArray<TYoloViewLabel>;
  const Legend: TArray<TYoloViewLegend>; const Mode: TYoloTextMode;
  const ShouldStop: TCpuGraphStop = nil);

implementation

uses
  {$IFDEF FPC}Windows, SysUtils, Math{$ELSE}Winapi.Windows, System.SysUtils, System.Math{$ENDIF},
  CrossPascal.Json, TVM.Yolo.RunOptions;

function MakeRect(const Left, Top, Right, Bottom: Integer): TRect;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Right := Right;
  Result.Bottom := Bottom;
end;

function IsPointIndex(const Text: string): Boolean;
var
  Value: Integer;
begin
  Result := TryStrToInt(Text, Value) and (Value >= 0);
end;

procedure PaintYoloWindowsText(const Pixels: Pointer; const Bytes, Step: NativeInt;
  const Width, Height: Integer; const Labels: TArray<TYoloViewLabel>;
  const Legend: TArray<TYoloViewLegend>; const Mode: TYoloTextMode;
  const ShouldStop: TCpuGraphStop);
var
  DC: HDC;
  Bitmap: HBITMAP;
  Font: HFONT;
  OldBitmap, OldFont: HGDIOBJ;
  WhiteBrush, ColorBrush: HBRUSH;
  Info: TBitmapInfo;
  Bits: Pointer;
  Source, Target: PByte;
  I, J, X, Y, Scale, LineHeight, LabelWidth, LabelHeight, CaptionCount, Attempts: Integer;
  LegendWidth, LegendHeight, LegendRows: Integer;
  Text: UnicodeString;
  Box, Measure, Stripe: TRect;
  Placed: TArray<TRect>;
  Overlap, ShowCaption: Boolean;
begin
  RequireCpu((Pixels <> nil) and (Width > 0) and (Height > 0) and
    (Int64(Width) * Height <= 64 * 1024 * 1024) and (Step >= Int64(Width) * 3) and
    (Int64(Height - 1) * Step + Int64(Width) * 3 <= Bytes), 'Invalid BGR preview storage.');
  if (Mode = ytNone) or ((Length(Labels) = 0) and (Length(Legend) = 0)) then Exit;
  CheckYoloRunStop(ShouldStop);
  DC := 0;
  Bitmap := 0;
  Font := 0;
  WhiteBrush := 0;
  OldBitmap := 0;
  OldFont := 0;
  try
    DC := CreateCompatibleDC(0);
    RequireCpu(DC <> 0, 'Cannot create the preview text drawing context.');
    FillChar(Info, SizeOf(Info), 0);
    Info.bmiHeader.biSize := SizeOf(Info.bmiHeader);
    Info.bmiHeader.biWidth := Width;
    Info.bmiHeader.biHeight := -Height;
    Info.bmiHeader.biPlanes := 1;
    Info.bmiHeader.biBitCount := 32;
    Info.bmiHeader.biCompression := BI_RGB;
    Bits := nil;
    Bitmap := CreateDIBSection(DC, Info, DIB_RGB_COLORS, Bits, 0, 0);
    RequireCpu((Bitmap <> 0) and (Bits <> nil), 'Cannot allocate the preview text bitmap.');
    OldBitmap := SelectObject(DC, Bitmap);
    RequireCpu(OldBitmap <> 0, 'Cannot select the preview text bitmap.');
    for Y := 0 to Height - 1 do
    begin
      if (Y and 31) = 0 then CheckYoloRunStop(ShouldStop);
      Source := PByte(NativeUInt(Pixels) + NativeUInt(Y) * NativeUInt(Step));
      Target := PByte(NativeUInt(Bits) + NativeUInt(Y) * NativeUInt(Width) * 4);
      for X := 0 to Width - 1 do
      begin
        Target^ := Source^;
        PByte(NativeUInt(Target) + 1)^ := PByte(NativeUInt(Source) + 1)^;
        PByte(NativeUInt(Target) + 2)^ := PByte(NativeUInt(Source) + 2)^;
        PByte(NativeUInt(Target) + 3)^ := 0;
        Inc(Source, 3);
        Inc(Target, 4);
      end;
    end;
    Scale := Max(1, Min(3, Min(Width, Height) div 800));
    Font := CreateFontW(-16 * Scale, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
      DEFAULT_PITCH or FF_DONTCARE, 'Segoe UI');
    RequireCpu(Font <> 0, 'Cannot create the preview text font.');
    OldFont := SelectObject(DC, Font);
    RequireCpu(OldFont <> 0, 'Cannot select the preview text font.');
    SetBkMode(DC, TRANSPARENT);
    SetTextColor(DC, RGB(16, 20, 24));
    WhiteBrush := CreateSolidBrush(RGB(255, 255, 255));
    RequireCpu(WhiteBrush <> 0, 'Cannot allocate the preview label background.');
    LineHeight := 22 * Scale;
    CaptionCount := 0;
    for I := 0 to High(Labels) do
      if not IsPointIndex(Labels[I].Text) then Inc(CaptionCount);
    for I := 0 to High(Labels) do
    begin
      CheckYoloRunStop(ShouldStop);
      ShowCaption := (Mode = ytAll) or
        ((not IsPointIndex(Labels[I].Text)) and (CaptionCount <= 40));
      if not ShowCaption or (Labels[I].Text = '') then Continue;
      Text := Labels[I].Text;
      Measure := MakeRect(0, 0, Width, Height);
      RequireCpu(DrawTextW(DC, PWideChar(Text), Length(Text), Measure,
        DT_CALCRECT or DT_NOPREFIX or DT_SINGLELINE) <> 0, 'Cannot measure a preview label.');
      LabelWidth := Min(Width, Measure.Right - Measure.Left + 12 * Scale);
      LabelHeight := Min(Height, Measure.Bottom - Measure.Top + 4 * Scale);
      X := Max(0, Min(Labels[I].X, Width - LabelWidth));
      Y := Max(0, Min(Labels[I].Y - LabelHeight, Height - LabelHeight));
      for Attempts := 0 to Min(Length(Placed), Height div Max(1, LabelHeight) + 1) do
      begin
        Box := MakeRect(X, Y, X + LabelWidth, Y + LabelHeight);
        Overlap := False;
        for J := 0 to High(Placed) do
          if (Box.Left < Placed[J].Right) and (Box.Right > Placed[J].Left) and
            (Box.Top < Placed[J].Bottom) and (Box.Bottom > Placed[J].Top) then
            begin
              Overlap := True;
              Break;
            end;
        if not Overlap then Break;
        Inc(Y, LabelHeight + 2 * Scale);
        if Y + LabelHeight > Height then Y := 0;
      end;
      J := Length(Placed);
      SetLength(Placed, J + 1);
      Placed[J] := Box;
      FillRect(DC, Box, WhiteBrush);
      ColorBrush := CreateSolidBrush(RGB(Labels[I].Color.Red, Labels[I].Color.Green, Labels[I].Color.Blue));
      RequireCpu(ColorBrush <> 0, 'Cannot allocate a preview label color.');
      try
        Stripe := MakeRect(Box.Left, Box.Top, Min(Box.Right, Box.Left + 4 * Scale), Box.Bottom);
        FillRect(DC, Stripe, ColorBrush);
      finally
        DeleteObject(ColorBrush);
      end;
      Inc(Box.Left, 8 * Scale);
      RequireCpu(DrawTextW(DC, PWideChar(Text), Length(Text), Box,
        DT_NOPREFIX or DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS) <> 0,
        'Cannot draw a preview label.');
    end;
    LegendRows := Min(Length(Legend), Max(0, (Height - 16 * Scale) div LineHeight));
    if LegendRows > 0 then
    begin
      LegendWidth := 0;
      for I := 0 to LegendRows - 1 do
      begin
        Text := Legend[I].Text;
        Measure := MakeRect(0, 0, Width, Height);
        RequireCpu(DrawTextW(DC, PWideChar(Text), Length(Text), Measure,
          DT_CALCRECT or DT_NOPREFIX or DT_SINGLELINE) <> 0, 'Cannot measure the class legend.');
        LegendWidth := Max(LegendWidth, Measure.Right - Measure.Left + 40 * Scale);
      end;
      LegendWidth := Min(Width, LegendWidth);
      LegendHeight := Min(Height, LegendRows * LineHeight + 12 * Scale);
      Box := MakeRect(0, 0, LegendWidth, LegendHeight);
      FillRect(DC, Box, WhiteBrush);
      for I := 0 to LegendRows - 1 do
      begin
        CheckYoloRunStop(ShouldStop);
        ColorBrush := CreateSolidBrush(RGB(Legend[I].Color.Red, Legend[I].Color.Green, Legend[I].Color.Blue));
        RequireCpu(ColorBrush <> 0, 'Cannot allocate a class legend color.');
        try
          Stripe := MakeRect(6 * Scale, (6 + I * 22) * Scale, 22 * Scale, (22 + I * 22) * Scale);
          FillRect(DC, Stripe, ColorBrush);
        finally
          DeleteObject(ColorBrush);
        end;
        Text := Legend[I].Text;
        Box := MakeRect(28 * Scale, (4 + I * 22) * Scale, LegendWidth - 4 * Scale,
          (26 + I * 22) * Scale);
        RequireCpu(DrawTextW(DC, PWideChar(Text), Length(Text), Box,
          DT_NOPREFIX or DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS) <> 0,
          'Cannot draw a class legend label.');
      end;
    end;
    RequireCpu(GdiFlush, 'Cannot finish preview text drawing.');
    CheckYoloRunStop(ShouldStop);
    for Y := 0 to Height - 1 do
    begin
      Source := PByte(NativeUInt(Bits) + NativeUInt(Y) * NativeUInt(Width) * 4);
      Target := PByte(NativeUInt(Pixels) + NativeUInt(Y) * NativeUInt(Step));
      for X := 0 to Width - 1 do
      begin
        Target^ := Source^;
        PByte(NativeUInt(Target) + 1)^ := PByte(NativeUInt(Source) + 1)^;
        PByte(NativeUInt(Target) + 2)^ := PByte(NativeUInt(Source) + 2)^;
        Inc(Source, 4);
        Inc(Target, 3);
      end;
    end;
  finally
    if OldFont <> 0 then SelectObject(DC, OldFont);
    if OldBitmap <> 0 then SelectObject(DC, OldBitmap);
    if Font <> 0 then DeleteObject(Font);
    if Bitmap <> 0 then DeleteObject(Bitmap);
    if WhiteBrush <> 0 then DeleteObject(WhiteBrush);
    if DC <> 0 then DeleteDC(DC);
  end;
end;

end.
