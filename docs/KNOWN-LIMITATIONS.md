# Known limitations

## Platforms and devices

This release targets Windows x64 with Delphi 13.2 or Lazarus 4.8 and FPC 3.2.2. Earlier compiler versions and Linux are outside the current verification matrix.

CUDA requires a compatible NVIDIA driver and enough free device memory. The
examples use CUDA device 0. The ready language packs select one of five
compiled architectures and share their weights. Prepare selects the matching
VisionModels pack. Converting a checkpoint builds one target. See the
[converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md)
for toolchain requirements.

## Models

QwenChat accepts the legacy named 64-token bundles and compatible local Qwen2 dense-text bundles with a 2,048-token context. Prompt, chat template and answer share that capacity. The default output setting is 0 (automatic), with optional answer budgets, a positive manual limit and Stop. There is no fixed six- or sixteen-token output cap. Loaded weights are reused between requests and text appears during generation. These checks do not establish quality for every compatible checkpoint or prompt. Dense Qwen CUDA inference has no silent CPU fallback. Qwen2.5-VL CPU is a separate explicitly selected architecture profile.

Both chat forms support Gemma 3n and Qwen2.5-VL CPU and CUDA profiles through
native TVM calls from Pascal. CPU image prompts can take several minutes. CUDA
text projections use INT8 weights with FP32 arithmetic. This can change answers
relative to CPU FP32. The Gemma 3n image profile resizes to 768 pixels and uses
256 context tokens per image. Qwen2.5-VL uses aspect-preserving square padding
with 64 image tokens at 224 pixels. These checks cover the supplied profile
and representative prompts. Audio and video input remain outside the
supported profiles. See [model input capabilities](MODEL-MODALITIES.md).

The five CPU vision checks cover the pinned model, preprocessing, and application result. They do not measure dataset accuracy or performance. Select the corresponding model source pack before conversion.

The [EA020 PaddleOCR example](../examples/paddle-ocr/README.md) uses fixed PP-OCRv5 Server detector and recognizer inputs. Reference checks cover two photos on Windows CPU and CUDA `sm_89`. Wide text crops are constrained by the recognizer width. The remaining CUDA targets have checked builds.

BiRefNet uses the full SwinL checkpoint with a fixed 800-pixel input. The native CPU and CUDA `sm_89` tensor checks cover three photos. They compare execution against the selected ONNX profile, rather than measuring dataset accuracy. The upstream checkpoint's 2048-pixel benchmark scores do not describe this HR800 profile. Inspect fine edges before using a cutout. The ready GPU bundle targets `sm_89`; other BiRefNet GPU architectures are outside this release's checked builds.

The OmDet result covers two recorded Windows CPU fixtures and includes a known difference in the raw numerical comparison. OmDet remains outside the supported profiles in this Windows SDK. The older Gemma 2 download retains its documented numerical limitations. The native converter builds both Gemma 2 soft-capping operations from the original checkpoint.

## Native components

The OpenCV and Leptonica examples cover particular image operations. The OpenCV bridge also passed a basic FFmpeg video write/read check. The example results do not cover every binding, codec, or video configuration.

The native image libraries are built locally from the companion source assets. The build requires a Linux Docker engine and access to the pinned package sources. The OpenCV build enables its nonfree modules and links LGPL FFmpeg statically. See [license scope](LICENSE-SCOPE.md) for source and relinking details.
