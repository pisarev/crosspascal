# Text and image input

A family name alone does not establish image support. The converted bundle needs the matching architecture, tokenizer and vision weights.

| Architecture | Implemented input | Examples |
| --- | --- | --- |
| Dense Qwen2/Qwen2.5, including Instruct and Coder | Text on CUDA | QwenChat and console examples |
| Gemma 2 | Experimental CPU text with its retained numerical restrictions | GemmaChat and console examples |
| Gemma 3n text bundle | Text on CPU or CUDA | GemmaChat and console examples |
| Gemma 3n CUDA with a converted gemma3nv projector | Text and images | Shared chat form and ImagePrompt |
| Qwen2.5-VL and other vision architectures | Not implemented by the dense Qwen adapter | Explicitly rejected |

Both chat forms have Attach image, a thumbnail and Remove image. A text-only bundle displays an explanation and blocks the image request before inference. Remove the image or select a compatible image bundle. No external captioning, OCR substitution or silent omission is used.

Use **Add images to a Gemma 3n bundle** in the converter. Supply an existing CUDA text bundle and its matching projector GGUF. It creates a separate bundle with vision.json, an encoder DLL, parameters and artifact hashes. The architecture comes from the text bundle, not a graphics-card name. Original model terms and access conditions still apply.

The verified image profile resizes RGB input to 768 by 768 with bilinear interpolation and produces 256 image tokens. These tokens, the question and the answer share the converted context. TVM executes vision encoding and text decoding; Pillow decodes image files. Audio and video input are not implemented.

The vision encoder was compared with the same source weights in PyTorch. Changing the image while keeping the question fixed produced different, correct colour answers. This bounded check does not establish accuracy for every image or checkpoint. The text decoder consumes image tokens one at a time, which increases time to the first answer.

The [console examples](../examples/language-models/README.md) show how to check SupportsImages before submitting an image. [Gemma conversion](../../crosspascal-convert/docs/GEMMA3N.md) describes the setup and manual steps.
