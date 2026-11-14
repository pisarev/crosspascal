# CrossPascal

For a first run, use the [Prepare.cmd quickstart](docs/PREPARE-EXAMPLES.md) to download the dependencies and sample data automatically.

CrossPascal gives Object Pascal applications image processing, geometry, and local model inference. The Windows x64 early access SDK brings together five repositories, a native desktop model converter, and Delphi and Lazarus examples.

## Get started

1. Open [CrossPascal Releases](https://github.com/pisarev/crosspascal/releases) and select the Windows x64 early access release. Download the SDK and the companion assets listed in its release notes. The GitHub source ZIP contains only the source of one repository.
2. Extract the SDK into a writable directory such as `C:\CrossPascal`. Keep the five repository folders together.
3. Follow the [Windows setup guide](docs/WINDOWS-EARLY-ACCESS.md) for the dependencies and example projects. Use Delphi 13.2 or Lazarus 4.8 with FPC 3.2.2 and build for Windows x64.

Try the Geometry and DisjointSet projects first if you want examples with no external runtime. For images, Prepare downloads the ready OpenCV or Leptonica runtime and sets the example paths. The matching source assets remain available for rebuilding.

## Run a model locally

The supplied language and vision models run through native TVM from Pascal. Open `CrossPascalConvert.exe` to build a bundle from an original checkpoint. Choose a profile, the source and a new output folder, then use **Preview** and **Build**. The [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) lists the supported formats and Windows and CUDA toolchains. Inference and conversion run without Python.

For CPU vision, run the VisionModels preparation script to download the ready model bundles and libraries. The profiles cover SqueezeNet 1.1, ResNet50, YOLO11n classification, YOLO11n detection, and RT-DETR R18vd.

For text in photos, try [PaddleOCR](examples/paddle-ocr/README.md). The example detects text regions, reads each crop and saves UTF-8 text or JSON with region coordinates and confidence scores. Windows x64 CPU and NVIDIA CUDA bundles are available.

For background removal, try [BiRefNet](examples/birefnet/README.md). It displays the original image beside a transparent preview or mask and saves an original-size PNG. The full SwinL HR800 model runs on CPU or NVIDIA CUDA `sm_89`.

For Gemma 3n, run the GemmaChat preparation script for the ready CPU model. The GGUF-to-TVM converter remains available for custom CPU or CUDA bundles. See [GemmaChat](examples/gemma-chat/README.md). GemmaChat streams text and retains loaded weights between requests, as QwenChat now does. Both demos expose explicit loading and unloading, generation settings, streaming, Stop, and image attachment. Compatible Gemma 3n CPU and CUDA image bundles accept pictures. The separate Qwen2.5-VL adapter converts compatible checkpoints for CPU text-and-image inference. Dense Qwen text bundles explain that an image cannot be used. See [model input capabilities](docs/MODEL-MODALITIES.md).

For short console programs, start with [Language models in a few Pascal calls](examples/language-models/README.md): load, configure, generate, stream, reuse, attach an image, and unload.

## Projects

| Project | What it provides |
| --- | --- |
| CrossPascal | Pascal algorithms, image adapters, and runnable examples |
| [CrossPascal Converter](https://github.com/pisarev/crosspascal-convert) | Native checkpoint import and TVM graph compilation |
| [CrossPascal TVM](https://github.com/pisarev/crosspascal-tvm) | Native Pascal TVM and DLPack interfaces, model helpers, and runtime setup |
| [CrossPascal OpenCV](https://github.com/pisarev/crosspascal-opencv) | Pascal bindings, a native bridge, image processing, and video I/O |
| [CrossPascal Leptonica](https://github.com/pisarev/crosspascal-leptonica) | Pascal bindings and helpers for scans and document images |

See [capabilities](docs/CAPABILITIES.md), [known limitations](docs/KNOWN-LIMITATIONS.md), and the [roadmap](docs/ROADMAP.md).

## License

Original CrossPascal code and documentation use the [MIT license](LICENSE). Third-party code, tools, and model files retain their own terms. See [license scope](docs/LICENSE-SCOPE.md).
