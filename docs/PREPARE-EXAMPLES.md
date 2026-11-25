# Prepare and run an example

Download **crosspascal-examples-prepare-ea024-r1.zip** from the
[EA024 release](https://github.com/pisarev/crosspascal/releases/tag/early-access-024-r1)
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
For chat applications, **Installed SDK folder** is set to the actual installed SDK root.
Keep the prepared folder together. Distributed Pascal executables are built with
Lazarus; Delphi builds verify source compatibility.

The default installation for EA024 launchers is %LOCALAPPDATA%/CrossPascal/early-access-024-r1. Set
CROSSPASCAL_PREPARE_HOME before running Prepare.cmd to choose another drive.
Downloads use a sibling downloads folder. Repeating preparation preserves your
source, project and package settings, and locally rebuilt example executables.
Runtime libraries, converters and models are still checked against their recorded
SHA-256 values. A missing SDK file or changed fixed dependency is reported with
its exact path; preserve your work and use a new installation folder. Prepare
checks disk space before extraction.

## Huihui Gemma and Qwen3.8 text and images

These dedicated kits select the model and device. Extract the ZIP and run
**Prepare.cmd**, then open the supplied GemmaChat or QwenChat project, or
run its ready Lazarus executable. Model and SDK paths are filled automatically.

| Model | Device | Prepare kit | Model download | Installed model |
| --- | --- | --- | ---: | ---: |
| Huihui Gemma 3n E4B abliterated | CPU | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-HuihuiGemma3nE4B-CPU-ea024-r1.zip) | 14.31 GiB | 26.81 GiB |
| Huihui Gemma 3n E4B abliterated | CUDA | [Prepare CUDA](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-HuihuiGemma3nE4B-GPU-ea024-r1.zip) | 10.52 GiB | 17.06 GiB |
| Qwen3.8-27B UD-Q4_K_M | CPU | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-Qwen38-27B-Q4-CPU-ea024-r1.zip) | 16.32 GiB | 16.32 GiB |
| Qwen3.8-27B UD-Q4_K_M | CUDA | [Prepare CUDA](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-Qwen38-27B-Q4-GPU-ea024-r1.zip) | 16.40 GiB | 16.40 GiB |
| Qwen3.8-27B original BF16 | CUDA | [Prepare CUDA](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-Qwen38-27B-BF16-GPU-ea024-r1.zip) | 52.73 GiB | 52.73 GiB |

The figures cover each model package. Prepare also accounts for the SDK,
shared dependencies, download cache, and extraction space. The ready context
is 4,096 tokens, including the chat template, image tokens, prompt, and answer.
Qwen Q4 retains its original mixed GGUF bytes. Original BF16 uses CUDA
layer streaming. The Windows checks used a machine with 32 GiB system RAM.

