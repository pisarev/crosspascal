# Qwen CUDA chat in Delphi and Lazarus

QwenChat loads a converted Qwen2.5-0.5B-Instruct bundle and generates a short answer on NVIDIA GPU 0. Open the Delphi or Lazarus project. The CUDA profile uses FP32, all 24 layers, batch 1, context 64 and prefill chunk 64. Six new tokens is the default. EOS stops generation early.

The model revision is `7ae557604adf67be50417f59c2c2f167def9a775`. A bundle produced for another profile is rejected. CPU fallback is disabled.

## Prepare the folders in File Explorer

1. In your browser, download the matching CrossPascal release archive and choose **Extract All** in File Explorer. Keep the repository folders together. The folders named `crosspascal`, `crosspascal-tvm` and `crosspascal-opencv` must be siblings.
2. Obtain the converted bundle using the converter described in the [main README](../../README.md). Select the named Qwen CUDA profile above. Extract the complete generated bundle to a writable working folder.
3. Keep `model.json`, `manifest.json`, `params.json`, `params.index`, `params.bin`, `qwen2-cuda.dll` and the five `tokenizer-*` / `tokenizer.index` files in the same model directory. The files must come from one completed conversion.
4. Locate `crosspascal-tvm/runtime/windows-x64-cuda`. Install the four pinned runtime DLLs there using the [Windows setup guide](../../docs/WINDOWS-EARLY-ACCESS.md). Leave the DLLs together with their licences and notices.

The PC needs a compatible NVIDIA driver and the Microsoft Visual C++ x64 runtime. Use the converter to build the model bundle for the CUDA architecture of the running device. Free enough GPU memory for the model before running; the application checks current free memory and reports allocation failures. Model parameters occupy about 1.84 GiB, with additional memory required for the runtime, temporary tensors and KV cache.

## Open and build in Delphi

1. Choose **File > Open Project** and open `crosspascal/examples/qwen-chat/QwenChat.dproj`. Open the project file, rather than creating a new project around the `.dpr`.
2. In Project Manager, activate **Release** and **Windows 64-bit**.
3. Open **Project > Options > Building > Delphi Compiler** if you want to inspect the supplied settings. The search path includes `..\..\..\crosspascal-tvm\pascal` and `..\..\..\crosspascal-opencv\pascal`. The conditional defines include `TVM_LAZY_INIT`.
4. Keep runtime packages disabled. Integer overflow checking is disabled for the tokenizer's intentional unsigned hash arithmetic.
5. Choose **Project > Build QwenChat**. The executable goes to `bin\Win64\Release\QwenChat.exe`; compiled units go to `build\Win64\Release`.

The form is created in Pascal code; there is no missing `.dfm` file. You do not need to install a design-time component package. The current TVM unit uses the sibling OpenCV Pascal sources for its image-interface types, but this text example does not initialize OpenCV. Leptonica is not required.

## Open and build in Lazarus

1. In Lazarus 4.8, open `crosspascal/examples/qwen-chat/QwenChat.lpi`.
2. Build with the Windows x64 FPC 3.2.2 compiler. The project supplies the relative unit paths and compiler settings.
3. Run the project or open `bin\lazarus-win64\QwenChat.exe` in File Explorer.

## Run a short prompt

1. Run the project in your IDE or open the compiled `QwenChat.exe` in File Explorer.
2. Beside **Converted model bundle**, click **Browse** and select the directory containing `model.json`.
3. Beside **Pinned CUDA runtime directory**, select `crosspascal-tvm/runtime/windows-x64-cuda`. The application fills this in automatically when it can locate the sibling repository.
4. Enter a short prompt, for example `Say hello in English.`, and leave **Max new tokens** at `6`.
5. Click **Run on GPU**. The status line shows validation, weight loading and generation progress. The result identifies the actual GPU and compute capability, then shows the generated text.
6. Use **Save result** to save a new JSON report if needed. Existing reports are not overwritten. Close the application normally after the current operation finishes.

The chat template consumes some of the 64-token context. The application rejects a prompt when template tokens plus the requested new tokens exceed that limit. A six-token answer may end mid-sentence; that is the selected generation limit, not an automatic failure.

## What the example checks

Before loading model parameters onto the GPU, the application checks the model profile, source identity, full parameter layout and hash, model-library hash, tokenizer hashes and runtime hashes. It rejects incompatible files and checks that GPU 0 matches the architecture recorded in the model and artifact manifests. Inputs are held open against writes throughout the run.

Embedding, prefill and decode must return the expected float32 CUDA tensor shapes. The application checks for nonfinite logits, performs greedy token selection and honours EOS. Each run releases its tensor, model and cache references. The runtime DLLs remain loaded until ordinary process shutdown, as required by the runtime's thread lifetime; the program does not use `Halt` to bypass normal exit.

A successful result applies to that bundle, prompt and device. Consult the matching [release notes](https://github.com/pisarev/crosspascal/releases) for the measured validation scope.

