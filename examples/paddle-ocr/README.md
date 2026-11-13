# PaddleOCR in Pascal

Open a photo, choose **Read text**, then select **Save result** to keep the recognized text or a JSON file with the text regions and confidence scores. The example uses the PP-OCRv5 Server detector and recognizer locally through TVM and uses OpenCV to read and crop the image.

## Prepare and run

1. Download [Prepare PaddleOCR for CPU](https://github.com/pisarev/crosspascal/releases/download/early-access-020/Prepare-PaddleOCR-CPU-ea020-r7.zip) or [Prepare PaddleOCR for NVIDIA GPU](https://github.com/pisarev/crosspascal/releases/download/early-access-020/Prepare-PaddleOCR-GPU-ea020-r7.zip).
2. Extract the ZIP and run `Prepare.cmd` in the extracted folder. It installs the SDK, runtime, sample photo, detector and recognizer, then writes their paths into the example settings.
3. Open `PaddleOcr.dproj` in Delphi 13.2 or `PaddleOcr.lpi` in Lazarus 4.8 and build for Windows x64. A Lazarus-built executable is included in `bin/lazarus-win64` inside the installed example folder.
4. Choose **Read text** to try the prepared photo, or choose **Open image** to use a different one. **Stop** takes effect after the current native operation returns.

Use the CPU version on a system with AVX2 and FMA. The GPU version checks the NVIDIA driver, compute capability and available device memory. Use detector and recognizer bundles for the same device. See the [EA020 release](https://github.com/pisarev/crosspascal/releases/tag/early-access-020) for the separate model downloads.

## Model profiles

The detector centers the image on a black square and processes a `960 × 960` tensor. The recognizer reads perspective crops at height 48 and width up to 320, then decodes the output with the supplied dictionary. Wide lines can lose detail at this fixed width. The application accepts images up to 4096 pixels on each side.

The Windows x64 CPU and CUDA (`sm_89`) checks compare text, region coordinates and confidence scores against the original ONNX models on two photos. The example is intended for reading visible text. Document layout, table reconstruction and handwriting accuracy across arbitrary images have separate requirements.

To build a new bundle, select the corresponding PaddleOCR profile in `CrossPascalConvert.exe` and choose its pinned ONNX export. Keep `ppocrv5_dict.txt` beside the recognizer export. The converter copies the verified dictionary into the recognizer bundle. See the [converter installation guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) for toolchain setup.

## Licenses

The example uses the CrossPascal MIT license. PaddlePaddle publishes the [detector](https://huggingface.co/PaddlePaddle/PP-OCRv5_server_det) and [recognizer](https://huggingface.co/PaddlePaddle/PP-OCRv5_server_rec) under Apache-2.0. The polygon offset uses Clipper 6.4.2 under the Boost Software License. The corresponding notices and sources are included with the release assets.
