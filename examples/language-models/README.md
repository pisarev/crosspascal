# Language models in a few Pascal calls

## Prepare and Run

Run **Prepare.cmd** in this folder and choose a console example, or use its named `Prepare-<Project>.cmd` file. It downloads the matched dependencies and sample data, then opens the prepared project folder. Open the **.dproj** in Delphi 13.2 or the **.lpi** in Lazarus 4.8, and press **Run**. See the [complete preparation guide](https://github.com/pisarev/crosspascal/blob/main/docs/PREPARE-EXAMPLES.md) for public downloads and optional GitHub request-limit recovery, model sizes and the other examples.


These small console programs show the same API used by QwenChat and GemmaChat.
Open a project, build it, and read its short main procedure. No web server or
conversion tools run inside these examples.

You need a converted model bundle and the installed CrossPascal SDK. Original
Hugging Face weights and an original GGUF are inputs to the converter; they are
not converted bundles. A bundle contains `model.json` and its referenced files.

| Example | What it shows |
| --- | --- |
| `LoadUnload` | Inspect a bundle, load its weights, and release them without generating text |
| `GenerateText` | Get a complete answer |
| `GenerationSettings` | Set every supported generation option |
| `StreamAndStop` | Print text as it arrives; hold Escape to stop |
| `RepeatedRequests` | Reuse loaded weights for two independent requests |
| `ImagePrompt` | Check image capability before submitting an image |

## Build and run by hand

1. In Delphi 13.2, open the chosen `.dproj`. Select **Release / Windows 64-bit**,
   then **Project to Build**.
2. Alternatively, in Lazarus 4.8, open the matching `.lpi` and choose **Run to Build**.
3. Open the IDE's run-parameters dialog. Enter the converted bundle directory,
   then the SDK root, each in double quotes. For example:

   `"D:\Models\my-converted-bundle" "D:\CrossPascal"`

4. To include an image, add its filename as a third quoted argument. This is
   optional for `GenerateText`, `GenerationSettings`, `StreamAndStop` and
   `RepeatedRequests`, and required for `ImagePrompt`. `LoadUnload` demonstrates
   lifecycle only. For example: `"D:\Models\my-bundle" "D:\CrossPascal" "D:\Photos\cat.jpg"`.
5. Run the program. Read the status and answer in its console window. You can
   also start the built program from a terminal with the same arguments.

The SDK root contains `crosspascal-tvm`, `crosspascal-convert` and the supplied
`runtime` directory with the native TVM libraries. Dense Qwen also accepts its
pinned native runtime directory directly. A compatible NVIDIA driver is required
for CUDA bundles; CPU bundles use system memory instead.

## The five operations

`ImagePrompt` streams a brief image description with greedy decoding. Hold
Escape to stop it. Its output setting remains automatic (`0`); the request for
one sentence is an instruction to the model, not an artificial token ceiling.

Create a `TLanguageModel`, call `Load`, fill `TLanguageOptions`, call `Generate`,
then call `Unload`. Always free the object in a `finally` block. `Generate`
returns a JSON report; `OnText` receives the complete answer so far, not just
the latest fragment. `ShouldStop` is a cooperative cancellation callback.
Call methods sequentially. Do not unload a model while generation is active.

Loaded weights survive subsequent requests. Requests have separate contexts:
the example does not automatically remember the previous conversation.

## Generation options

| Option | Meaning |
| --- | --- |
| `MaxNewTokens` | `0` is automatic. A positive integer is a manual limit; there is no arbitrary demo ceiling. |
| `Sampling` | `qsSample` samples tokens; `qsGreedy` chooses the highest score. `qsDefault` samples in automatic mode and uses greedy decoding with a manual limit. |
| `Temperature` | Sampling temperature, 0.01-2.0; default 0.7 |
| `TopP` | Nucleus probability, greater than 0 and at most 1; default 0.8 |
| `TopK` | Candidate count, 1-128; default 20 |
| `RepetitionPenalty` | Sampling penalty, 1-2; default 1.1 |
| `Seed` | `-1` chooses a random seed; 0-4294967295 gives a repeatable seed for the same runtime and inputs |
| `Effort` | Optional answer budget: full context, 128, 512 or 1024 tokens. This is an output budget, not a reasoning mode. |
| `SystemPrompt` | Dense Qwen system instructions; the Gemma and Qwen-VL paths prepend them to the user prompt |
| `PlainCompletion` | Disable the chat template for plain text completion; system instructions do not apply to plain Qwen completion |

Temperature, Top P, Top K, seed and repetition penalty affect sampling. Greedy
decoding preserves the highest-score path. The result records the effective
settings and stop reason.

Automatic mode (`0`) sets the answer budget within the remaining compiled
context. A context includes the prompt, image tokens and generated text. The
report records whether generation ended at the end-of-answer token, the manual
limit, the answer budget, the context limit or your Stop request, with token
counts. A larger context requires a suitable converted bundle and enough
memory; `0` cannot make a fixed-size cache infinite.

## Models and images

The API dispatches by the converted bundle architecture, not by a list of
model sizes or GPU names. Qwen2 dense text bundles, experimental Gemma 2 CPU,
Qwen2.5-VL, Gemma 3n and Qwen3.5/3.8 CPU/CUDA bundles use the same lifecycle.

`SupportsImages` describes the actual bundle and runtime. It is not a promise
based on a family name. The dense Qwen2.5 models are text models; adding an
image filename cannot make them see. A multimodal family member needs its own
vision weights and compatible conversion/runtime support. An unsupported image
request fails clearly before inference and is never silently reduced to text.

Gemma 3n CPU or CUDA bundles with a verified vision manifest and its referenced
encoder files also accept image paths. To create one, select the original GGUF and its
matching `gemma3nv` projector GGUF in the converter's Gemma 3n profile. A
selected image occupies 256 tokens in the verified 768-pixel profile.
Qwen2.5-VL CPU and CUDA bundles include their vision graph. A 224-pixel profile
uses 64 image tokens and aspect-preserving padding. Qwen3.8 image bundles use
the original BF16 vision tensors and a 512-pixel letterboxed profile. Image
files are decoded with OpenCV; inference uses TVM. All generation examples validate
`SupportsImages` before submitting an optional picture. Neither dense Qwen2.5
nor Gemma 2 gains vision merely by passing an image filename.

Gemma 2 remains experimental with the limitations documented in its bundle.
These examples do not expand the numerical acceptance scope of that profile.
