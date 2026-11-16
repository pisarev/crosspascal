# OmDet-Turbo in Pascal

Find objects by describing the classes you want. Enter up to 16 class names, one per line, then choose **Detect objects**. The example displays boxes, labels, and confidence scores beside the original photo. You can change the classes and run the same image again.

## Prepare and run

1. Download the OmDet-Turbo preparation kit from the [CrossPascal releases](https://github.com/pisarev/crosspascal/releases).
2. Extract the ZIP and run `Prepare.cmd`. It downloads the SDK, runtime, model, and sample image, then writes the example settings.
3. Open `crosspascal/examples/omdet-turbo/OmDetTurbo.dproj` in Delphi 13.2 or `OmDetTurbo.lpi` in Lazarus 4.8. Build for Windows x64 and run. The prepared example also includes a Lazarus executable in `bin/lazarus-win64`.
4. Choose **Detect objects** to process the sample. Choose **Open image** for another PNG, JPEG, BMP, TIFF, or WebP image, up to 4096 pixels per side.

Both devices need a Windows x64 computer with AVX2 and FMA. The CUDA bundles cover `sm_75`, `sm_86`, `sm_89`, and `sm_120`. CUDA execution needs a driver that supports CUDA 12.8 and at least 2 GiB of free GPU memory. Prepare reads the installed device's compute capability and selects its bundle. Each model's memory requirement still applies.

The dedicated CPU and GPU kits already select their device. From the combined kit's `omdetturbo` folder or the source example, use `Prepare.cmd -Device CPU` to select CPU or `Prepare.cmd -Device CUDA` to require CUDA. With no device argument, `Auto` selects a matching CUDA bundle or uses CPU.

## Describe the objects

The initial classes are `person`, `helmet`, `flag`, and `space shuttle`. The supplied NASA photograph shows astronaut Eileen Collins. Replace the classes with the objects you want to find in your own image. OmDet evaluates the supplied text; these four classes are editable starting values.

Leave **Task** blank to build the task text from your class names. You can also enter a separate instruction. **Confidence** filters low scores. **NMS** controls removal of overlapping boxes within each class. Both thresholds range from 0 to 1.

Each class and the task use up to 77 CLIP tokens, including the start and end tokens. Select **Allow truncating text to 77 tokens** to shorten longer input. Saved reports record token counts and truncation. The tokenizer accepts Unicode text.

**Save result** writes an annotated PNG or a JSON report to a new filename. The report includes detections, thresholds, text, token counts, device information, and model and image hashes. Saved PNGs keep the original image dimensions.

**Stop** requests cancellation between native operations. Once the current operation returns, you can run another request. **Unload model** releases the loaded model and text cache.

## Model profile

The example uses [omlab/omdet-turbo-swin-tiny-hf](https://huggingface.co/omlab/omdet-turbo-swin-tiny-hf/tree/7fe93cecfb770c4d76cf71163956221249cab566) at revision `7fe93cecfb770c4d76cf71163956221249cab566`. It runs two native FP32 graphs: a CLIP text encoder and the trained Swin-Tiny detector. Learned class projection and CLIP tokenizer data accompany the graphs.

Images use RGB decoding, Pillow-compatible bilinear resizing to `640 x 640`, and the checkpoint's normalization. The fixed detector accepts 16 class slots, a 77-token task, and its attention mask. Requests can use fewer classes. Postprocessing discards inactive class slots before selecting the top 900 scores, applies sigmoid once, and performs class-aware NMS before clipping boxes to the image.

The Pascal units `TVM.OmDet`, `TVM.OmDetModel`, and `ClipTokenizer` provide preprocessing, model execution, tokenization, and postprocessing. The example keeps the model on a worker thread and caches recent text features. CPU and CUDA use the same text and image processing.

## Convert the source pack

Open `CrossPascalConvert.exe`, select **OmDet-Turbo text-guided detection | CPU** or **CUDA**, and select the supplied ONNX source folder. It contains `text.onnx`, `detector.onnx`, `class-projection.f32`, `vocab.json`, and `merges.txt`. Choose a new output folder.

The native converter compiles both graphs and writes a validated bundle. It checks the source files against this trained profile and refuses partial, altered, or single-graph input. CUDA conversion also needs NVRTC and an explicit target architecture. The GUI initially reads that target from the installed CUDA device; you can edit it to build for another architecture. See the [converter installation guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) for the native compiler tools.

This native conversion path starts from the supplied ONNX source pack.

## Recorded execution

The executable can save a result without opening its main window:

```text
OmDetTurbo.exe --recorded --bundle="model-folder" --runtime="runtime-folder" --opencv="crosscv.dll" --image="photo.jpg" --classes="person;cat" --report="result.json"
```

All paths can be absolute. Choose new JSON and PNG filenames. `--output` selects the PNG path; it defaults to the report path with a `.png` extension. `--classes-file` reads one class per line from a UTF-8 file. Other options are `--task`, `--confidence`, `--nms`, and `--truncate`.

A successful run writes `status: PASS` after the worker, model, and image runtime close, then exits with code 0. A failed run exits with code 1. The report's elapsed time covers the worker request, model loading, inference, and worker shutdown. It excludes reading the image and saving the PNG and JSON files.

## Licenses

The Pascal example uses the CrossPascal MIT license. OmDet and the checkpoint declare Apache-2.0 licensing. The CLIP tokenizer data carries the OpenAI CLIP MIT notice. Model and sample archives include their notices and credits.
