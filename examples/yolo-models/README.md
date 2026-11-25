# YoloModels

YoloModels runs 23 YOLO profiles from Object Pascal. Open an image, choose a model and device, view the result, and save it. The example is part of the EA024 Windows x64 SDK and builds in Delphi and Lazarus.

The CPU must support AVX2 and FMA, for both CPU and CUDA bundles. CUDA bundles are compiled for `sm_75`, `sm_86`, `sm_89`, and `sm_120` and require a compatible NVIDIA driver.

## Profiles

| Task | Profiles | Input |
| --- | --- | --- |
| Classification | `yolov5n-cls`, `yolov8n-cls`, `yolo11n-cls`, `yolo26n-cls` | 224 x 224 |
| Object detection | `yolov5n`, `yolov8n`, `yolov10n`, `yolo11n`, `yolo12n`, `yolov13n`, `yolo26n` | 640 x 640 |
| Instance segmentation | `yolov5n-seg`, `yolov8n-seg`, `yolo11n-seg`, `yolo26n-seg` | 640 x 640 |
| Pose | `yolov8n-pose`, `yolo11n-pose`, `yolo26n-pose` | 640 x 640 |
| Oriented detection | `yolov8n-obb`, `yolo11n-obb`, `yolo26n-obb` | 640 x 640 |
| Semantic segmentation | `yolo26n-sem` | 640 x 640 |
| Depth estimation | `yolo26n-depth` | 640 x 640 |

## Prepare

Extract the SDK into a writable directory such as `C:\CrossPascal`, then run Prepare from that directory.

Prepare the models before opening the example. Run `crosspascal/prepare/vision/yolo-models/Prepare.cmd` for Auto, `Prepare-CPU.cmd` for CPU, or `Prepare-GPU.cmd` for CUDA. CUDA preparation keeps the CPU package as well. A profile that is not installed reports a missing file.

By default, Prepare installs the SDK and models in `%LOCALAPPDATA%\CrossPascal\early-access-024-r1\crosspascal-windows-x64`. When it finishes, the lines following `READY` give the full Delphi and Lazarus project paths. Use that prepared SDK directory for the paths below, including when you chose a different installation location.

See [Prepare and run](../../docs/PREPARE-EXAMPLES.md) for the general steps and the [Windows setup guide](../../docs/WINDOWS-EARLY-ACCESS.md) for dependencies. The five model archives, one for CPU and one for each CUDA target, are provided separately from the SDK.

| Location | Contents |
| --- | --- |
| `index.json`, `profiles.json` | Bundle index and profile catalog |
| `models/<profile>-cpu`, `models/<profile>-sm_XX` | Model bundles |
| `models/recipes` | ONNX graph recipes without weights |
| `runtime/yolo` | TVM FFI and runtime core |
| `runtime/gemma-native/crosscv.dll` | Image runtime |
| `CrossPascalConvert.exe` | Native desktop converter |

## Run

In the prepared SDK directory, open `crosspascal/examples/yolo-models/bin/lazarus-win64/YoloModels.exe`.

1. Click **Open image...** and choose a PNG, JPEG, BMP, or WebP image, up to 4096 pixels on either side.
2. Choose a profile in **Model / task**. Each entry shows the profile and its task.
3. Choose **CPU** or **NVIDIA CUDA** in **Device**. CUDA uses GPU 0 and the bundle for its compute capability.
4. Adjust the settings enabled for that task. Enter values from 0 to 1 with a decimal point.
5. Click **Run**.

| Setting | Used for |
| --- | --- |
| **Confidence** | Object detection, instance segmentation, pose, and oriented detection |
| **NMS IoU** | The same tasks, when the profile uses NMS |
| **Point visibility** | Pose |
| **Mask opacity** | Instance and semantic segmentation |

**Stop** requests cancellation. When the status reads "Stopped. You can run again.", start another run. **Unload** releases the loaded model.

## Results and export

**View** switches between **Result** and **Original**. **Labels** offers **Auto**, **All**, and **None**. The side panel lists classes and scores, pixel counts for semantic segmentation, or the estimated range in meters for depth. For object tasks, it lists the first 100 objects.

Click **Save results...** and enter a new folder name. The example saves images, maps, and `result.json`. The saved result includes every object. Existing results are never overwritten. Save before opening another image or changing the model or device, because these actions clear the current result.

## Command line

Both options are optional:

| Option | Value |
| --- | --- |
| `--prepared=<directory>` | Directory containing the prepared `index.json` |
| `--image=<file>` | Image to open at startup |

```powershell
Set-Location "$env:LOCALAPPDATA\CrossPascal\early-access-024-r1\crosspascal-windows-x64"
.\crosspascal\examples\yolo-models\bin\lazarus-win64\YoloModels.exe "--prepared=$PWD" --image=C:\Images\photo.jpg
```

Without `--prepared`, the example looks for `index.json` in its own directory and up to six parent directories, then asks you to select the file.

## Build

Use Delphi 13.2 or Lazarus 4.8 with FPC 3.2.2 and build for Windows x64. Keep the SDK repository folders together.

- **Delphi:** open `crosspascal/examples/yolo-models/YoloModels.dproj`. The project supplies the required defines, so open it instead of the `.dpr`. The Release output is `bin/Win64/Release/YoloModels.exe` in the example directory.
- **Lazarus:** open `crosspascal/examples/yolo-models/YoloModels.lpi`. The output is `bin/lazarus-win64/YoloModels.exe` in the example directory.

## Convert a checkpoint

To build a bundle from an original `.pt` checkpoint and its pinned, weight-free ONNX recipe, follow [Native YOLO conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/YOLO-NATIVE.md).

## Sources and licenses

[MODEL-PROVENANCE.json](../../docs/yolo/MODEL-PROVENANCE.json) records the source and recipe hashes, code revisions, and license file for each profile. The upstream license files are in [model-sources](../../docs/yolo/model-sources). Model and upstream source terms remain in those documents. The CrossPascal [MIT license](../../LICENSE) covers original CrossPascal code and documentation and does not replace them.
