# Prepare and run an example

Download **crosspascal-examples-prepare-ea017.zip** from the
[EA017 release](https://github.com/pisarev/crosspascal/releases/tag/early-access-017)
and extract it to a writable folder. Open your example's folder and run
**Prepare.cmd**. Shared example folders offer a menu.

Public releases download without a GitHub account or token. While a release is
private, your GitHub account needs repository access. If anonymous access is
denied or GitHub's public request limit is reached, Prepare can retry with your
existing GitHub CLI login, a saved credential, or a token entered with hidden
input. Saving a token in Windows Credential Manager is optional. A fine-grained
token needs Contents: Read-only for this repository. Never paste tokens into a
project, script or issue.

Prepare downloads a portable preparation runtime, the SDK, native libraries,
model bundles and a sample image. No Python installation, manual DLL copying,
native-library build or CPU model conversion is required. Downloads are checked
with SHA-256, shared across examples, and resumed after interruption.

Wait for **READY**. In the opened project folder, use the .dproj in Delphi 13.2
or the .lpi in Lazarus 4.8. Select Windows 64-bit / Release and press **Run**.
Model, library and image paths are already in the generated *.prepared.ini files.
Keep the prepared folder together. Distributed Pascal executables are built with
Lazarus; Delphi builds verify source compatibility.

The default installation is %LOCALAPPDATA%/CrossPascal/early-access-017. Set
CROSSPASCAL_PREPARE_HOME before running Prepare.cmd to choose another drive.
Downloads use a sibling downloads folder. Repeating preparation preserves your
editable source and settings changes. A changed fixed dependency requires a new
installation folder. Prepare checks disk space before extraction.

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

Gemma and Qwen downloads are about 3.6, 11.4 and 5.2 GiB depending on the selected
model, plus runtime files. The packs contain their licenses, NOTICE, modification
records and checksums. Preserve these when redistributing. Gemma use restrictions
apply to the supplied derivatives and must be carried into onward distribution
agreements. See [license scope](LICENSE-SCOPE.md) for code, libraries and relinking.

QwenChat and GemmaChat: click Load model, then Generate. Auto (0) uses the available
context; Stop remains available. Image-capable profiles accept one image. Console
examples use prepared settings without IDE arguments. VisionModels lets you choose
five prepared CPU profiles. MarkerLite exposes image operations. LoadResizeSave
writes a resized PNG to the SDK results folder. CrossCVHello and LeptonicaHello
perform small native-library checks.

GPU conversion remains available in CrossPascalConvert.exe. Detect the local CUDA
architecture or select a target manually. CPU preparation does not install a CUDA
toolchain. Model behavior and accepted scope are unchanged from EA016.
