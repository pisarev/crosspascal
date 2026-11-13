# Separate CPU and GPU downloads for vision models

Each row downloads one model and the shared EA019 Windows x64 SDK/runtime. The other four models are not downloaded. GPU means NVIDIA CUDA.

| Model | CPU preparation | GPU preparation | CPU model ZIP | GPU model ZIP range |
| --- | --- | --- | ---: | ---: |
| SqueezeNet 1.1 | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-SqueezeNet-CPU-ea019.zip) | [Prepare GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-SqueezeNet-GPU-ea019.zip) | 8.9 MiB | 9.0 MiB to 9.0 MiB |
| ResNet50 v1 | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-ResNet50-CPU-ea019.zip) | [Prepare GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-ResNet50-GPU-ea019.zip) | 181.4 MiB | 181.5 MiB to 181.5 MiB |
| YOLO11n classification | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-YOLO11n-Classification-CPU-ea019.zip) | [Prepare GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-YOLO11n-Classification-GPU-ea019.zip) | 22.9 MiB | 23.2 MiB to 23.2 MiB |
| YOLO11n detection | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-YOLO11n-Detection-CPU-ea019.zip) | [Prepare GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-YOLO11n-Detection-GPU-ea019.zip) | 33.0 MiB | 33.6 MiB to 33.7 MiB |
| RT-DETR R18vd | [Prepare CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-RT-DETR-R18vd-CPU-ea019.zip) | [Prepare GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-RT-DETR-R18vd-GPU-ea019.zip) | 155.8 MiB | 157.0 MiB to 157.1 MiB |

## Prepare and run

1. Extract the chosen ZIP. It contains one enclosing `Prepare-<Model>-<Device>` folder.
2. Open that folder and run `Prepare.cmd`. The chosen CPU/GPU mode is already set; do not add `-Device` again.
3. Wait for READY. Open `VisionModels.dproj` in Delphi 13.2 or `VisionModels.lpi` in Lazarus 4.8. Select Windows x64 / Release, build and run. The supplied Lazarus executable can also be run directly.
4. The matching model profile and bus image are already selected. Click **Run inference**.

Both variants require Windows x64 and at least 1 GiB of free system RAM before loading the model, in addition to memory used by Windows and the IDE. GPU preparation also requires at least 1,024 MiB free VRAM, a driver supporting CUDA 12.8 and compute capability 6.1, 7.5, 8.6, 8.9 or 12.0. It checks CUDA device 0 and rejects an incompatible GPU instead of silently changing the selected device.

The first preparation also downloads 407.2 MiB of shared SDK/runtime/sample files. They are reused on later runs. Allow room for both downloaded ZIPs and extracted files; Prepare checks disk space.

Preparation uses Windows PowerShell and requires neither Python nor a GitHub account. The archive has its manifest and all helper files inside its enclosing folder. Keep them together.

If you edited the prepared INI manually, Prepare preserves it. Select the matching profile and bundle in the app or use `Prepare.cmd -InstallRoot C:\CrossPascal\new-vision` to prepare fresh defaults.

From this source checkout, `prepare/vision/<profile>/Prepare-CPU.cmd` and `Prepare-GPU.cmd` select a device. `Prepare.cmd` in that same directory uses Auto and may fall back to CPU with an explanation. The original [all-five-model starter](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-VisionModels-ea019.zip) remains available.

## Manual model files

Install the coordinated SDK and dependencies first. Extract one model ZIP, retain the entire enclosed bundle folder, and choose that folder and the matching profile in VisionModels. A model ZIP alone does not include the shared SDK/runtime.

The per-model archives preserve every accepted model file byte for byte, including its source, licence, manifest, compiled DLL and input sidecar. They do not reconvert or quantize the model. SqueezeNet and ResNet50 use the same ONNX source in both variants. The retained CPU YOLO11n and RT-DETR builds use ONNX exports; the native CUDA builds use the original PT/Safetensors checkpoint pinned by those exports. The upstream checkpoint identity, input shape and preprocessing agree. Numerical results need not be bit-identical.

### SqueezeNet 1.1

Apache-2.0 as declared in the accompanying pinned source pack.

