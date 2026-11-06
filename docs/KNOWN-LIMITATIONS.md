# Known limitations

## Platforms and devices

This release targets Windows x64 with Delphi 13.2 or Lazarus 4.8 and FPC 3.2.2. Earlier compiler versions and Linux are outside the current verification matrix.

CUDA conversion and inference require compatible NVIDIA hardware, drivers, and enough free device memory. The converter can detect the local architecture or build for a manually selected architecture. A bundle is specific to its selected architecture. QwenChat uses device 0 in the visible CUDA device list. See the [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) for toolchain requirements.

## Models

The Qwen example uses one FP32 profile with a 64-token context. That context includes the prompt, chat template, and generated tokens. The default first reply is limited to six new tokens. There is no CPU fallback for this profile. Additional devices, models, context lengths, precisions, and broad language-quality claims are outside this check.

The five CPU vision checks cover the pinned model, preprocessing, and application result. They do not measure dataset accuracy or performance. Select the corresponding model source pack before conversion.

The OmDet result covers two recorded Windows CPU fixtures and includes a known difference in the raw numerical comparison. It is outside the supported profiles in the Windows SDK. PaddleOCR, BiRefNet, and Gemma are also outside the supported SDK profiles.

## Native components

The OpenCV and Leptonica examples cover particular image operations. The OpenCV bridge also passed a basic FFmpeg video write/read check. The example results do not cover every binding, codec, or video configuration.

The native image libraries are built locally from the companion source assets. The build requires a Linux Docker engine and access to the pinned package sources. The OpenCV build enables its nonfree modules and links LGPL FFmpeg statically. See [license scope](LICENSE-SCOPE.md) for source and relinking details.
