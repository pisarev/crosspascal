# Release notes

## early-access-025

EA025 extends YoloModels from 23 to 115 prepared profiles across the existing seven tasks. The size kits are `n`, `s`, `m`, `b`, `l`, `x`, and `all`. The `b` kit contains YOLOv10b; YOLOv13 has `n`, `s`, `l`, and `x` profiles.

The default kit remains `n`. Separate preparation kits install a selected size, and the `all` kit installs every profile. Each kit offers CPU, NVIDIA CUDA, and Auto selection. CUDA packages retain the CPU models and provide `sm_75`, `sm_86`, `sm_89`, and `sm_120` code. The converter uses the complete trusted catalog, regardless of the size selected for the example.

The new SDK includes the pinned catalogs and weight-free graph recipes. Existing `n` model packages and other immutable model downloads retain their original URLs and SHA-256 values. [Prepare](PREPARE-EXAMPLES.md) uses the updated SDK and matching size kits. [Model provenance](yolo/MODEL-PROVENANCE.json) records each profile's upstream terms.

## early-access-024

EA024 adds native YOLO conversion and the YoloModels example: 23 profiles from v5, v8, v10, 11, 12, v13 and 26 across seven typed tasks. Ready CPU bundles and CUDA targets `sm_75`, `sm_86`, `sm_89` and `sm_120` share the SDK's pinned runtime. CUDA preparation retains the CPU package too.

The Windows model loader preserves Unicode filenames across the Pascal/FFI boundary, including adjacent input sidecars. The FFI source patch, build recipe and exact DLL pins accompany the runtime.

Existing EA023 language features and immutable model assets are retained. New [preparation kits](PREPARE-EXAMPLES.md) select the EA024 SDK/runtime; the model downloads keep their original versioned URLs and SHA-256 values. Per-profile YOLO source terms are recorded in [model provenance](yolo/MODEL-PROVENANCE.json).


## EA023 language models and image input

The ready language bundles add Huihui Gemma 3n E4B abliterated on CPU and
CUDA, Qwen3.8-27B original UD-Q4_K_M on CPU and CUDA, and original BF16
Qwen3.8-27B with CUDA layer streaming. Each accepts text and one image.
The matching native converter profiles can include the required vision
weights. Existing text-only architectures remain text-only.

Gemma 3n and the new Qwen3.8 bundles use a 4,096-token context. Automatic
output uses the remaining context, and generation reports its actual stop
reason and token counts. The chat examples align Answer and Message and
use a compact folder button beside the Installed SDK folder field.

The shared API, chats and console examples build in Delphi 13.2 and
Lazarus 4.8 / FPC 3.2.2. Windows image and text checks covered the supplied
CPU and CUDA language routes. The new CUDA bundles include targets
sm_75, sm_86, sm_89 and sm_120; inference checks used sm_89.

The combined Prepare menu retains the previous 16 choices and adds three
language model entries. Five dedicated CPU/GPU kits select the new models.
Prepare fills the model and SDK paths and skips an unavailable CUDA-only
entry when preparing all supported examples.

## EA020 PaddleOCR

[PaddleOCR](../examples/paddle-ocr/README.md) reads text in photos, displays detected regions and exports plain text or JSON. The PP-OCRv5 Server detector and recognizer are available as separate CPU and NVIDIA CUDA downloads. Prepare sets up both models for the selected device.

The native converter accepts the pinned PaddleOCR ONNX exports. The Pascal example builds in Delphi and Lazarus. Windows x64 CPU and CUDA `sm_89` inference were checked against the original ONNX models on two photos. Additional CUDA targets have compiled bundles.

## EA019 ready CUDA model bundles

The same chat, console and VisionModels examples can open CPU and CUDA bundles.
Prepare selects a compatible package using CUDA device 0, the installed driver
and available GPU memory. Use `Prepare.cmd -Device CPU` or `-Device CUDA` to
choose explicitly.

The prepared CUDA models include Gemma 3n E4B with image support, Gemma 2 2B,
Qwen2.5-VL 3B, YOLO11n detection and classification, RT-DETR R18vd, SqueezeNet
1.1 and ResNet50 v1. The compiled targets are `sm_61`, `sm_75`, `sm_86`,
`sm_89` and `sm_120`. The converter can also build those CUDA profiles from
the supported original checkpoints. Inference and conversion run without Python.

## EA018 native TVM release

EA018 packages the verified native Windows x64 SDK as a separate pre-release.
Pascal calls TVM directly to run the supported language and vision models.
CrossPascal Converter builds TVM bundles from supported original checkpoints.
Inference and conversion run without Python.

Prepare installs EA018 in `%LOCALAPPDATA%/CrossPascal/early-access-018` by default.
The shared download cache can reuse model archives.

## EA017 native TVM update

The Windows x64 SDK runs the supported language and vision models through TVM
directly from Pascal. The desktop converter imports the supported checkpoint
formats, builds TVM graphs, and compiles Windows model libraries without Python.
`Prepare.cmd` uses Windows PowerShell and installs the native SDK and the
selected dependencies in `%LOCALAPPDATA%/CrossPascal/early-access-017-native`
by default. Existing model downloads can be reused from the download cache.

The Windows x64 checks covered all 13 example builds in Delphi and Lazarus,
text and image requests on Gemma 3n CPU and CUDA, Qwen2.5-VL on CPU, the
supported text profiles, and all five CPU vision profiles. Image processing
on the tested CPU took several minutes. The release is still a pre-release.

## EA017 maintenance update, 10 November 2026

The supplied GUI examples use aligned controls with consistent button dimensions and an explicit keyboard tab order. The Pascal sources were formatted with the updated pascal_fmt utility. Copyright notices are retained in library code and omitted from the examples. All 13 examples were built and started with Delphi 13.2 and Lazarus 4.8 on Windows x64; the interface checks did not load a model or run inference.

## EA017 initial release

Public downloads no longer require GitHub authorization. GitHub request-limit recovery can still use an optional authenticated retry. Release metadata is
cached during preparation to reduce API requests.

Model licenses are shown before dependency preparation and in the guides. Pascal comment headers were checked across all source extensions: two component
headers were completed and two test-program headers were removed. All accepted model, runtime and executable
bytes from EA016 are retained. This release changes preparation and documentation,
not model inference or the accepted Delphi/Lazarus example behavior.
