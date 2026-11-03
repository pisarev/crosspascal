# Known limitations

This source preview is prepared for private testing. See the [GitHub release notes](https://github.com/pisarev/crosspascal/releases) for delivery details and clean-clone check results.

Geometry and DisjointSet passed tests on the final prepared sources with Delphi 37 Win64 on Windows. Runtime support remains limited to this example.

The Leptonica source subset omits the native DLL and six codec fixtures. Full codec tests require the matching complete inputs. The converter omits required modules and cannot be installed or used as a complete CLI. The TVM package contains a build-options template, and the OpenCV package contains a roadmap.

OmDet is accepted only within a separate two-case Windows CPU investigation. Its original strict raw tolerance failure remains recorded. Models, trained weights, and a runnable OmDet SDK are absent from this distribution.

This preview does not establish Linux, FPC, CUDA, hosted CI, general model accuracy, or medical use. Public access follows owner testing and separate approval.
