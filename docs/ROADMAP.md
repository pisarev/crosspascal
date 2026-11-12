# Roadmap

The first milestone is a Windows x64 SDK with a model converter, runnable Pascal examples, and independent OpenCV and Leptonica components. The [capability matrix](CAPABILITIES.md) lists the profiles and checks for this release.

## Compilers and platforms

The next Windows x64 compatibility work covers Delphi 10.2 Tokyo, 10.3 Rio, 10.4 Sydney, 11 Alexandria, and 12 Athens. It also covers Free Pascal 3.2.3 and earlier Lazarus releases from 3.0 through 4.6. Each addition needs its own build and example checks.

Linux support is a separate goal for the native runtime, converter, and examples.

## Image processing and model inference

The SDK includes the first [PaddleOCR example](../examples/paddle-ocr/README.md) for CPU and NVIDIA CUDA. Develop the common interfaces for detection, segmentation, classification, and OCR. Extend the TVM and OpenCV DNN backends with tested model profiles. BiRefNet is the next model family, followed by OmDet. Additional candidates include YOLO variants, RT-DETR profiles and Grounded-SAM.

Continue MarkerLite from basic image processing toward a single application for loading, detection, segmentation, and OCR. Separate the core tensor interface from image adapters so text-only applications can use a smaller source set.

## Language models and other backends

Evaluate additional Qwen and Gemma profiles, larger context settings, and other precision options. Keep GPU architecture configurable for each build. Explore TensorFlow Lite, cuDNN, and medical imaging applications as separate work.

Qwen2 dense-text and Gemma 3n GGUF text conversion now derive supported layouts from architecture metadata. Gemma 3n CPU and CUDA image adapters include preprocessing, projected embeddings and bounded image-dependent reference checks. A separate architecture-derived Qwen2.5-VL CPU adapter is implemented; the dense Qwen2 route remains text-only. Broader image evaluation, additional projector layouts, audio and video remain future work. See the [implemented input profiles](MODEL-MODALITIES.md). A text demo or a model family name does not establish image support.
