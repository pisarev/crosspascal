# Image adapters and Mat/Pix bridge

These units connect the shared Pascal image algorithms to the independent OpenCV and Leptonica libraries. They belong to the umbrella CrossPascal repository because they depend on shared interfaces or on both backends.

| Unit | Direct dependencies | Purpose |
| --- | --- | --- |
| `CrossVision.Image.OpenCV` | `CrossVision.Image`, OpenCV bindings | Borrow a grayscale Mat as `IImageAccessor`; write pixels back to a grayscale Mat |
| `CrossVision.Image.Leptonica` | `CrossVision.Image`, `CrossVision.Pix` | Retain a Pix as `IImageAccessor`; convert non-8-bit input once; write into an 8-bit Pix |
| `CrossVision.MatPix` | `CrossVision.Mat`, `CrossVision.Pix`, OpenCV value types/constants | Convert between supported Mat/Pix layouts, resize through Leptonica, and crop centrally |

The independent high-level wrappers are delivered with their backends: `CrossVision.Mat` in `crosspascal-opencv/pascal`; `CrossVision.Pix`, `Box`, `Pixa`, `Pta`, `Numa`, `Colormap`, `FPix`, and `Sel` in `crosspascal-leptonica/pascal`.

The pure units `Image`, `Binarize`, `Morphology`, `Contour`, and `Curve` are in `../rtl-algorithms/src`, together with the required Geometry and DisjointSet units. Binarize uses Morphology and Contour; Contour uses Curve and DisjointSet; Curve uses Geometry and Geometry.Types. Keep this full source closure even when a particular application calls only Sauvola.

## Lifetime rules

Initialize the matching native runtime before creating its high-level image objects. Release all wrapper interfaces and borrowed accessors before finalizing the runtime. Keeping processing in a nested procedure makes temporary interface references leave scope before the caller unloads the library.

`GrayMatAccessor` borrows the raw `TMat` without taking ownership. Pass a single-channel 8-bit Mat and keep its owning `IMat` alive for every accessor read. `GrayPixAccessor` retains its `IPix`, including any conversion it creates.

The Mat/Pix bridge needs both runtimes initialized. It supports 8-bit Pix with CV_8UC1, 32-bit Pix with CV_8UC4, and CV_8UC3 to 32-bit Pix with alpha set to 255. Other depths or channel counts return an empty result. The bridge copies pixel values; it does not share native allocations between the two libraries.

## Manual example

Open `MarkerLite.dproj` in Delphi or `MarkerLite.lpi` in Lazarus from `../examples/marker-lite/`. Build for Windows x64 to try Open, Grayscale, Sauvola, Canny edges, and Save PNG. Its project already contains the required relative search paths. It demonstrates the OpenCV adapter and shared algorithms; it does not load Leptonica.

For the standalone Leptonica example, open `LeptonicaHello.dproj` or `LeptonicaHello.lpi` from `../../crosspascal-leptonica/examples/`. The Leptonica packages include eight image helper units and do not depend on OpenCV.
