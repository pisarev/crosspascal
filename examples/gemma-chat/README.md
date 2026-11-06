# GemmaChat

Ask a Gemma 3n model a question from a Delphi or Lazarus application. The answer appears as it is generated. The application keeps the model loaded between requests and releases it when you close the window or choose another bundle.

This example accepts **text**. It uses the experimental native TVM CUDA W8A32 bundle produced by the Gemma converter: int8 projection weights with FP32 arithmetic. Inference does not run in PyTorch or Ollama. The Pascal application communicates over private local pipes with the included Python TVM runtime. It does not contact a server. QwenChat uses a separate, native Pascal consumer; its model bundles are not interchangeable with Gemma bundles.

## Prepare the files

1. Download the coordinated Windows x64 SDK and its **Gemma runtime** companion asset from the same private release.
2. Extract both archives into the same parent directory. The resulting `crosspascal-windows-x64` folder must contain `crosspascal`, `crosspascal-convert` and `runtime/gemma-python/python.exe`.
3. Prepare a compatible Gemma 3n GGUF through the [Gemma converter](../../../crosspascal-convert/docs/GEMMA3N.md). Select CUDA or automatic device detection. Keep the resulting bundle directory intact. It contains `model.json`, the generated DLL, parameters and tokenizer.

To run an already converted compatible bundle, you need the supplied runtime, a compatible NVIDIA driver and enough GPU memory. You do not need the conversion toolchain, PyTorch or a separately installed Python. The model's original access and license conditions continue to apply; model weights are not included in the release.

## Build and run manually

1. Keep the example inside the extracted SDK so its relative source paths work.
2. In Delphi 13.2, open `GemmaChat.dproj`, select **Release / Windows 64-bit**, then **Project > Build GemmaChat**. In Lazarus 4.8 with FPC 3.2.2, open `GemmaChat.lpi` and choose **Run > Build**.
3. Run the application. The distributed EXE, when supplied, is built with Lazarus.
4. In the first field, select the **converted bundle directory**, not the original GGUF file. The second field should automatically find the SDK root; use **Browse** if you moved the application.
5. Keep the default question and click **Run on GPU**. An instruct model should answer “Paris”. Ask another question without closing the window: the status should report that the model was reused.
6. Keep **Max new tokens = 0** for automatic generation. A positive number is your manual output limit. **Stop** preserves the text already generated. **Save result** writes text, token IDs, timings and the stop reason to a JSON file.

Each request is independent: reusing the weights does not preserve conversation history. **Plain completion** is for base models; leave it unchecked for the usual instruct/chat bundle. This example uses greedy decoding. It does not offer sampling controls that the backend does not implement.

The bundle's compiled context is a real capacity: prompt and answer share it. Automatic mode ends at EOS, Stop or this capacity. A `context_limit` result is reported explicitly; convert with a larger supported context for longer answers. No fixed 16-token output limit is applied.

## Images

The original Gemma 3n architecture supports images, but this converter and demo currently implement only its text decoder. A text-only GGUF does not contain a vision encoder. See [text and image capabilities](../../docs/MODEL-MODALITIES.md) before choosing a model. Selecting a picture is not a supported input for this example.