The original Gemma and Qwen-VL entries remain available in the combined
menu. See the [Huihui guide](https://github.com/pisarev/crosspascal-convert/blob/main/docs/HUIHUI-GEMMA3N.md)
and [Qwen3.8 guide](https://github.com/pisarev/crosspascal-convert/blob/main/docs/QWEN35.md)
for source identities, conversion, and model terms.

## YOLO models

The [YoloModels example](../examples/yolo-models/README.md) runs 23 profiles across seven tasks: classification, object detection, instance segmentation, pose, oriented detection, semantic segmentation, and depth estimation.

Use `vision/yolo-models/Prepare.cmd` from the combined preparation ZIP, or download [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-YoloModels-CPU-ea024-r1.zip) or [Prepare GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-024-r1/Prepare-YoloModels-GPU-ea024-r1.zip). The generic script selects Auto; `Prepare-CPU.cmd` and `Prepare-GPU.cmd` set the device explicitly.

The CPU archive is about 218 MiB. A CUDA preparation keeps that CPU package and adds the one archive for the installed GPU, about 223 MiB. The SDK and shared runtime are separate dependencies; Prepare prints the actual remaining download size. The other CUDA archives are not downloaded.

The SDK includes all profile manifests and weight-free graph recipes. Original checkpoints can be converted with the desktop converter or `ConvertYolo`; ready model DLLs are downloaded by Prepare. See [model provenance](yolo/MODEL-PROVENANCE.json) and its adjacent source notices for the upstream terms.

## Download one vision model

SqueezeNet 1.1, ResNet50 v1, YOLO11n classification, YOLO11n detection and RT-DETR R18vd each have separate CPU and GPU preparation ZIPs. [Choose a model and device](VISION-DOWNLOADS.md). These kits download only the selected model plus shared dependencies; the original all-five-model kit remains available.

Each ZIP contains an enclosing folder. Extract it, open that folder and run `Prepare.cmd`. The dedicated CPU/GPU kit already sets its device. The generic kits below retain `-Device` and Auto selection.

The six [console examples](../examples/language-models/README.md) have separate CPU and CUDA launchers in the [EA024 downloads](https://github.com/pisarev/crosspascal/releases/tag/early-access-024-r1). From the combined ZIP, you can also run an example's Prepare.cmd with `-Device CPU` or `-Device CUDA`.

For text detection and recognition, the [PaddleOCR example](../examples/paddle-ocr/README.md) prepares both PP-OCRv5 Server models for the same device. The EA020 release also provides each model as a separate download.

For background removal, the [BiRefNet example](../examples/birefnet/README.md) has separate CPU and GPU preparation kits in EA024. It uses the full SwinL model with a fixed 800-pixel input. The GPU kits select a bundle for `sm_75`, `sm_86`, `sm_89`, or `sm_120` and require at least 4 GiB of free GPU memory.

For text-guided detection, the [OmDet-Turbo example](../examples/omdet-turbo/README.md) has separate CPU and GPU preparation kits. Enter class names for the objects you want to find. The example runs the text encoder and detector locally, then saves an annotated PNG or JSON.

## CPU or CUDA

Prepare checks CUDA device 0, the NVIDIA driver and free GPU memory before
downloading a model. It selects a ready CUDA bundle when it finds a match
and prints its decision and the remaining download size. When a CPU bundle
is available, it falls back to that bundle and explains why. For a CUDA-only
profile, it reports the unmet requirement and stops. That profile cannot use
`-Device CPU`. With `-All`, an unavailable CUDA-only profile is skipped
while the other selected examples are prepared.

From Command Prompt in an example's combined-kit folder, use
`Prepare.cmd -Device CPU` to select CPU or `Prepare.cmd -Device CUDA` to
require CUDA. Dedicated CPU/GPU ZIPs already set the device; run their
`Prepare.cmd` without adding another `-Device`. In CUDA mode an incompatible card,
older driver or insufficient free GPU memory is reported before downloading
the model. Repeating Prepare updates its generated defaults if you have kept
them as supplied.

CUDA inference requires an NVIDIA driver supporting CUDA 12.8 and a matching
bundle for compute capability 6.1, 7.5, 8.6, 8.9 or 12.0. The desktop examples
use CUDA device 0. The CUDA Toolkit is needed for CUDA conversion with NVRTC.
The prepared GPU examples use compiled kernels and the supplied TVM runtime.
All CUDA-enabled examples provide bundles for compute capabilities 7.5, 8.6, 8.9, and 12.0: GTX 1650 and the RTX 20, 30, 40, and 50 families. Some earlier profiles also provide 6.1.

| Examples | Free GPU memory checked by Prepare |
| --- | ---: |
| VisionModels | 1,024 MiB |
| YoloModels | 1,536 MiB |
| PaddleOCR | 2,048 MiB |
| BiRefNet | 4,096 MiB |
| OmDetTurbo | 2,048 MiB |
| QwenChat and ImagePrompt | 5,120 MiB |
| GemmaChat | 5,312 MiB |
| Gemma 2 text examples | 5,500 MiB |
| HuihuiGemmaChat | 5,984 MiB |
| Qwen38Q4Chat | 3,873 MiB |
| Qwen38BF16Chat | 3,083 MiB |

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
| BiRefNet HR800: full SwinL | MIT as declared in the pinned upstream model card; included notices apply. | 16 GiB |
| OmDet-Turbo Swin-Tiny and CLIP | Apache-2.0 for OmDet and the checkpoint; the CLIP tokenizer MIT notice is included. | 16 GiB |
| QwenChat and ImagePrompt: Qwen2.5-VL 3B | [Qwen Research License](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct/blob/66285546d2b821cf421d4f5eb2576359d3770cd3/LICENSE): non-commercial research and evaluation only; commercial use needs a separate license from Alibaba Cloud. Built with Qwen. | 24 GiB |
| GemmaChat: Gemma 3n E4B | [Gemma Terms](https://ai.google.dev/gemma/terms) and [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). | 32 GiB |
| HuihuiGemmaChat: abliterated Gemma 3n E4B text and images | [Gemma Terms](https://ai.google.dev/gemma/terms), incorporated use policy, and supplied derivative notices. | 32 GiB |
| Qwen38Q4Chat and Qwen38BF16Chat: Qwen3.8-27B text and images | Apache-2.0; included model and dependency notices apply. | 32 GiB |
| Five text console examples: experimental Gemma 2 2B | Same Gemma terms; limited short-context completion profile. | 16 GiB |
| YoloModels: 23 YOLO profiles | [Pinned model/source provenance](yolo/MODEL-PROVENANCE.json) and the supplied GPL/AGPL notices apply; the original CrossPascal source license does not replace them. | — |
| VisionModels: YOLO11n detection/classification | AGPL-3.0; proprietary use may require a separate [Ultralytics license](https://www.ultralytics.com/license). | See the model pack |
| VisionModels: SqueezeNet, ResNet50, RT-DETR | Apache-2.0 as declared in each pinned source pack. | See the model pack |
| PaddleOCR: PP-OCRv5 Server detector and recognizer | Apache-2.0; Clipper 6.4.2 uses the Boost Software License. [PaddleOCR terms and notices](https://github.com/pisarev/crosspascal/tree/main/examples/paddle-ocr#licenses). | See the PaddleOCR guide |

For the original profiles, CPU model downloads are about 3.6 GiB for Gemma 2,
11.4 GiB for Gemma 3n, and 5.2 GiB for Qwen-VL, plus runtime files. Prepare prints the actual download size
for the selected CPU or CUDA package. The packs contain their licenses, NOTICE, modification
records and checksums. Preserve these when redistributing. Gemma use restrictions
apply to the supplied derivatives and must be carried into onward distribution
agreements. See [license scope](LICENSE-SCOPE.md) for code, libraries and relinking.

QwenChat and GemmaChat: click Load model, then Generate. Auto (0) sets the answer
budget within the remaining compiled context; the status reports the stop reason
with token counts. Stop remains available. Image-capable profiles accept one image. Console
examples use prepared settings without IDE arguments. VisionModels lets you choose
five prepared profiles and reports the device that ran inference. MarkerLite exposes image operations. LoadResizeSave
writes a resized PNG to the SDK results folder. CrossCVHello and LeptonicaHello
perform small native-library checks.

CrossPascalConvert.exe can build native bundles from supported original
checkpoints. Select the CUDA entry for the model and enter the target architecture.
Conversion uses the native TVM compiler and NVRTC for CUDA kernels.

## File inventories

The SDK includes a `SOURCE-INDEX.json` for each source component and a root `SDK-FILES.json` inventory for the complete SDK. Check these inventories before running Prepare, building an example or editing files. Prepare records installed packages separately in its receipts.

The source archive and Git repositories have the corresponding source inventories. The SDK also supplies the native libraries and ready application executables.
