# CrossPascal on Windows x64

For a first run, use the [Prepare.cmd quickstart](PREPARE-EXAMPLES.md). The manual setup below remains available for conversion and rebuilding native dependencies.

Use the coordinated Windows SDK, the companion OpenCV and Leptonica source assets, and the model source assets listed in the release notes. Keep the five repository folders beside one another in a writable directory such as `C:\CrossPascal`. The compiler targets for this early-access release are Delphi 13.2 and Lazarus 4.8 with FPC 3.2.2. Support for earlier compiler versions is planned for subsequent updates.

## Install the dependencies you need

- **RTL algorithms.** Open the Geometry or DisjointSet example in your Pascal IDE. These examples need no external runtime.
- **OpenCV and Leptonica.** Extract the companion native source assets, start a Linux Docker engine, and run the command below with the actual extracted paths. The script checks the source inventories and the build inputs and installs the libraries into the appropriate SDK directories. Pass only the source path for the component you use when setting up an independent component.
- **Converter and native TVM.** Use the SDK's portable Python. Run the TVM setup command below to fetch the pinned Apache TVM, TVM FFI, and Python dependencies from PyPI. The installer checks each wheel and the four runtime DLLs. To use the same cached wheels again, add `--offline`.

Run these commands from the root of the extracted SDK:

```powershell
& .\crosspascal\scripts\install-native-win64.ps1 `
    -OpenCVSource C:\CrossPascalInputs\opencv-windows-x64 `
    -LeptonicaSource C:\CrossPascalInputs\leptonica-windows-x64

& .\runtime\python\python.exe -B .\crosspascal-tvm\scripts\install_tvm_windows.py `
    --cache .\dependency-cache `
    --destination .\crosspascal-tvm\runtime\windows-x64-cuda `
    --site-packages .\runtime\python\Lib\site-packages `
    --dependencies .\crosspascal-tvm\runtime\WINDOWS-PYTHON-WHEELS.json
```

The OpenCV and Leptonica DLLs are generated on your machine from the corresponding native sources. Windows model conversion also requires the Windows C++ libraries and the LLVM executables described in the [converter guide](../../crosspascal-convert/INSTALL.md). CUDA model conversion requires the NVIDIA driver and the CUDA Toolkit listed there.

The native installer uses the Windows Docker command on PATH by default. If Docker is installed directly inside an existing WSL distribution, add `-WslDistribution` followed by its name to the same command. The distribution must be able to access the Windows source and SDK directories.

## Prepare the TVM cache on a connected PC

If the SDK computer cannot reach PyPI, extract the same SDK on another Windows x64 computer with Internet access and run this command there:

```powershell
& .\runtime\python\python.exe -B .\crosspascal-tvm\scripts\install_tvm_windows.py `
    --cache .\dependency-cache `
    --dependencies .\crosspascal-tvm\runtime\WINDOWS-PYTHON-WHEELS.json `
    --download-only
```

Copy the resulting `dependency-cache` folder to the root of the SDK on the destination computer. Run the TVM setup command above with `--offline` appended. The installer checks the same file hashes in both modes.

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

For both language chat forms and the console language examples, extract the language runtime companion asset into the same SDK root. It supplies `runtime/gemma-python/python.exe` and its pinned execution dependencies. No separate Python installation or conversion tools are needed to run an already converted bundle. Follow the [GemmaChat manual steps](../examples/gemma-chat/README.md) or the [Qwen2.5-VL guide](../../crosspascal-convert/docs/QWEN2.5-VL.md). Converting an original checkpoint requires the additional exporter environment described in the converter guides. For CPU image conversion, select the appropriate Qwen2.5-VL section or add a matching vision projector to a Gemma 3n text bundle. The [modality matrix](MODEL-MODALITIES.md) lists the supported inputs.