- [CPU ZIP](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-squeezenet-cpu-ea019.zip) — 8.9 MiB.
- [GPU CC 6.1](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-squeezenet-cuda-sm_61-ea019.zip) — 9.0 MiB.
- [GPU CC 7.5](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-squeezenet-cuda-sm_75-ea019.zip) — 9.0 MiB.
- [GPU CC 8.6](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-squeezenet-cuda-sm_86-ea019.zip) — 9.0 MiB.
- [GPU CC 8.9](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-squeezenet-cuda-sm_89-ea019.zip) — 9.0 MiB.
- [GPU CC 12.0](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-squeezenet-cuda-sm_120-ea019.zip) — 9.0 MiB.

### ResNet50 v1

Apache-2.0 as declared in the accompanying pinned source pack.

- [CPU ZIP](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-resnet50-cpu-ea019.zip) — 181.4 MiB.
- [GPU CC 6.1](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-resnet50-cuda-sm_61-ea019.zip) — 181.5 MiB.
- [GPU CC 7.5](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-resnet50-cuda-sm_75-ea019.zip) — 181.5 MiB.
- [GPU CC 8.6](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-resnet50-cuda-sm_86-ea019.zip) — 181.5 MiB.
- [GPU CC 8.9](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-resnet50-cuda-sm_89-ea019.zip) — 181.5 MiB.
- [GPU CC 12.0](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-resnet50-cuda-sm_120-ea019.zip) — 181.5 MiB.

### YOLO11n classification

AGPL-3.0; preserve the accompanying model and exporter sources and terms.

- [CPU ZIP](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cls-cpu-ea019.zip) — 22.9 MiB.
- [GPU CC 6.1](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cls-cuda-sm_61-ea019.zip) — 23.2 MiB.
- [GPU CC 7.5](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cls-cuda-sm_75-ea019.zip) — 23.2 MiB.
- [GPU CC 8.6](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cls-cuda-sm_86-ea019.zip) — 23.2 MiB.
- [GPU CC 8.9](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cls-cuda-sm_89-ea019.zip) — 23.2 MiB.
- [GPU CC 12.0](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cls-cuda-sm_120-ea019.zip) — 23.2 MiB.

### YOLO11n detection

AGPL-3.0; preserve the accompanying model and exporter sources and terms.

- [CPU ZIP](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cpu-ea019.zip) — 33.0 MiB.
- [GPU CC 6.1](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cuda-sm_61-ea019.zip) — 33.6 MiB.
- [GPU CC 7.5](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cuda-sm_75-ea019.zip) — 33.6 MiB.
- [GPU CC 8.6](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cuda-sm_86-ea019.zip) — 33.6 MiB.
- [GPU CC 8.9](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cuda-sm_89-ea019.zip) — 33.6 MiB.
- [GPU CC 12.0](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-yolo11n-cuda-sm_120-ea019.zip) — 33.7 MiB.

### RT-DETR R18vd

Apache-2.0 as declared in the accompanying pinned source pack.

- [CPU ZIP](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-rtdetr-r18vd-cpu-ea019.zip) — 155.8 MiB.
- [GPU CC 6.1](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-rtdetr-r18vd-cuda-sm_61-ea019.zip) — 157.0 MiB.
- [GPU CC 7.5](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-rtdetr-r18vd-cuda-sm_75-ea019.zip) — 157.0 MiB.
- [GPU CC 8.6](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-rtdetr-r18vd-cuda-sm_86-ea019.zip) — 157.0 MiB.
- [GPU CC 8.9](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-rtdetr-r18vd-cuda-sm_89-ea019.zip) — 157.0 MiB.
- [GPU CC 12.0](https://github.com/pisarev/crosspascal/releases/download/early-access-019/vision-rtdetr-r18vd-cuda-sm_120-ea019.zip) — 157.1 MiB.

CUDA hardware execution has been checked on GTX 1650 (CC 7.5) and RTX 4060 Ti (CC 8.9). CC 6.1, 8.6 and 12.0 are build-checked targets; this is not a claim that those GPUs were run.

Exact sizes and SHA-256 values: [VISION-DOWNLOADS.json](https://github.com/pisarev/crosspascal/releases/download/early-access-019/VISION-DOWNLOADS.json).

## Distribution layout

Every release archive must contain one enclosing folder with a clear stable name. No Prepare files are placed loose at the archive root. Verify the member paths, extract the archive and launch its enclosed Prepare.cmd before release. Existing SDK, source, complete-example and model archive roots retain their established names.
