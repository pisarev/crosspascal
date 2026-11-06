# QwenChat in Delphi and Lazarus

Dense Qwen2-compatible CUDA bundles are selected by architecture and tensor shapes, not by checkpoint name or graphics-card model. Qwen2.5 text models cannot inspect images.

## Open and build

Extract the main SDK and the matching Gemma runtime companion into the same parent folder. The companion also supplies the four native TVM DLLs used by Qwen; no conversion tools are needed to run a completed bundle.

Keep the extracted SDK folders together. The SDK root contains `crosspascal`,
`crosspascal-tvm`, `crosspascal-opencv`, `crosspascal-convert` and `runtime`.

1. In Delphi 13.2, open `QwenChat.dproj`, select **Release / Windows 64-bit**,
   then choose **Project → Build**.
2. Alternatively, in Lazarus 4.8, open `QwenChat.lpi` and choose **Run → Build**.
3. Run the program. The supplied release executable is built with Lazarus.
   Delphi builds demonstrate source compatibility and are not distributed.

The form is created in Pascal code; there is no separate form resource or
design-time package to install. Both demos share the same form and model API.
The underlying Qwen consumer is native Pascal. Gemma uses the supplied Python
runtime to call compiled TVM libraries; it does not run PyTorch or Ollama.

## First answer

1. Beside **Converted model bundle**, select the folder containing `model.json`.
   Select a completed converter output, not original model weights.
2. Beside **Installed SDK root**, select the extracted SDK root.
3. Click **Load model**. Loading does not generate an answer.
4. Enter a question. Leave **New tokens** at `0` and **Answer budget** at
   **Full context** for automatic output.
5. Click **Generate**. Text appears progressively. **Stop** keeps the partial
   answer after the current model operation finishes.
6. Ask another question to reuse loaded weights. Each request has a fresh
   context; the demo does not automatically add earlier messages.
7. Click **Unload model** to release model memory. Closing normally also unloads.

**Save result** writes a new JSON report with the effective settings, timings
and stop reason. Existing reports are not overwritten. Smaller windows scroll
so that every setting and action remains accessible.

## Settings

| Control | Default | Meaning |
| --- | --- | --- |
| New tokens | 0 | Automatic output; a positive integer requests a manual maximum with no artificial demo ceiling. |
| Sampling | Auto | Sample in automatic mode, greedy with a manual limit; choose either explicitly. |
| Temperature | 0.7 | Sampling variability, 0.01–2.0. |
| Top P | 0.8 | Nucleus probability within Top K, greater than 0 through 1. |
| Top K | 20 | Sampling candidates, 1–128. |
| Repetition penalty | 1.1 | Penalize previously seen tokens when sampling, 1–2. |
| Seed | -1 | Random seed; use 0–4294967295 for a repeatable sampling comparison. |
| Answer budget | Full context | Optional automatic budgets of 128, 512 or 1024 tokens; a positive manual maximum takes precedence. |
| Instructions | You are a helpful assistant. | Qwen system role; Gemma instructions are prepended to the user prompt. |
| Plain completion | Off | Disable the chat template. System instructions do not apply to plain Qwen completion. |

Temperature, Top P, Top K, repetition penalty and seed affect sampling. Greedy
selects the highest score. Answer budget is not a separate reasoning mode.
Automatic output ends at the model's end-of-answer token, Stop, or the actual
converted context capacity. The prompt, image tokens and answer share that
capacity; `0` cannot make a fixed-size cache infinite.

## Attach a picture

Click **Attach image**, choose a PNG, JPEG or BMP, and check its thumbnail. Enter
a question about it, then click **Generate**. **Remove image** returns to text
input. Images remain local.

Image capability comes from the selected bundle, not its family name. A
text-only bundle displays a clear explanation and blocks image inference;
it never silently ignores the picture. Remove the image or select a compatible
Gemma 3n image bundle. Dense Qwen2.5 is text-only; Qwen-VL requires a different
architecture and is not implemented by this consumer.

For Gemma 3n, open **Add images to a Gemma 3n bundle** in the converter. Select
an existing CUDA text bundle and its matching `gemma3nv` projector GGUF, inspect
the selection, then build a new image bundle. Text conversion is reused. This
profile processes a 768-pixel image into 256 image tokens; context must also fit
the question and answer. Audio is not implemented. A text GGUF alone does not
contain the required vision weights.

## Use the same API without a window

The [minimal console examples](../language-models/README.md) demonstrate explicit
loading, all settings, streaming, Stop, repeated requests, images and unloading.
They use the same `TLanguageModel` and `TLanguageOptions` as these demos.
