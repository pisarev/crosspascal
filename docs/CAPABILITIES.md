# Windows x64 capabilities

The early access SDK supports Delphi 13.2 and Lazarus 4.8 with FPC 3.2.2. Keep the repository folders from the same SDK together. See the [Windows setup guide](WINDOWS-EARLY-ACCESS.md) for installation and project paths.

| Route | Example | Verified result |
| --- | --- | --- |
| Pure Pascal geometry and sets | Geometry and DisjointSet | 541 and 9 checks passed, respectively, in both compilers |
| OpenCV image access | CrossCVHello | Pixel sum of 84 and 12 nonzero pixels in both compilers |
| OpenCV image resize | LoadResizeSave | The GUI opened a PNG and saved identical 640 × 480 outputs in both compilers |
| Document imaging | LeptonicaHello | A 256 × 96 grayscale gradient in both compilers |
| Interactive image processing | MarkerLite | The GUI opened a PNG and saved identical grayscale outputs in both compilers. The example also exposes Sauvola and Canny |
| Video I/O | Native OpenCV bridge | The FFmpeg backend wrote and read a test video |
| CUDA language generation | Converter and QwenChat | The converter built the bundle for the detected architecture. Both IDE builds returned the same six tokens for the first-run prompt |
| CPU vision | Converter and VisionModels | Five pinned application profiles produced finite classifications or detections in both compilers |

## Model profiles

The two Qwen2.5-Instruct profiles use FP32, batch size one, and a 64-token context and prefill chunk. The 0.5B and 1.5B models have 24 and 28 layers respectively. The converter detects the local CUDA architecture and also accepts a manually selected destination architecture. The application checks its CUDA device against the model bundle. The manual target was checked in Preview. Generation was checked for a build using the detected target.

CPU profiles include SqueezeNet 1.1, ResNet50, YOLO11n classification, YOLO11n detection, and RT-DETR R18vd. The companion source archive provides the matching inputs, exact source identities, and notices. Classifiers return ranked scores. Detectors return boxes, class IDs, and scores. Application results are scoped to the pinned profiles and tested inputs.

## Native setup

The SDK installer builds OpenCV and Leptonica from their companion source assets. The ordinary online setup fetched the pinned native build inputs in a clean Windows SDK installation. The TVM installer uses the official Apache TVM 0.26.0 and Apache TVM FFI 0.1.14 Windows wheels. See [known limitations](KNOWN-LIMITATIONS.md) for the scope of these checks.
