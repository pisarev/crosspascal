# Prepare and run an example

Download **crosspascal-examples-prepare-ea019.zip** from the
[EA019 release](https://github.com/pisarev/crosspascal/releases/tag/early-access-019)
and extract it to a writable folder. Open your example's folder and run
**Prepare.cmd**. Shared example folders offer a menu.

The source repositories and releases are public. Prepare downloads without a
GitHub account or token. If GitHub's anonymous request limit is reached, you can
retry with an existing GitHub CLI login, a saved credential, or an optional token
entered with hidden input. Saving a token in Windows Credential Manager is optional. A fine-grained
token needs Contents: Read-only for this repository. Never paste tokens into a
project, script or issue.

Prepare uses Windows PowerShell to download the SDK, native libraries, model
bundles and a sample image. The prepared examples run without Python. Prepare
sets up the DLLs and selects a model bundle automatically. Downloads are checked
with SHA-256, shared across examples, and resumed after interruption.

Wait for **READY**. In the opened project folder, use the .dproj in Delphi 13.2
or the .lpi in Lazarus 4.8. Select Windows 64-bit / Release and press **Run**.
Model, library and image paths are already in the generated *.prepared.ini files.
Keep the prepared folder together. Distributed Pascal executables are built with
Lazarus; Delphi builds verify source compatibility.

The default installation is %LOCALAPPDATA%/CrossPascal/early-access-019. Set
CROSSPASCAL_PREPARE_HOME before running Prepare.cmd to choose another drive.
Downloads use a sibling downloads folder. Repeating preparation preserves your
editable source and settings changes. A changed fixed dependency requires a new
installation folder. Prepare checks disk space before extraction.

## Download one vision model

SqueezeNet 1.1, ResNet50 v1, YOLO11n classification, YOLO11n detection and RT-DETR R18vd each have separate CPU and GPU preparation ZIPs. [Choose a model and device](VISION-DOWNLOADS.md). These kits download only the selected model plus shared dependencies; the original all-five-model kit remains available.

Each ZIP contains an enclosing folder. Extract it, open that folder and run `Prepare.cmd`. The dedicated CPU/GPU kit already sets its device. The generic kits below retain `-Device` and Auto selection.

## CPU or CUDA

Prepare checks CUDA device 0, the NVIDIA driver and free GPU memory before
downloading a model. It selects a ready CUDA bundle when it finds a match
and prints its decision and the remaining download size. Otherwise it uses
the CPU bundle and explains why.

From Command Prompt, use `Prepare.cmd -Device CPU` to select CPU or
`Prepare.cmd -Device CUDA` to require CUDA. In CUDA mode an incompatible card,
older driver or insufficient free GPU memory is reported before downloading
the model. Repeating Prepare updates its generated defaults if you have kept
them as supplied.

CUDA inference requires an NVIDIA driver supporting CUDA 12.8 and a matching
bundle for compute capability 6.1, 7.5, 8.6, 8.9 or 12.0. The desktop examples
use CUDA device 0. The CUDA Toolkit is needed for CUDA conversion with NVRTC.
The prepared GPU examples use compiled kernels and the supplied TVM runtime.

| Examples | Free GPU memory checked by Prepare |
| --- | ---: |
| VisionModels | 1,024 MiB |
| QwenChat and ImagePrompt | 5,120 MiB |
| GemmaChat and the Gemma 2 text examples | 5,500 MiB |

Free GPU memory depends on the display and other applications. A 3 GiB
GTX 1060 can use a matching vision bundle when enough memory is free.
For language models, a card with at least 8 GiB of VRAM leaves more room for
the model and the desktop. Close GPU-heavy applications if the available
memory changes between preparation and inference.

## Model terms and requirements

The MIT license for original CrossPascal code does not cover model weights or
third-party libraries. Review the relevant terms before use or redistribution.

| Examples / models | Terms | Suggested system RAM |
| --- | --- | --- |
| QwenChat and ImagePrompt: Qwen2.5-VL 3B | [Qwen Research License](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct/blob/66285546d2b821cf421d4f5eb2576359d3770cd3/LICENSE): non-commercial research and evaluation only; commercial use needs a separate license from Alibaba Cloud. Built with Qwen. | 24 GiB |
| GemmaChat: Gemma 3n E4B | [Gemma Terms](https://ai.google.dev/gemma/terms) and [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). | 32 GiB |
| Five text console examples: experimental Gemma 2 2B | Same Gemma terms; limited short-context completion profile. | 16 GiB |
| VisionModels: YOLO11n detection/classification | AGPL-3.0; proprietary use may require a separate [Ultralytics license](https://www.ultralytics.com/license). | See the model pack |
| VisionModels: SqueezeNet, ResNet50, RT-DETR | Apache-2.0 as declared in each pinned source pack. | See the model pack |

CPU model downloads are about 3.6 GiB for Gemma 2, 11.4 GiB for Gemma 3n, and
5.2 GiB for Qwen-VL, plus runtime files. Prepare prints the actual download size
for the selected CPU or CUDA package. The packs contain their licenses, NOTICE, modification
records and checksums. Preserve these when redistributing. Gemma use restrictions
apply to the supplied derivatives and must be carried into onward distribution
agreements. See [license scope](LICENSE-SCOPE.md) for code, libraries and relinking.

QwenChat and GemmaChat: click Load model, then Generate. Auto (0) uses the available
context; Stop remains available. Image-capable profiles accept one image. Console
examples use prepared settings without IDE arguments. VisionModels lets you choose
five prepared profiles and reports the device that ran inference. MarkerLite exposes image operations. LoadResizeSave
writes a resized PNG to the SDK results folder. CrossCVHello and LeptonicaHello
perform small native-library checks.

CrossPascalConvert.exe can build native bundles from supported original
checkpoints. Select the CUDA entry for the model and enter the target architecture.
Conversion uses the native TVM compiler and NVRTC for CUDA kernels.
