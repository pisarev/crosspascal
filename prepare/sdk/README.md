# CrossPascal Windows x64 SDK

Use the [example preparation guide](../../docs/PREPARE-EXAMPLES.md)
to install a ready model and its example. The SDK, native converter, and
model inference run without Python.

Run **CrossPascalConvert.exe**, choose a profile, enter the original model
and a new output folder, then choose **Preview** or **Build**. Conversion
uses the bundled native TVM compiler, the MSVC x64 linker, and Windows SDK
libraries. CUDA conversion also uses CUDA Toolkit 12.8 with NVRTC. Ready
CUDA inference uses the NVIDIA driver and supplied runtime components.
The ready SDK includes the Windows UTF-8 path fix in its TVM FFI 0.1.14
library; source and runtime pins are in
[`native/windows-runtime`](../../../crosspascal-tvm/native/windows-runtime/README.md)
and the runtime provenance file. The separate Python-based
`crosspascal-tvm/scripts/install_tvm_windows.py` installs the official FFI
wheel and the matching SDK core for a manual source setup; Prepare does not
use that script.

| Profile | Source |
| --- | --- |
| Gemma 3n E4B CPU or CUDA | Original GGUF; image input also uses the matching projector GGUF |
| Huihui Gemma 3n E4B abliterated text CPU or CUDA | Pinned community Q8_0 GGUF |
| Qwen 3.5/3.8 dense GGUF CPU or CUDA | Original mixed-format GGUF and source identity |
| Qwen 3.5/3.8 original BF16 CUDA | Original Safetensors directory and source identity |
| Gemma 2 CPU or CUDA | Safetensors directory with configuration and tokenizer |
| Dense Qwen2.5 CUDA | Safetensors directory with configuration and tokenizer |
| Qwen2.5-VL 3B CPU or CUDA | Supported pinned original Safetensors snapshot |
| YOLO11n detection or classification CPU or CUDA | Pinned Ultralytics `.pt` or matching ONNX source pack |
| RT-DETR R18vd CPU or CUDA | Pinned PekingU Safetensors or matching ONNX source pack |
| SqueezeNet 1.1 and ResNet50 v1 CPU or CUDA | Original ONNX |
| PP-OCRv5 Server detection or recognition CPU or CUDA | Pinned ONNX from the EA020 source packs; keep `ppocrv5_dict.txt` beside recognizer ONNX |
| BiRefNet HR800 CPU or CUDA | Pinned full SwinL ONNX from the EA021 source pack |
| OmDet-Turbo CPU or CUDA | Supplied five-file folder: text and detector ONNX, learned class projection, vocabulary, and merges |

The [Huihui Gemma guide](https://github.com/pisarev/crosspascal-convert/blob/main/docs/HUIHUI-GEMMA3N.md) covers
the community text profiles. The [Qwen3.8 guide](https://github.com/pisarev/crosspascal-convert/blob/main/docs/QWEN35.md)
covers Q4 CPU/CUDA and original BF16 CUDA with weight streaming. Their
ready bundles use a 1,024-token context, including the chat template,
prompt, and answer.

Select the resulting bundle in the corresponding Pascal example. Prepared
examples include a Lazarus-built Windows x64 executable and projects for
Delphi and Lazarus. Keep the sibling repository directories together when
building. **Load model** opens the selected bundle, **Generate** starts an
answer, **Stop** cancels generation, and **Unload** releases the model.

Ready CUDA bundles contain code for `sm_75`, `sm_86`, `sm_89`, and `sm_120`.
The launcher reads the installed device for the initial conversion target;
you can edit it to compile for another computer. Prepare checks the device
and available memory before selecting CUDA.

[BiRefNet](../../examples/birefnet/README.md) saves an original-size
mask and transparent cutout from its full SwinL HR800 model. Its CUDA bundle
uses at least 4 GiB of free GPU memory.
[OmDet-Turbo](../../examples/omdet-turbo/README.md) detects objects
from editable class names and saves an annotated PNG or JSON. Its CUDA
bundle uses at least 2 GiB of free GPU memory. These CPU profiles use AVX2
and FMA.

Use ASCII paths for conversion sources, outputs, and compiler tools. The
launcher finds the TVM compiler in `runtime/converter/compiler` and uses
the installed MSVC linker and Windows SDK by default. For custom locations,
create `runtime/converter/toolchain.ini` with a `[toolchain]` section and
the needed `COMPILER`, `LINKER`, `FFI_LIB`, `MSVC_LIB`, `UCRT_LIB`,
`WINDOWS_LIB`, or `NVRTC` keys. Paths can be absolute or relative to
`runtime/converter`.

Model and tooling licenses remain with the corresponding source and
runtime files. `SOURCE-REVISIONS.json` pins the repository commits; each
component's `SOURCE-INDEX.json` describes its shipped source files before
preparation, local builds, or edits. `SDK-FILES.json` lists the complete SDK
payload, including native libraries and ready applications.
