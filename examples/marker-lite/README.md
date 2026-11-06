# MarkerLite: manual image processing

MarkerLite is a small desktop example for Delphi and Lazarus on Windows x64. Open an image, inspect the result of each operation, and save the displayed image as PNG. The form is created in Pascal code; no DFM file is required.

## Open, build, and run

Keep the delivered repositories side by side with their supplied names. This example needs the `crosspascal` and `crosspascal-opencv` repositories, including `crosspascal-opencv/bin/crosscv.dll`. Build the library using the [Windows setup guide](../../docs/WINDOWS-EARLY-ACCESS.md).

1. In Delphi 13.2, open `MarkerLite.dproj`. In Lazarus 4.8, open `MarkerLite.lpi`.
2. Build for Windows x64. In Delphi, select **Debug** or **Release**.
3. Choose **Build**, then **Run**. No command-line arguments are needed.
4. Click **Open...** and choose a PNG, JPEG, BMP, TIFF, or WebP image.
5. Click **Grayscale**, **Sauvola**, or **Canny edges** to update the displayed image.
6. Click **Save PNG...**, choose the output filename, and confirm replacement if the file already exists.
7. Close the window normally when finished.

Each operation uses the current image. Open the original again to compare independent processing paths. The title displays the image dimensions and the saved filename. Cancelling a file dialog leaves the current image unchanged.

**Sauvola** uses the pure Pascal implementation with radius 15, K=0.2, and R=128. It produces black foreground and white background. **Canny edges** converts to grayscale and uses thresholds 50 and 150. These are image-processing demonstrations; this application does not run an OCR or language model.

## Files and relative paths

The project resolves its units through these relative paths:

| Content | Path from the project folder |
| --- | --- |
| Pure image algorithms and Geometry/DisjointSet dependencies | `../../rtl-algorithms/src` |
| Image adapters | `../../vision` |
| OpenCV bindings and `CrossVision.Mat` | `../../../crosspascal-opencv/pascal` |

Delphi writes `crosspascal/build/Win64/<configuration>/MarkerLite.exe`. Lazarus writes `bin/lazarus-win64/MarkerLite.exe` relative to this example. DCU and OBJ files are kept in project-specific subdirectories of that configuration.

At startup the application locates the sibling `crosspascal-opencv/bin/crosscv.dll` from its executable directory. It checks the binding/runtime ABI and uses that runtime directory for dependent DLL lookup within the process. It does not search a developer's private checkout. Keep the supplied layout if moving the executable.

## Image ownership and errors

Open and Save use Pascal file streams with the native memory codecs. The image viewer uses the `IMat` wrapper. Sauvola accesses a live grayscale Mat through `GrayMatAccessor`, then writes the result back with `WriteToGrayMat`.

Closing the form releases its image. The application destroys the form before calling `CVFinalize`, so native objects are released while their runtime is still loaded. Load, decode, encode, and processing failures produce English error messages.

The manual project and its source dependencies are delivered here. Build and runtime observations for a particular delivery are recorded separately; the historical test suites are not implied by the presence of this example.
