# Text and image input

A family name alone does not establish image support. The converted bundle needs the matching architecture, tokenizer and vision weights.

| Architecture | Implemented input | Examples |
| --- | --- | --- |
| Dense Qwen2/Qwen2.5, including Instruct and Coder | Text on CUDA | QwenChat and console examples |
| Gemma 2 | Text on CPU or CUDA | GemmaChat and console examples |
| Gemma 3n text bundle | Text on CPU or CUDA | GemmaChat and console examples |
| Gemma 3n CPU or CUDA with a converted gemma3nv projector | Text and images | Both chat forms and all generation console examples |
| Qwen2.5-VL | Text and images on CPU or CUDA | Both chat forms and all generation console examples |
| Dense Qwen3.5/3.8 | Text on CPU or CUDA; text and images when the bundle includes the original vision encoder. Original BF16 requires CUDA | Both chat forms and all generation console examples |
| Other vision architectures | No implicit compatibility claim | Unsupported inputs are explicitly rejected |

Both chat forms have Attach image, a thumbnail and Remove image. A text-only bundle displays an explanation and blocks the image request before inference. Remove the image or select a compatible image bundle. No external captioning, OCR substitution or silent omission is used.

In the converter, select a Gemma 3n CPU or CUDA profile, including Huihui, with the original GGUF and its matching gemma3nv projector GGUF. The resulting bundle contains vision.json, an encoder DLL, parameters and artifact hashes. The architecture comes from the source GGUF, not a graphics-card name. Original model terms and access conditions still apply.

The verified image profile resizes RGB input to 768 by 768 with bilinear interpolation and produces 256 image tokens. These tokens, the question and the answer share the converted context. TVM executes vision encoding and text decoding; the Pascal application uses OpenCV to decode image files. Audio and video input are not implemented.

Qwen2.5-VL has a separate checkpoint-folder conversion section. Its default 224-pixel profile preserves image aspect ratio, pads the image and contributes 64 image tokens. It uses the original vision weights and multimodal rotary positions. It is not the dense Qwen2.5 text adapter with an image filename added.

Qwen3.8 image bundles add the original BF16 vision tensors from the source repository. Images are letterboxed to 512 by 512 with bicubic interpolation, and image tokens use multimodal rotary positions. The ready bundles share a 4,096-token context between prompt, image tokens and answer.

New CPU image profiles use block prefill before token-by-token decoding. A previously encoded, unchanged image can reuse its features while the model stays loaded. Exact timings depend on the model, processor, available memory and storage. Numerical and bounded semantic checks do not establish accuracy for every image or checkpoint.

The [console examples](../examples/language-models/README.md) show how to check SupportsImages before submitting an image. [Gemma conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/GEMMA3N.md), [Qwen2.5-VL conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/QWEN2.5-VL.md) and [Qwen3.8 conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/QWEN35.md) describe setup and manual steps. LoadUnload is a lifecycle example and does not perform inference; all generation examples accept an image when the selected bundle supports it.

In the unpacked SDK, the same guides are in `crosspascal-convert/docs/`.
