# GemmaChat in Delphi and Lazarus

## Prepare and Run

Download [Prepare-GemmaChat-ea018.zip](https://github.com/pisarev/crosspascal/releases/download/early-access-018/Prepare-GemmaChat-ea018.zip), extract it, and double-click **Prepare.cmd**. It downloads the matched dependencies and sample data, then opens the prepared project folder. Open the **.dproj** in Delphi 13.2 or the **.lpi** in Lazarus 4.8, and press **Run**. See the [complete preparation guide](https://github.com/pisarev/crosspascal/blob/main/docs/PREPARE-EXAMPLES.md) for public downloads and optional GitHub request-limit recovery, model sizes and the other examples.


Both chat demos use the same controls and `TLanguageModel` API. Choose a
converted model by its `model.json`, not by its filename or a graphics-card name.
Dense Qwen2.5 and Gemma 2 are text-only architectures. Qwen2.5-VL and a Gemma 3n
bundle containing its converted vision encoder accept a picture and a question.

## Open and build

Extract the Windows x64 SDK.
Keep `crosspascal`, `crosspascal-tvm`, `crosspascal-opencv`, `crosspascal-convert`
and `runtime` beside one another. Completed bundles run without conversion
tools. CPU bundles use system memory; CUDA bundles need a compatible driver.

1. In Delphi 13.2, open `GemmaChat.dproj`, select **Release / Windows 64-bit**,
   and choose **Project to Build**.
2. Alternatively, in Lazarus 4.8, open `GemmaChat.lpi` and choose **Run to Build**.
3. Run the program. Distributed executables are built with Lazarus; Delphi
   builds are used to check source compatibility.

The form is created in Pascal code; no form resource or design-time package is
required. Dense Qwen, Qwen2.5-VL and Gemma run through native TVM libraries
called from Pascal.

## First answer

1. In the **Model** row, click **Browse...** and select the converted folder
   containing `model.json`. Original Safetensors or GGUF files go to the
   converter first.
2. The SDK location is found automatically. If necessary, open **Settings**
   and choose **Installed SDK folder** at the bottom of the settings panel.
3. Click **Load model**. The capability line identifies the architecture,
   execution device, context size and supported inputs.
4. Type a question in **Message**. **New tokens** defaults to `0` (automatic),
   with **Answer budget** set to **Full context**.
5. Click **Generate**. Read the answer as it appears. **Stop** requests
   cancellation at the next safe model-operation boundary.
6. Ask another question to reuse loaded weights. Each request has a fresh
   context; the demo does not automatically include earlier messages.
7. Click **Unload** to release the model. Normal closing also unloads it.

**Save result...** creates a JSON report of the answer, effective settings,
timings and stop reason. Existing reports are not overwritten. Settings live
in a separate scrollable panel; hiding it gives more room to the answer.

Loading verifies model files before inference. Storage speed, model size and
available memory affect startup. Reusing the loaded model avoids reading and
verifying its weights again. CPU image processing can take noticeably longer
than text-only generation; the report separates image processing and response
timings. A previously encoded, unchanged image can reuse its cached features.

## Settings

| Control | Default | Meaning |
| --- | --- | --- |
| New tokens | 0 | Automatic output; a positive integer requests a manual maximum without an artificial demo ceiling. |
| Sampling | Auto | Sample in automatic mode, greedy with a manual limit; either can be selected explicitly. |
| Temperature | 0.7 | Sampling variability, 0.01-2.0. |
| Top P | 0.8 | Nucleus probability within Top K, greater than 0 through 1. |
| Top K | 20 | Sampling candidates, 1-128. |
| Repetition penalty | 1.1 | Penalty for previously seen tokens when sampling, 1-2. |
| Seed | -1 | Random seed; 0-4294967295 gives repeatable sampling with the same runtime and inputs. |
| Answer budget | Full context | Optional automatic budgets of 128, 512 or 1024 tokens; a positive manual maximum takes precedence. |
| Instructions | You are a helpful assistant. | Dense Qwen uses a system role; the Gemma and Qwen-VL paths prepend these instructions to the user prompt. |
| Plain completion | Off | Disable the chat template. System instructions do not apply to plain dense-Qwen completion. |

Temperature, Top P, Top K, repetition penalty and seed affect sampling. Greedy
chooses the highest score. Answer budget is an output allowance, not a separate
reasoning mode. Automatic output ends at an end-of-answer token, Stop, or the
bundle's actual context capacity. Prompt, image tokens and answer share that
capacity; `0` cannot make a fixed-size cache infinite.

## Attach a picture

Click **Attach image...**, choose a PNG, JPEG or BMP, and check its thumbnail.
Ask a question about it, then click **Generate**. **Remove** returns to text
input. Images remain local. The form accepts one image per request.

Image capability comes from the actual bundle. A text-only bundle explains the
limitation and blocks image inference before execution. It never silently
ignores the picture. Remove it or select a compatible multimodal bundle.

For **Qwen2.5-VL**, convert an original checkpoint folder, including its vision
weights and tokenizer, in the converter's Qwen2.5-VL section. The CPU profile
preserves aspect ratio and pads an image to the selected size. A 224-pixel
profile uses 64 image tokens; larger supported image sizes use more memory and
context. This is a different architecture from dense Qwen2.5.

For **Gemma 3n**, use **Add images to a Gemma 3n bundle** in the converter.
Select a CPU or CUDA text bundle with host embeddings and its matching
`gemma3nv` projector GGUF. Inspect, then build a new image bundle. Older CPU
text bundles may need reconversion. The 768-pixel profile uses 256 image tokens.
A text GGUF alone does not contain the necessary vision weights. Audio and
video inputs are not implemented.

Gemma 2 remains an experimental text profile with the numerical limitations
documented in its bundle. These demos do not expand that acceptance scope.

## Use the same API without a window

The [minimal console examples](../language-models/README.md) show loading,
all settings, streaming, Stop, repeated requests, images and unloading. They
use the same `TLanguageModel` and `TLanguageOptions` as these demos.
