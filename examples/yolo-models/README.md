# YoloModels

YoloModels runs 115 YOLO profiles from Object Pascal across seven tasks. Choose one model size or the complete set, open an image, choose a model and device, view the result, and save it. The example is part of the EA025 Windows x64 SDK and builds in Delphi and Lazarus.

The CPU must support AVX2 and FMA, for both CPU and CUDA bundles. CUDA bundles are compiled for `sm_75`, `sm_86`, `sm_89`, and `sm_120` and require a compatible NVIDIA driver.

## Profiles

| Task | Families | Input |
| --- | --- | --- |
| Classification | YOLOv5, YOLOv8, YOLO11, YOLO26 | 224 x 224 |
| Object detection | YOLOv5, YOLOv8, YOLOv10, YOLO11, YOLO12, YOLOv13, YOLO26 | 640 x 640 |
| Instance segmentation | YOLOv5, YOLOv8, YOLO11, YOLO26 | 640 x 640 |
| Pose | YOLOv8, YOLO11, YOLO26 | 640 x 640 |
| Oriented detection | YOLOv8, YOLO11, YOLO26 | 640 x 640 |
| Semantic segmentation | YOLO26 | 640 x 640 |
| Depth estimation | YOLO26 | 640 x 640 |

Each family and task comes in several model sizes. Prepare installs one size group:

| Size group | Profiles | Contents |
| --- | ---: | --- |
| `n` (default) | 23 | Every family and task in the table above |
| `s` | 23 | Every family and task |
| `m` | 22 | Every family and task except YOLOv13 |
| `b` | 1 | YOLOv10 object detection |
| `l` | 23 | Every family and task |
| `x` | 23 | Every family and task |
| `all` | 115 | All of the groups above |

**Model / task** shows the exact profile names. The profile catalogs and the converter contain the complete list.

## Prepare

Extract the SDK into a writable directory such as `C:\CrossPascal`, then run Prepare from that directory.

Prepare the models before opening the example. Run `crosspascal/prepare/vision/yolo-models/Prepare.cmd` for Auto, `Prepare-CPU.cmd` for CPU, or `Prepare-GPU.cmd` for CUDA. These scripts and the combined preparation ZIP prepare the default `n` group. CUDA preparation also keeps the matching CPU files. A profile that is not installed reports a missing file.

To prepare another size group, choose the size next to the YoloModels CPU, GPU, or Auto kit on the download page, extract that kit, and run its `Prepare.cmd`. The kit selects the size group, so you do not need to edit any files.

By default, the scripts above and the combined preparation ZIP install the SDK and models in `%LOCALAPPDATA%\CrossPascal\early-access-025\crosspascal-windows-x64`. Each size kit, including `n` and `all`, installs in its own folder: `%LOCALAPPDATA%\CrossPascal\early-access-025-yolo-<size>\crosspascal-windows-x64`. With the default locations, all kits share one downloads folder. When Prepare finishes, the lines following `READY` give the full Delphi and Lazarus project paths. Use that prepared SDK directory for the paths below, including when you chose a different installation location.

See [Prepare and run](../../docs/PREPARE-EXAMPLES.md) for the general steps and the [Windows setup guide](../../docs/WINDOWS-EARLY-ACCESS.md) for dependencies. Model archives for CPU and for each CUDA target are provided separately from the SDK. A larger size group can be split into several ZIP parts. The `all` kit uses the archives of the other six groups rather than separate copies of the weights.

| Location | Contents |
| --- | --- |
| `index.json`, `profiles.json` | Bundle index and profile catalog for the `n` group |
| `index-<size>.json`, `profiles-<size>.json` | Bundle index and profile catalog for `s`, `m`, `b`, `l`, `x`, or `all` |
| `models/<profile>-cpu`, `models/<profile>-sm_XX` | Model bundles for the prepared size group and device |
| Paths in each profile's `graph_recipe.file` | Weight-free ONNX graph recipes for all 115 profiles |
| `runtime/yolo` | TVM FFI and runtime core |
| `runtime/gemma-native/crosscv.dll` | Image runtime |
| `CrossPascalConvert.exe` | Native desktop converter |

A size kit records its group in `yolo-kit.txt` in the prepared SDK directory. The common SDK does not include this file, so the example uses `n`. The example rejects an unknown size group.

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
| `--prepared=<directory>` | Prepared SDK directory containing the index files |
| `--image=<file>` | Image to open at startup |

```powershell
Set-Location "$env:LOCALAPPDATA\CrossPascal\early-access-025\crosspascal-windows-x64"
.\crosspascal\examples\yolo-models\bin\lazarus-win64\YoloModels.exe "--prepared=$PWD" --image=C:\Images\photo.jpg
```

For a size kit, use the SDK directory printed after `READY`.

Without `--prepared`, the example looks for `index.json` in its own directory and up to six parent directories, then asks you to select the file.

## Build

Use Delphi 13.2 or Lazarus 4.8 with FPC 3.2.2 and build for Windows x64. Keep the SDK repository folders together.

- **Delphi:** open `crosspascal/examples/yolo-models/YoloModels.dproj`. The project supplies the required defines, so open it instead of the `.dpr`. The Release output is `bin/Win64/Release/YoloModels.exe` in the example directory.
- **Lazarus:** open `crosspascal/examples/yolo-models/YoloModels.lpi`. The output is `bin/lazarus-win64/YoloModels.exe` in the example directory.

The prepared index pins used by `YoloModels.Defaults.pas` are supplied in
`docs/yolo/PREPARED-INDEX-PINS.json`. From the `crosspascal` source repository,
regenerate the unit with:

```powershell
python tools/generate_yolo_defaults.py docs/yolo/PREPARED-INDEX-PINS.json examples/yolo-models/YoloModels.Defaults.pas
```

Rebuild the example and desktop converter after changing the prepared indexes.

## Convert a checkpoint

To build a bundle from an original `.pt` checkpoint and its pinned, weight-free ONNX recipe, follow [Native YOLO conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/YOLO-NATIVE.md). The desktop converter offers all 115 profiles, whichever size group is prepared. For the command-line converter, select the profile from the complete `profiles-all.json` catalog.

## Sources and licenses

[MODEL-PROVENANCE.json](../../docs/yolo/MODEL-PROVENANCE.json) records the source and recipe hashes, code revisions, and license file for each profile. The upstream license files are in [model-sources](../../docs/yolo/model-sources). Model and upstream source terms remain in those documents. The CrossPascal [MIT license](../../LICENSE) covers original CrossPascal code and documentation and does not replace them.
