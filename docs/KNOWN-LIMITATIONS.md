# Known limitations

## Platforms and devices

This release targets Windows x64 with Delphi 13.2 or Lazarus 4.8 and FPC 3.2.2. Earlier compiler versions and Linux are outside the current verification matrix.

CUDA conversion and inference require compatible NVIDIA hardware, drivers, and enough free device memory. The converter can detect the local architecture or build for a manually selected architecture. A bundle is specific to its selected architecture. QwenChat uses device 0 in the visible CUDA device list. See the [converter guide](https://github.com/pisarev/crosspascal-convert/blob/main/INSTALL.md) for toolchain requirements.

## Models

QwenChat accepts the legacy named 64-token bundles and compatible local Qwen2 dense-text bundles with a 2,048-token context. Prompt, chat template and answer share that capacity. The default output setting is 0 (automatic), with optional answer budgets, a positive manual limit and Stop. There is no fixed six- or sixteen-token output cap. Loaded weights are reused between requests and text appears during generation. These checks do not establish quality for every compatible checkpoint or prompt. Dense Qwen CUDA inference has no silent CPU fallback. Qwen2.5-VL CPU is a separate explicitly selected architecture profile.

Both chat forms support Gemma 3n CPU FP32, Gemma 3n CUDA W8A32, and Qwen2.5-VL CPU FP32 through an included Python TVM worker. It is not a native Pascal tokenizer/graph implementation. The language runtime asset supplies Python, TVM, SentencePiece, Tokenizers and Pillow; PyTorch and Ollama are not used for inference. GPU projection weights are quantized to int8 with FP32 arithmetic, so this is a different numerical profile from CPU FP32. Gemma 3n conversion offers contexts up to 1,024 tokens. Its image profile resizes to 768 pixels and uses 256 context tokens per image. Qwen2.5-VL uses aspect-preserving square padding; the default 224-pixel profile uses 64 image tokens. These bounded profiles do not establish accuracy for every image or every compatible checkpoint. Audio and video inputs are not implemented. CPU builds need a compatible processor target and sufficient RAM; FP32 weights can be much larger than the original download. See [model input capabilities](MODEL-MODALITIES.md).

The five CPU vision checks cover the pinned model, preprocessing, and application result. They do not measure dataset accuracy or performance. Select the corresponding model source pack before conversion.

The OmDet result covers two recorded Windows CPU fixtures and includes a known difference in the raw numerical comparison. It is outside the supported profiles in the Windows SDK. PaddleOCR and BiRefNet are also outside those SDK profiles. Experimental Gemma 2 CPU conversion retains its separately documented attention-score soft-capping limitation; it is not the Gemma 3n CUDA backend.

## Native components

The OpenCV and Leptonica examples cover particular image operations. The OpenCV bridge also passed a basic FFmpeg video write/read check. The example results do not cover every binding, codec, or video configuration.

The native image libraries are built locally from the companion source assets. The build requires a Linux Docker engine and access to the pinned package sources. The OpenCV build enables its nonfree modules and links LGPL FFmpeg statically. See [license scope](LICENSE-SCOPE.md) for source and relinking details.
