# Roadmap

The first milestone is a Windows x64 SDK with a model converter, runnable Pascal examples, and independent OpenCV and Leptonica components. The [capability matrix](CAPABILITIES.md) lists the profiles and checks for this release.

## Compilers and platforms

The next Windows x64 compatibility work covers Delphi 10.2 Tokyo, 10.3 Rio, 10.4 Sydney, 11 Alexandria, and 12 Athens. It also covers Free Pascal 3.2.3 and earlier Lazarus releases from 3.0 through 4.6. Each addition needs its own build and example checks.

Linux support is a separate goal for the native runtime, converter, and examples.

## Image processing and model inference

Develop the common interfaces for detection, segmentation, classification, and OCR. Extend the TVM and OpenCV DNN backends and add tested model profiles. Candidate families include additional YOLO variants, RT-DETR, PaddleOCR, OmDet, BiRefNet, and Grounded-SAM.

Continue MarkerLite from basic image processing toward a single application for loading, detection, segmentation, and OCR. Separate the core tensor interface from image adapters so text-only applications can use a smaller source set.

## Language models and other backends

Evaluate additional Qwen and Gemma profiles, larger context settings, and other precision options. Keep GPU architecture configurable for each build. Explore TensorFlow Lite, cuDNN, and medical imaging applications as separate work.
