# Text and image input

A family name alone does not establish image support. The converted bundle needs the matching architecture, tokenizer and vision weights.

| Architecture | Implemented input | Examples |
| --- | --- | --- |
| Dense Qwen2/Qwen2.5, including Instruct and Coder | Text on CUDA | QwenChat and console examples |
| Gemma 2 | Experimental text on CPU or CUDA with the profile's numerical restrictions | GemmaChat and console examples |
| Gemma 3n text bundle | Text on CPU or CUDA | GemmaChat and console examples |
| Gemma 3n CPU or CUDA with a converted gemma3nv projector | Text and images | Both chat forms and all generation console examples |
| Qwen2.5-VL | Text and images on CPU or CUDA | Both chat forms and all generation console examples |
| Other vision architectures | No implicit compatibility claim | Unsupported inputs are explicitly rejected |

Both chat forms have Attach image, a thumbnail and Remove image. A text-only bundle displays an explanation and blocks the image request before inference. Remove the image or select a compatible image bundle. No external captioning, OCR substitution or silent omission is used.

Use **Add images to a Gemma 3n bundle** in the converter. Supply a CPU or CUDA text bundle with host embeddings and its matching projector GGUF. It creates a separate bundle with vision.json, an encoder DLL, parameters and artifact hashes. Older CPU text bundles may require reconversion. The architecture comes from the text bundle, not a graphics-card name. Original model terms and access conditions still apply.

The verified image profile resizes RGB input to 768 by 768 with bilinear interpolation and produces 256 image tokens. These tokens, the question and the answer share the converted context. TVM executes vision encoding and text decoding; Pillow decodes image files. Audio and video input are not implemented.

Qwen2.5-VL has a separate checkpoint-folder conversion section. Its default 224-pixel profile preserves image aspect ratio, pads the image and contributes 64 image tokens. It uses the original vision weights and multimodal rotary positions. It is not the dense Qwen2.5 text adapter with an image filename added.

New CPU image profiles use block prefill before token-by-token decoding. A previously encoded, unchanged image can reuse its features while the model stays loaded. Exact timings depend on the model, processor, available memory and storage. Numerical and bounded semantic checks do not establish accuracy for every image or checkpoint.

The [console examples](../examples/language-models/README.md) show how to check SupportsImages before submitting an image. [Gemma conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/GEMMA3N.md) and [Qwen2.5-VL conversion](https://github.com/pisarev/crosspascal-convert/blob/main/docs/QWEN2.5-VL.md) describe setup and manual steps. LoadUnload is a lifecycle example and does not perform inference; all generation examples accept an image when the selected bundle supports it.

In the unpacked SDK, the same guides are in `crosspascal-convert/docs/`.
