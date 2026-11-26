{ ************************************************************************** }
{                                                                            }
{ YoloModels.Run                                                             }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                       }
{                                                                            }
{ ************************************************************************** }

unit YoloModels.Run;

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}
{$B-}

interface

uses
  CrossVision.Mat, CrossVision.ML, CrossVision.ML.Depth, CrossVision.ML.YoloBundle,
  TVM.Yolo.Profile, TVM.Yolo.RunOptions, CrossPascal.Json;

type
  TYoloExampleResult = record
    Profile: TYoloProfile;
    ProfileIdentity: string;
    ManifestSHA256: string;
    Device: string;
    CUDAArchitecture: string;
    ImageSHA256: string;
    Width: Integer;
    Height: Integer;
    Milliseconds: UInt64;
    Confidence: Single;
    NmsIoU: Single;
    Classes: TClassificationArray;
    Detections: TDetectionArray;
    Instances: TInstanceArray;
    Poses: TPoseArray;
    Oriented: TOrientedDetectionArray;
    Semantic: TSemanticMaskArray;
    Depth: TDepthMap;
  end;

  { Construct, use and release a session on its owning inference worker.
    The worker joins and calls FinishTVMThread before the application exits.
    A Stop callback owner must outlive the session. Results own their maps. }
  TYoloExampleSession = class
  private
    FBundle: IYoloBundle;
    FActive: IInterface;
    FProfile: TYoloProfile;
    FOptions: TYoloRunOptions;
    FManifestSHA256: string;
    FDevice: string;
    FCUDAArchitecture: string;
  public
    constructor Create(const BundleDirectory, ManifestSHA256: string; const ManifestBytes: Int64;
      const RuntimeDirectory: string; const ExpectedProfile: TYoloProfile;
      const Options: TYoloRunOptions);
    destructor Destroy; override;
    function Run(const Image: IMat; const ImageSHA256: string): TYoloExampleResult;
    function Profile: TYoloProfile;
  end;

function YoloTaskName(const Task: TYoloTask): string;
function YoloExampleResultObject(const Value: TYoloExampleResult): TJSONObject;
function YoloExampleResultJSON(const Value: TYoloExampleResult): string;

implementation

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils, Winapi.Windows{$ENDIF}, CrossVision.Geometry.Types,
  TVM.Yolo.Native, TVM.Yolo.Identity, TVM.NativeFiles, TVM.CpuGraph;

constructor TYoloExampleSession.Create(const BundleDirectory, ManifestSHA256: string;
  const ManifestBytes: Int64; const RuntimeDirectory: string; const ExpectedProfile: TYoloProfile;
  const Options: TYoloRunOptions);
var
  Lease: INativeFileLease;
  Root, Artifact: TJSONObject;
begin
  inherited Create;
  FProfile := CopyYoloProfile(ExpectedProfile);
  FOptions := Options;
  FManifestSHA256 := ManifestSHA256;
  FBundle := LoadYoloBundleForRun(BundleDirectory, ManifestSHA256, ManifestBytes,
    RuntimeDirectory, FProfile, FOptions);
  Lease := HoldNativeFile(BundleDirectory, 'manifest.json', ManifestSHA256, ManifestBytes);
  Root := ReadNativeObject(Lease);
  try
    Artifact := NativeObject(NativeField(Root, 'artifact'));
    FDevice := NativeText(Artifact, 'device');
    if FDevice = 'cuda' then FCUDAArchitecture := NativeText(Artifact, 'cuda_arch');
  finally
    Root.Free;
  end;
  case FProfile.Task of
    ytClassification: FActive := FBundle.OpenClassifier;
    ytDetection: FActive := FBundle.OpenDetector;
    ytInstances: FActive := FBundle.OpenInstanceSegmenter;
    ytPose: FActive := FBundle.OpenPoseEstimator;
    ytOriented: FActive := FBundle.OpenOrientedDetector;
    ytSemantic: FActive := FBundle.OpenSemanticSegmenter;
    ytDepth: FActive := FBundle.OpenDepthEstimator;
  end;
end;

destructor TYoloExampleSession.Destroy;
begin
  FActive := nil;
  FBundle := nil;
  inherited;
end;

function TYoloExampleSession.Profile: TYoloProfile;
begin
  Result := CopyYoloProfile(FProfile);
end;

