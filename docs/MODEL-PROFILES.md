# Model profiles and requirements

The Windows x64 SDK provides projects for Delphi 13.2 and Lazarus 4.8 with FPC 3.2.2. Use the [Prepare guide](PREPARE-EXAMPLES.md) to install the selected example and its dependencies.

Ready CUDA bundles cover compute capabilities `sm_75`, `sm_86`, `sm_89`, and `sm_120`, spanning GTX 1650 and the RTX 20, 30, 40, and 50 families. Prepare selects a bundle using the installed device, the driver, and the selected model's free-memory requirement. The prepared examples use CUDA device 0 and a driver supporting CUDA 12.8.

| Example | Model and result | Minimum free GPU memory checked by Prepare |
| --- | --- | ---: |
| VisionModels | SqueezeNet and ResNet50 classification; YOLO11n classification and detection; RT-DETR detection | 1 GiB |
| [YoloModels](../examples/yolo-models/README.md) | 115 profiles across seven typed tasks in size groups `n`, `s`, `m`, `b`, `l`, `x`, and `all`, with original-size result export | 1,536 MiB |
| PaddleOCR | PP-OCRv5 Server text detection and recognition | 2 GiB |
| BiRefNet | Full SwinL HR800 background removal, mask, and transparent cutout | 4 GiB |
| OmDetTurbo | CLIP text encoding and Swin-Tiny detection from editable class names | 2 GiB |
| QwenChat and ImagePrompt | Qwen2.5-VL 3B text and image input | 5 GiB |
| GemmaChat | Gemma 3n E4B text and image input | 5,312 MiB |
| HuihuiGemmaChat | Huihui Gemma 3n E4B abliterated text and image input | 5,984 MiB |
| Qwen38Q4Chat | Qwen3.8-27B UD-Q4_K_M text and image input | 3,873 MiB |
| Qwen38BF16Chat | Qwen3.8-27B original BF16 text and image input | 3,083 MiB |
| Gemma 2 console examples | Text generation and model lifecycle | 5,500 MiB |

The CPU routes use AVX2 and FMA. Model weights, decoded data, and the operating system also need system memory and disk space. Prepare reports its checks and the remaining download size before installation. See each example's guide for its setup.

[OmDet-Turbo](../examples/omdet-turbo/README.md) accepts up to 16 class names and a task instruction. Its FP32 detector uses a 640-pixel image input; the CLIP encoder uses up to 77 tokens per class or task. Saved detections use the original image dimensions.

[BiRefNet](../examples/birefnet/README.md) uses the full SwinL model with an 800-pixel input and saves an original-size mask or transparent PNG.

The [model input matrix](MODEL-MODALITIES.md) describes text and image inputs for the language architectures. The [capability matrix](CAPABILITIES.md) lists the supplied examples. The [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) describes source packs, checkpoints, and native compiler tools.

Original CrossPascal code uses MIT licensing. Model files and native dependencies retain their included licenses and notices. See [license scope](LICENSE-SCOPE.md).
