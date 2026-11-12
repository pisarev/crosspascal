# CPU and CUDA vision models

## Prepare and Run

[Choose a model and its separate CPU or GPU starter](../../docs/VISION-DOWNLOADS.md). Each ZIP contains one enclosing folder; open it and run `Prepare.cmd`. Only the selected model is downloaded. The complete five-model starter below remains optional.

Download [Prepare-VisionModels-ea019.zip](https://github.com/pisarev/crosspascal/releases/download/early-access-019/Prepare-VisionModels-ea019.zip), extract it, and double-click **Prepare.cmd**. It downloads the matched dependencies and sample data, then opens the prepared project folder. Open the **.dproj** in Delphi 13.2 or the **.lpi** in Lazarus 4.8, and press **Run**. See the [complete preparation guide](https://github.com/pisarev/crosspascal/blob/main/docs/PREPARE-EXAMPLES.md) for public downloads and optional GitHub request-limit recovery, model sizes and the other examples.


Open `VisionModels.dproj` in Delphi or `VisionModels.lpi` in Lazarus to build a small image-classification and object-detection application for Windows x64. The form lets you select a model profile, choose a converted bundle, open a picture, run on CPU or CUDA, and save a JSON result. It uses the supplied Pascal TVM adapters and OpenCV image types.

The source project has five explicit profiles. Model weights and compiled model libraries are external inputs. A profile name or a completed build does not establish model quality, successful inference, or release acceptance.

| Profile | Task | Required input | Output shown |
|---|---|---|---|
| SqueezeNet 1.1 | Classification | float32 RGB, 224 × 224 | Five class IDs and original scores |
| ResNet50 | Classification | float32 RGB, 224 × 224 | Five class IDs and original scores |
| YOLO11n classification | Classification | float32 RGB, 224 × 224 | Five class IDs and original scores |
| YOLO11n detection | Object detection | float32 RGB, 640 × 640 | Class IDs, scores and boxes |
| RT-DETR R18vd | Object detection | float32 RGB, 640 × 640 | Class IDs, scores and boxes |

## Download the coordinated Windows SDK and source models

This manual example uses `C:\CrossPascal` as the installation directory. Choose another writable local folder if needed and substitute it throughout. First install the compiler/runtime prerequisites described in the [converter installation guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md); the SDK includes the native TVM compiler.

1. In your browser, open [CrossPascal Releases](https://github.com/pisarev/crosspascal/releases). The source repositories and releases are public; no GitHub sign-in is required for downloads.
2. Download the Windows x64 SDK and its matching CPU model source asset listed in the release notes.
3. In Explorer, right-click the Windows SDK ZIP and choose **Extract All**. Use the directory containing `CrossPascalConvert.exe`, `runtime`, and the five sibling project folders as `C:\CrossPascal`. Keep the complete directory together.
4. Create `C:\CrossPascal\Sources` and extract the complete source-model ZIP there. Its `crosspascal-cpu-model-sources` folder contains:

| Profile | Subfolder | Source ONNX file |
| --- | --- | --- |
| SqueezeNet 1.1 | `squeezenet` | `squeezenet1.1-7.onnx` |
| ResNet50 v1 | `resnet50` | `resnet50-v1-12.onnx` |
| YOLO11n classification | `yolo11n-cls` | `yolo11n-cls.onnx` |
| YOLO11n detection | `yolo11n` | `yolo11n.onnx` |
| RT-DETR R18vd | `rtdetr-r18vd` | `rtdetr-r18vd.onnx` |

Each model folder must retain its adjacent `SOURCE.json`, licence and accompanying records. The ONNX files are the inputs for the converter. Generated model DLLs are created in a separate output folder.

## Convert one source model

Open `CrossPascalConvert.exe` from the SDK. Choose the model profile and
select its source file. SqueezeNet and ResNet50 accept ONNX, YOLO11n accepts
the pinned Ultralytics `.pt` or matching ONNX, and RT-DETR accepts its pinned
Safetensors or matching ONNX. Choose a new output directory, review **Preview**,
then click **Build**. Open the resulting bundle in VisionModels.

## Open and build

Keep these three repository folders together:

```text
crosspascal/
crosspascal-opencv/
crosspascal-tvm/
```

1. In Delphi 13.2, choose **File > Open Project** and open `C:\CrossPascal\crosspascal\examples\vision-models\VisionModels.dproj`.
2. Select **Release** and **Windows 64-bit** in Project Manager.
3. Open **Project > Options > Delphi Compiler**. The project already defines `TVM_LAZY_INIT` and contains the relative unit search paths listed below. Keep this define so the application can check and load the selected runtime explicitly.
4. Choose **Project > Build VisionModels**. The executable goes to `bin/Win64/Release`; generated DCU files go to `build/Win64/Release`.
5. Choose **Run > Run Without Debugging**, or open `C:\CrossPascal\crosspascal\examples\vision-models\bin\Win64\Release\VisionModels.exe` in Explorer.

In Lazarus 4.8, open `VisionModels.lpi` and build for Windows x64 with FPC 3.2.2. Run it in Lazarus or open `bin/lazarus-win64/VisionModels.exe`.

The configured unit search paths, relative to the project folder, are:

- `../../rtl-algorithms/src`
- `../../../crosspascal-tvm/pascal`
- `../../../crosspascal-opencv/pascal`

The example builds its form in code using VCL or LCL. Build `crosspascal-opencv/bin/crosscv.dll` before running it. Follow the [Windows setup guide](../../docs/WINDOWS-EARLY-ACCESS.md). The example checks the OpenCV ABI before opening images.

## Select a bundle and an image

Choose the matching profile, for example **ResNet50 v1 (ONNX Model Zoo)**. Browse to `C:\CrossPascal\Models\resnet50-cpu` or paste that path. Select the directory containing the completed bundle:

- `manifest.json`, with the source-model SHA-256, library SHA-256, task, adapter, input name, shape and dtype;
- the Windows x64 model DLL named by the manifest;
- its `.dll.inputs` sidecar.

Keep the accompanying runtime, recipe/report, and `model-source` metadata/licence directory with the bundle. The consumer validates the actual generated DLL against its own manifest; it does not require a fixed old DLL hash or a particular output-folder name.

The input shape must be `[1,3,224,224]` for classifiers or `[1,3,640,640]` for detectors. The bundle must declare CPU or CUDA, float32, batch one, the `main` entry, and the converter's shared-library format `so`. The consumer checks the selected profile against this metadata and checks the actual library bytes before loading it.

The TVM runtime field defaults to `crosspascal-tvm/runtime/windows-x64-cuda`. The example loads the pinned TVM libraries from that folder. The selected bundle determines CPU or CUDA execution; CUDA also requires a matching compute target and NVIDIA driver.

Click **Open image**, select a photograph, then click **Run inference**. The
bundle determines whether TVM runs on CPU or CUDA. The result shows the selected
device and, for CUDA, the GPU name and compute target. Run
`Prepare.cmd -Device CPU` or `Prepare.cmd -Device CUDA` to prepare a specific
variant. You can also select a compatible bundle with **Browse**.

The application hashes the bytes it decodes. If the file changes before
inference, open it again. Input images are limited to 64 MiB and 40 megapixels.
The model DLL must be at most 512 MiB, and at least 1 GiB of free system memory
must be available before it is loaded.

The form stays responsive while its worker runs. Wait for the worker to finish before closing. Each run releases its model and input tensors. **Save result** creates a new JSON file and refuses to replace an existing file. Recorded results include the input, model, manifest, profile-catalog and runtime hashes. They describe the completed inference; they do not mark the release accepted.

## Preprocessing and interpretation

The current Pascal adapters resize the image directly to the model's square input. They use area interpolation if either dimension shrinks, and cubic interpolation otherwise, then convert BGR to RGB and divide by 255. Classification also applies the mean and standard deviation declared in `models.json`; detector profiles do not apply additional normalization.

The source packs declare this direct-square preprocessing explicitly. ResNet50 v1 and SqueezeNet apply the recorded ImageNet mean/std; YOLO11 classification uses empty mean/std. Direct resize does not establish equivalence to an upstream crop or letterbox evaluation recipe, so upstream benchmark accuracy is not assigned to this route.

Classification scores are returned without an added softmax. Their meaning depends on the source model: a model may already include a final activation. The application therefore shows the original values and zero-based class IDs, and does not guess class names or call every score a probability.

YOLO detection uses the profile's score threshold and class-aware NMS. RT-DETR uses its existing decoder and score threshold; it does not add YOLO-style NMS. Box overlays are drawn only on the display bitmap, so they do not change the image supplied to the model.

## Model identity and source terms

`models.json` pins the exact ONNX source admitted by each profile. These are source identities for the conversion/consumer route, not a requirement that separately generated model DLLs have identical bytes.

| Profile | Source ONNX SHA-256 |
| --- | --- |
| SqueezeNet 1.1 | `1eeff551a67ae8d565ca33b572fc4b66e3ef357b0eb2863bb9ff47a918cc4088` |
| ResNet50 v1 | `3f03fdef724b22947eed826f1eef1dc5c34151bb4c37d634f1db89dfa2dd1526` |
| YOLO11n classification | `218f8ef1d4005d1bab740a805dbf994b1dfddb83fd54880245f0a0db17aa1844` |
| YOLO11n detection | `7951f527c60cee719f9b40bb71071a3f08dc1214061dcd13639d4e4920b8d2b0` |
| RT-DETR R18vd | `4750cf32e9e7e3ef5d8dea600377246ce4c408dec5f418d103d41c39edc01c17` |

**SqueezeNet:** the unchanged profile selects trained [ONNX Model Zoo SqueezeNet 1.1](https://huggingface.co/onnxmodelzoo/squeezenet1.1-7/tree/61e525224ad479521059f4586bcacf50ad3627ca), declared Apache-2.0. The actual input is `data [1,3,224,224]`; output is `squeezenet0_flatten0_reshape0 [1,1000]`. Its graph contains no Softmax. The old ONNX light test fixture remains excluded.

**ResNet50:** the new source is the original trained [ONNX Model Zoo ResNet50 v1, opset 12](https://huggingface.co/onnxmodelzoo/resnet50-v1-12/tree/1f95315d8bd3b3ca2ceabe54d274e0cdf5a83bbe), declared Apache-2.0. Its symbolic batch N is bound to 1 for conversion without changing the source bytes. The actual input is `data`; output is `resnetv17_dense0_fwd [1,1000]`. This route uses the v1 Model Zoo file and makes no TorchVision V2 checkpoint or benchmark claim.

**YOLO11:** the new classification export uses the official [v8.3.0 yolo11n-cls.pt asset](https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n-cls.pt), checkpoint SHA-256 `c62d41bf9625777760018bf914d2e6cd472420ccd01706d97a61cb6c82502bd7`. Detection uses [Ultralytics/YOLO11 revision 5599de6f3b0ef95f98f37530ed0f3bf149c10b37](https://huggingface.co/Ultralytics/YOLO11/tree/5599de6f3b0ef95f98f37530ed0f3bf149c10b37), checkpoint SHA-256 `0ebbc80d4a7680d14987a577cd21342b65ecfd94632bd9a8da63ae6417644ee1`. Both were prospectively exported with Ultralytics 8.4.146, CPU FP32, batch 1, opset 17 and no simplifier. Detection retains the raw dense `[1,84,8400]` head without exported NMS. The retained upstream declaration is AGPL-3.0; preserve the model licence and accompanying exporter source. The own export helper's MIT licence does not replace upstream model or exporter terms.

**RT-DETR:** the new source is [PekingU/rtdetr_r18vd revision ac77a11ff0170a41b771c03264987f8ce2b0d753](https://huggingface.co/PekingU/rtdetr_r18vd/tree/ac77a11ff0170a41b771c03264987f8ce2b0d753), declared Apache-2.0. Its `model.safetensors` SHA-256 is `fe87a5a30f5daf298d10794c7682a63b6107986f97d6a770ba948d89e4340093`. The recorded Transformers 4.45.2 CPU FP32 export uses the pinned local config and produces `logits [1,300,80]` plus normalized `pred_boxes [1,300,4]`. The checkpoint is the named rtdetr_r18vd source; no COCO/O365 variant is substituted.

Each source pack retains the exact public origin, file pins and applicable licence/export records in SOURCE.json and its declared ancillary files. The converter carries those into `model-source/` in the generated bundle and optional download ZIP. A licence field records the source declaration; read the accompanying terms for redistribution. The local recipe path, public model origin, numeric diagnostics and application result are separate records.

The YOLO11n detection pack uses the fixed-slice ONNX at the top level. It preserves the original traced ONNX and a reproducible transformation under its reproduction directory. The revised ONNX produced byte-identical results to the original ONNX on the retained input. The resulting CPU DLL passed the same-image Delphi detector contract in the example's recorded mode. Use the steps above to run the model in either IDE.

The source project adds no OCR, segmentation, OmDet or GPU-vision acceptance claim. Those routes have their own scope and evidence.

In the unpacked SDK, the converter guide is `crosspascal-convert/INSTALL.md`.