function TYoloExampleSession.Run(const Image: IMat; const ImageSHA256: string): TYoloExampleResult;
var
  Started: UInt64;
begin
  RequireCpu((Image <> nil) and not Image.IsEmpty, 'Open an image before running YOLO.');
  NativeRequireSHA256(ImageSHA256);
  CheckYoloRunStop(FOptions.ShouldStop);
  Result := Default(TYoloExampleResult);
  Started := GetTickCount64;
  case FProfile.Task of
    ytClassification: Result.Classes := (FActive as IClassifier).Classify(Image);
    ytDetection: Result.Detections := (FActive as IDetector).Detect(Image);
    ytInstances: Result.Instances := (FActive as IInstanceSegmenter).SegmentInstances(Image);
    ytPose: Result.Poses := (FActive as IPoseEstimator).EstimatePoses(Image);
    ytOriented: Result.Oriented := (FActive as IOrientedDetector).DetectOriented(Image);
    ytSemantic: Result.Semantic := (FActive as ISemanticSegmenter).SegmentClasses(Image);
    ytDepth: Result.Depth := (FActive as IDepthEstimator).EstimateDepth(Image);
  end;
  CheckYoloRunStop(FOptions.ShouldStop);
  Result.Milliseconds := GetTickCount64 - Started;
  Result.Profile := CopyYoloProfile(FProfile);
  Result.ProfileIdentity := YoloProfileIdentity(FProfile);
  Result.ManifestSHA256 := FManifestSHA256;
  Result.Device := FDevice;
  Result.CUDAArchitecture := FCUDAArchitecture;
  Result.ImageSHA256 := ImageSHA256;
  Result.Width := Image.Width;
  Result.Height := Image.Height;
  Result.Confidence := FOptions.Confidence;
  Result.NmsIoU := FOptions.NmsIoU;
end;

function YoloTaskName(const Task: TYoloTask): string;
begin
  case Task of
    ytClassification: Result := 'classification';
    ytDetection: Result := 'object_detection';
    ytInstances: Result := 'instance_segmentation';
    ytPose: Result := 'pose';
    ytOriented: Result := 'oriented_detection';
    ytSemantic: Result := 'semantic_segmentation';
    ytDepth: Result := 'depth_estimation';
  else
    raise EArgumentException.Create('Unknown YOLO task.');
  end;
end;

function Numbers(const Values: array of Double): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  try
    for I := 0 to High(Values) do Result.AddElement(JSONFloat(Values[I]));
  except
    Result.Free;
    raise;
  end;
end;

function Prediction(const ClassID: Integer; const ClassName: string;
  const Score: Double): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('class_id', JSONInteger(ClassID));
    Result.AddPair('class_name', ClassName);
    Result.AddPair('score', JSONFloat(Score));
  except
    Result.Free;
    raise;
  end;
end;

procedure AddBox(const Item: TJSONObject; const Box: TRectI);
begin
  Item.AddPair('xyxy', Numbers([Box.Left, Box.Top, Box.Right, Box.Bottom]));
end;

function YoloExampleResultObject(const Value: TYoloExampleResult): TJSONObject;
var
  Rows, Points: TJSONArray;
  Item, Settings: TJSONObject;
  I, K: Integer;
