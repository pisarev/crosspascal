# CrossPascal

For a first run, use the [Prepare.cmd quickstart](docs/PREPARE-EXAMPLES.md) to download the dependencies and sample data automatically.

CrossPascal gives Object Pascal applications image processing, geometry, and local model inference. The Windows x64 early access SDK brings together five repositories, a browser-based model converter, and Delphi and Lazarus examples.

## Get started

1. Open [CrossPascal Releases](https://github.com/pisarev/crosspascal/releases) and select the Windows x64 early access release. Download the SDK and the companion assets listed in its release notes. The GitHub source ZIP contains only the source of one repository.
2. Extract the SDK into a writable directory such as `C:\CrossPascal`. Keep the five repository folders together.
3. Follow the [Windows setup guide](docs/WINDOWS-EARLY-ACCESS.md) for the dependencies and example projects. Use Delphi 13.2 or Lazarus 4.8 with FPC 3.2.2 and build for Windows x64.

Try the Geometry and DisjointSet projects first if you want examples with no external runtime. For images, Prepare downloads the ready OpenCV or Leptonica runtime and sets the example paths. The matching source assets remain available for rebuilding.

## Run a model locally

Open `CrossPascalConvert.exe` to start the converter. Choose a pinned Qwen2.5-Instruct download or a compatible local Safetensors folder, such as Qwen2.5-Coder-0.5B-Instruct. Select the detected CUDA architecture or enter the target architecture, then build the bundle. Open the supplied QwenChat executable or build it in your IDE. Auto uses the shared context window, and **Stop** keeps the partial answer. See the [QwenChat guide](examples/qwen-chat/README.md) for sampling and answer budgets, and the [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) for setup.

For CPU vision, run the VisionModels preparation script to download the ready model bundles and libraries. The profiles cover SqueezeNet 1.1, ResNet50, YOLO11n classification, YOLO11n detection, and RT-DETR R18vd.

For Gemma 3n, run the GemmaChat preparation script for the ready CPU model. The GGUF-to-TVM converter remains available for custom CPU or CUDA bundles. See [GemmaChat](examples/gemma-chat/README.md). GemmaChat streams text and retains loaded weights between requests, as QwenChat now does. Both demos expose explicit loading and unloading, generation settings, streaming, Stop, and image attachment. Compatible Gemma 3n CPU and CUDA image bundles accept pictures. The separate Qwen2.5-VL adapter converts compatible checkpoints for CPU text-and-image inference. Dense Qwen text bundles explain that an image cannot be used. See [model input capabilities](docs/MODEL-MODALITIES.md).

For short console programs, start with [Language models in a few Pascal calls](examples/language-models/README.md): load, configure, generate, stream, reuse, attach an image, and unload.

## Projects

| Project | What it provides |
| --- | --- |
| CrossPascal | Pascal algorithms, image adapters, and runnable examples |
| [CrossPascal Converter](https://github.com/pisarev/crosspascal-convert) | Model acquisition, conversion, and a local browser interface |
| [CrossPascal TVM](https://github.com/pisarev/crosspascal-tvm) | Native Pascal TVM and DLPack interfaces, model helpers, and runtime setup |
| [CrossPascal OpenCV](https://github.com/pisarev/crosspascal-opencv) | Pascal bindings, a native bridge, image processing, and video I/O |
| [CrossPascal Leptonica](https://github.com/pisarev/crosspascal-leptonica) | Pascal bindings and helpers for scans and document images |

See [capabilities](docs/CAPABILITIES.md), [known limitations](docs/KNOWN-LIMITATIONS.md), and the [roadmap](docs/ROADMAP.md).

## License

Original CrossPascal code and documentation use the [MIT license](LICENSE). Third-party code, tools, and model files retain their own terms. See [license scope](docs/LICENSE-SCOPE.md).
