# BiRefNet in Pascal

Open a photo and choose **Remove background**. The example displays the original beside a transparent preview or a grayscale mask. **Save result** saves a PNG at the original image size or a JSON report with the model and input hashes.

## Prepare and run

1. Download the BiRefNet CPU or NVIDIA GPU preparation kit from the [EA021 release](https://github.com/pisarev/crosspascal/releases/tag/early-access-021).
2. Extract the ZIP and run `Prepare.cmd`. It downloads the SDK, TVM runtime, model, and sample image, then writes their paths into the example settings.
3. Open `BiRefNet.dproj` in Delphi 13.2 or `BiRefNet.lpi` in Lazarus 4.8. Build for Windows x64 and run. The installed example also includes a Lazarus-built executable in `bin/lazarus-win64`.
4. Choose **Remove background** to try the prepared image. Choose **Open image** for another PNG, JPEG, BMP, TIFF, or WebP image, up to 4096 pixels per side.

The CPU model requires AVX2 and FMA. The GPU bundle targets NVIDIA `sm_89` and requires at least 4 GiB of free GPU memory. The loader checks both before inference. Choose the model and runtime for the same device. CPU inference works without CUDA.

**Stop** waits for the current native operation to return. On the CPU, a full inference can take a minute or more. After stopping, you can start again or open another image. When closing during inference, wait for the operation to finish, then close the window again.

The checkerboard appears in the preview. The saved cutout has a real alpha channel and preserves the original RGB pixels. Choose a new output filename; the example refuses to overwrite an existing file.

## Model and image processing

The profile uses the full SwinL [BiRefNet_HR checkpoint](https://huggingface.co/ZhengPeng7/BiRefNet_HR/tree/a7a562f6fd16021180f2f4348f4de003a2d3d1e1). It resizes the image to `800 x 800` RGB pixels using Pillow-compatible bicubic interpolation, then applies ImageNet normalization. The native model returns FP32 mask logits. One sigmoid and bilinear probability resizing produce the mask at the original image dimensions.

This fixed HR800 profile differs from the upstream 2048-pixel workflow. Its output does not establish the upstream benchmark scores. Inspect fine hair, transparent objects, and low-contrast edges before using a cutout.

To convert the supplied ONNX source pack, open `CrossPascalConvert.exe`, select **BiRefNet HR800 background removal | CPU** or **CUDA**, and choose the ONNX file. Select a new output folder. CUDA conversion also needs the matching native compiler tools and a target architecture. See the [converter installation guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md).

## Recorded execution

The executable can also save a result without opening the window:

```text
BiRefNet.exe --recorded --bundle="model-folder" --runtime="runtime-folder" --opencv="crosscv.dll" --image="photo.png" --report="result.json"
```

All paths can be absolute. Choose a new report filename. The default outputs are `result.cutout.png` and `result.mask.png`; `--cutout` and `--mask` can set separate new PNG filenames. A successful run writes `status: PASS` after releasing the model and image resources, then exits with code 0. A failed run exits with code 1 and writes a failure report when possible. The report's elapsed time covers model loading, preprocessing, inference, postprocessing, and model release. It excludes reading the image and saving the output files.

## Licenses

The Pascal example uses the CrossPascal MIT license. The BiRefNet project and this checkpoint declare MIT licensing. The release includes the upstream notices and sample-image credits.