begin
  Value.Profile.Validate;
  RequireCpu(Value.ProfileIdentity = YoloProfileIdentity(Value.Profile),
    'The result profile identity changed.');
  Result := TJSONObject.Create;
  try
    Result.AddPair('schema', 'crosspascal.yolo-example-result.v1');
    Result.AddPair('profile', Value.Profile.ID);
    Result.AddPair('task', YoloTaskName(Value.Profile.Task));
    Result.AddPair('profile_identity', Value.ProfileIdentity);
    Result.AddPair('source_sha256', Value.Profile.SourceSHA256);
    Result.AddPair('recipe_sha256', Value.Profile.RecipeSHA256);
    Result.AddPair('manifest_sha256', Value.ManifestSHA256);
    Result.AddPair('image_sha256', Value.ImageSHA256);
    Result.AddPair('image_width', JSONInteger(Value.Width));
    Result.AddPair('image_height', JSONInteger(Value.Height));
    Result.AddPair('device', Value.Device);
    if Value.CUDAArchitecture <> '' then Result.AddPair('cuda_arch', Value.CUDAArchitecture);
    Result.AddPair('inference_ms', JSONUnsigned(Value.Milliseconds));
    Result.AddPair('coordinate_space', 'original_image_pixels');
    Result.AddPair('integer_boxes', 'floor_left_top_ceil_right_bottom');
    Settings := TJSONObject.Create;
    Result.AddPair('run_settings', Settings);
    Settings.AddPair('confidence', JSONFloat(Value.Confidence));
    Settings.AddPair('nms_iou', JSONFloat(Value.NmsIoU));
    Settings.AddPair('nms_free', JSONBoolean(Value.Profile.NmsKind = ynSelectedInGraph));
    Rows := TJSONArray.Create;
    Result.AddPair('predictions', Rows);
    case Value.Profile.Task of
      ytClassification:
        for I := 0 to High(Value.Classes) do
          Rows.AddElement(Prediction(Value.Classes[I].ClassId, Value.Classes[I].ClassName,
            Value.Classes[I].Score));
      ytDetection:
        for I := 0 to High(Value.Detections) do
        begin
          Item := Prediction(Value.Detections[I].ClassId, Value.Detections[I].ClassName,
            Value.Detections[I].Score);
          Rows.AddElement(Item);
          AddBox(Item, Value.Detections[I].Box);
        end;
      ytInstances:
        begin
          Result.AddPair('mask_values', Numbers([0, 255]));
          for I := 0 to High(Value.Instances) do
          begin
            Item := Prediction(Value.Instances[I].ClassId, Value.Instances[I].ClassName,
              Value.Instances[I].Score);
            Rows.AddElement(Item);
            AddBox(Item, Value.Instances[I].Box);
            Item.AddPair('mask', 'instance-' + IntToStr(I) + '.u8');
          end;
        end;
      ytPose:
        begin
          Result.AddPair('keypoint_count', JSONInteger(Value.Profile.KeypointCount));
          Result.AddPair('keypoint_dimensions', JSONInteger(Value.Profile.KeypointDimensions));
          Result.AddPair('keypoint_fields', 'x,y,visibility');
          Result.AddPair('visibility_from_model', JSONBoolean(Value.Profile.KeypointDimensions = 3));
          for I := 0 to High(Value.Poses) do
          begin
            Item := Prediction(Value.Poses[I].ClassId, Value.Poses[I].ClassName,
              Value.Poses[I].Score);
            Rows.AddElement(Item);
            AddBox(Item, Value.Poses[I].Box);
            Points := TJSONArray.Create;
            Item.AddPair('keypoints', Points);
            for K := 0 to High(Value.Poses[I].Keypoints) do
              Points.AddElement(Numbers([Value.Poses[I].Keypoints[K].X,
                Value.Poses[I].Keypoints[K].Y, Value.Poses[I].Keypoints[K].Visibility]));
          end;
        end;
      ytOriented:
        begin
          Result.AddPair('angle_units', 'radians');
          Result.AddPair('oriented_box_fields', 'center_x,center_y,width,height,angle');
          for I := 0 to High(Value.Oriented) do
          begin
            Item := Prediction(Value.Oriented[I].ClassId, Value.Oriented[I].ClassName,
              Value.Oriented[I].Score);
            Rows.AddElement(Item);
            Item.AddPair('xywhr', Numbers([Value.Oriented[I].Box.CenterX,
              Value.Oriented[I].Box.CenterY, Value.Oriented[I].Box.Width,
              Value.Oriented[I].Box.Height, Value.Oriented[I].Box.Angle]));
          end;
        end;
      ytSemantic:
        begin
          Result.AddPair('mask_values', Numbers([0, 255]));
          for I := 0 to High(Value.Semantic) do
          begin
            Item := TJSONObject.Create;
            Rows.AddElement(Item);
            Item.AddPair('class_id', JSONInteger(Value.Semantic[I].ClassId));
            Item.AddPair('class_name', Value.Semantic[I].ClassName);
            Item.AddPair('mask', 'class-' + IntToStr(I) + '.u8');
          end;
        end;
      ytDepth:
        begin
          RequireCpu(Value.Depth.Units = duMeters, 'Unexpected depth units.');
          Result.AddPair('depth_units', 'meters');
          Result.AddPair('depth', 'depth.f32le');
        end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function YoloExampleResultJSON(const Value: TYoloExampleResult): string;
var
  Root: TJSONObject;
begin
  Root := YoloExampleResultObject(Value);
  try
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

end.
