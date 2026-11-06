# Text and image input

The family name alone does not identify the model's supported inputs. The converter must inspect its architecture and available weights.

| Architecture | Original model capability | This early-access converter and example |
| --- | --- | --- |
| Qwen2/Qwen2.5 dense causal language model, including the checked Instruct and Coder models | Text input and output | Text through QwenChat; persistent GPU weights, streaming, Stop and sampling controls |
| Qwen2.5-VL | Text and image input; video support in the original architecture | Not implemented by the current Qwen text converter; rejected rather than treated as a dense text checkpoint |
| Gemma 2 | Text input and output | Experimental CPU text route with its documented numerical restrictions |
| Gemma 3n | Text, image and audio input in the original multimodal architecture | Gemma 3n GGUF text decoder through TVM CPU or CUDA; GemmaChat accepts the CUDA text bundle |

Adding an image button cannot turn a text-only checkpoint into a vision-language model. The original vision weights, preprocessing settings and the correct multimodal architecture are required. The text-only Gemma 3n GGUF used for the current acceptance contains no vision or audio tensor groups.

## Planned text-plus-image route

The implementation needs an architecture adapter, not a list of model names:

1. Inspect the vision configuration and require the matching image encoder, projector and text decoder weights. Preserve model access conditions and licenses.
2. Reproduce the original resize/crop, normalization, image-token placement, positions and attention rules. Record these in a versioned bundle manifest with explicit `text` and `image` capabilities.
3. Compile the vision encoder and projector through TVM for the detected or manually selected target. Account for their additional GPU memory alongside the text decoder.
4. Extend the runtime to pass projected image embeddings into the decoder. Keep text-only execution working and reject image input for a text-only bundle.
5. Add an image selector, thumbnail, removal button and prompt to the Pascal example. Show the loaded bundle's actual capabilities.
6. Compare image-dependent answers with the original implementation on the same weights and preprocessing. Include a changed-image test to establish that the image is really used, then verify Delphi and Lazarus and document resource needs.

Gemma 3n and Qwen2.5-VL need separate adapters. They can share the capability manifest and user interface, but their image processing and transformer details differ. Image inference has not passed acceptance in this release. Audio and video are also outside the current route.

Original architecture documentation: [Qwen2.5 text model](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct), [Qwen2.5-VL](https://qwenlm.github.io/blog/qwen2.5-vl/), [Gemma 3n](https://huggingface.co/docs/transformers/model_doc/gemma3n).
