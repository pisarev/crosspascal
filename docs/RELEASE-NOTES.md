# CrossPascal Windows x64 early access

This release brings together the CrossPascal Pascal sources, the local model converter, and examples for Delphi 13.2 and Lazarus 4.8 with FPC 3.2.2.

## Download and setup

- The Windows x64 SDK contains the five project trees, the Lazarus-built converter launcher, and a portable Python environment.
- The OpenCV and Leptonica companion assets contain the native source inputs, build instructions, and notices. The SDK installs the libraries by building them locally.
- The CPU model source archive contains the pinned inputs for SqueezeNet 1.1, ResNet50, YOLO11n classification, YOLO11n detection, and RT-DETR R18vd.
- The converter downloads the pinned Qwen2.5-0.5B-Instruct source separately. The setup command fetches and verifies the official Apache TVM 0.26.0, TVM FFI 0.1.14, and the other pinned Python packages.

Use the [Windows setup guide](WINDOWS-EARLY-ACCESS.md) after extracting the SDK. Keep the accompanying sources, licenses, and notices with their respective files.

## What was checked

- The converter selected the detected CUDA architecture on an RTX 4060 Ti and built the Qwen bundle. A short prompt produced the same six tokens in Delphi and Lazarus. Manual architecture selection was checked in Preview.
- VisionModels ran all five CPU profiles in both IDE builds. YOLO11n detection and RT-DETR R18vd were converted through the same showcase route used by the application instructions.
- Geometry, DisjointSet, CrossCVHello, and LeptonicaHello passed in both IDE builds. MarkerLite and LoadResizeSave saved identical PNGs across the two compilers.
- OpenCV and Leptonica installed from the companion sources in a clean extraction. The OpenCV FFmpeg backend wrote and read a test video. A separate rebuild using modified FFmpeg also passed the video check.

Read the [capability matrix](CAPABILITIES.md) and [known limitations](KNOWN-LIMITATIONS.md) for the limits of these checks.
