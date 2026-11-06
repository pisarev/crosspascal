# CrossPascal

CrossPascal gives Object Pascal applications image processing, geometry, and local model inference. The Windows x64 early access SDK brings together five repositories, a browser-based model converter, and Delphi and Lazarus examples.

## Get started

1. Open [CrossPascal Releases](https://github.com/pisarev/crosspascal/releases) and select the Windows x64 early access release. Download the SDK and the companion assets listed in its release notes. The GitHub source ZIP contains only the source of one repository.
2. Extract the SDK into a writable directory such as `C:\CrossPascal`. Keep the five repository folders together.
3. Follow the [Windows setup guide](docs/WINDOWS-EARLY-ACCESS.md) for the dependencies and example projects. Use Delphi 13.2 or Lazarus 4.8 with FPC 3.2.2 and build for Windows x64.

Try the Geometry and DisjointSet projects first if you want examples with no external runtime. To work with images, build the OpenCV or Leptonica library using the corresponding source asset, then open its example project.

## Run a model locally

Open `CrossPascalConvert.exe` to start the converter. Choose a pinned Qwen2.5-Instruct download or a compatible local Safetensors folder, such as Qwen2.5-Coder-0.5B-Instruct. Select the detected CUDA architecture or enter the target architecture, then build the bundle. Open QwenChat in your IDE and run a prompt. Auto uses the shared 2,048-token context, and **Stop** keeps the partial answer. The [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) walks through both IDEs.

For CPU vision, use the matching model source archive and the VisionModels example. The profiles cover SqueezeNet 1.1, ResNet50, YOLO11n classification, YOLO11n detection, and RT-DETR R18vd.

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
