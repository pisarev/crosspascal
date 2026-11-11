# CrossPascal on Windows x64

For a first run, use the [Prepare.cmd quickstart](PREPARE-EXAMPLES.md). The manual setup below remains available for conversion and rebuilding native dependencies.

Use the coordinated Windows SDK, the companion OpenCV and Leptonica source assets, and the model source assets listed in the release notes. Keep the five repository folders beside one another in a writable directory such as `C:\CrossPascal`. The compiler targets for this early-access release are Delphi 13.2 and Lazarus 4.8 with FPC 3.2.2. Support for earlier compiler versions is planned for subsequent updates.

## Install the dependencies you need

- **RTL algorithms.** Open the Geometry or DisjointSet example in your Pascal IDE. These examples need no external runtime.
- **OpenCV and Leptonica.** Extract the companion native source assets, start a Linux Docker engine, and run the command below with the actual extracted paths. The script checks the source inventories and the build inputs and installs the libraries into the appropriate SDK directories. Pass only the source path for the component you use when setting up an independent component.
- **TVM.** The SDK includes the native runtime and compiler. Keep its library folders together. Install the Windows x64 C++ linker and SDK libraries for model conversion. CUDA conversion also uses NVIDIA NVRTC. See the [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md).

To rebuild the image libraries from their source assets, run this command from the extracted SDK:

```powershell
& .\crosspascal\scripts\install-native-win64.ps1 `
    -OpenCVSource C:\CrossPascalInputs\opencv-windows-x64 `
    -LeptonicaSource C:\CrossPascalInputs\leptonica-windows-x64
```

The rebuild uses a Linux Docker engine. For Docker inside WSL, add `-WslDistribution` followed by the distribution name.

## Open the examples

Open the `.dproj` in Delphi and select Windows 64-bit. Open the corresponding `.lpi` in Lazarus and build with the Windows x64 FPC compiler. Keep the examples inside their extracted folders so their relative unit and data paths resolve.

| Example | First result |
| --- | --- |
| `crosspascal/rtl-algorithms/tests/TestGeometry` | Geometry checks with a zero failure count |
| `crosspascal/rtl-algorithms/tests/TestDisjointSet` | Disjoint-set checks with a zero failure count |
| `crosspascal-opencv/examples/CrossCVHello` | Image pixel sum of 84 and 12 nonzero pixels |
| `crosspascal-opencv/examples/LoadResizeSave` | A 640 × 480 PNG saved from the chosen photograph |
| `crosspascal-leptonica/examples/LeptonicaHello` | A 256 × 96 grayscale gradient PNG |
| `crosspascal/examples/marker-lite/MarkerLite` | Grayscale, Sauvola, or Canny processing with PNG output |
| `crosspascal/examples/vision-models/VisionModels` | A CPU classifier's top five classes or a detector's boxes |
| `crosspascal/examples/qwen-chat/QwenChat` | A streamed answer from a dense Qwen CUDA or Qwen2.5-VL CPU bundle; compatible vision bundles accept an attached picture |
| `crosspascal/examples/gemma-chat/GemmaChat` | A streamed answer from a converted Gemma CPU or CUDA bundle; compatible Gemma 3n vision bundles accept an attached picture |

For the two model applications, open `CrossPascalConvert.exe` at the SDK root. Choose the profile and its pinned source in the converter, convert it, and select the generated bundle in the application. The CPU profiles cover SqueezeNet 1.1, ResNet50, YOLO11n classification, YOLO11n detection, and RT-DETR R18vd. Both Qwen2.5-Instruct profiles (0.5B and 1.5B) use the CUDA architecture detected by the converter or explicitly entered for the destination machine.

Read the per-profile and component limitations in the release notes. Keep the original upstream notices with the corresponding dependencies and source assets.

The SDK supplies the native libraries for language inference. Gemma 3n image conversion uses the original GGUF and its matching projector. Qwen2.5-VL uses its supported Safetensors checkpoint. See the [model input matrix](MODEL-MODALITIES.md).
