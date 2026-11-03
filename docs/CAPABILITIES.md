# Capabilities of this source preview

This table describes the files prepared for private testing. A result from a larger internal package does not extend the contents or support of this snapshot.

| Component | Included here | Evidence and current limit |
| --- | --- | --- |
| Geometry and DisjointSet | Pascal units, console tests, and a Windows launcher | Final prepared sources tested on Windows with Delphi 37 Win64: Geometry 541 passed, DisjointSet 9 passed, no failures. |
| Leptonica bindings | 29 units, Delphi package, test and tool source, notices | A source subset of a separately tested package. Its native DLL and six codec fixtures are absent. No fresh full native suite was run for this subset. |
| Converter | 26 Python source files | Architectural source snapshot. Required family modules are omitted, so it is not an installable Python package or a supported CLI. |
| TVM | CPU build-options template and upstream license/NOTICE | No TVM source distribution, compiler, runtime DLL, or compiled model is included. |
| OpenCV | Package description | Native package acceptance and distribution are still pending. |
| OmDet | No model or runnable inference bundle | A separate Windows CPU investigation accepted two fixed cases under an application-level numerical contract. This does not make OmDet runnable from this preview. |

The OmDet investigation retained the original strict raw comparison result as a failure. It accepted the measured differences for the two tested inputs after checking probabilities, box corners, and discrete decisions. Pascal outputs matched the TVM output bit patterns. Broader accuracy and arbitrary-input behavior remain unverified.

Linux, FPC, CUDA, hosted CI, and other model families are not supported by this source preview. Historical results for those components remain part of the wider project record.

See [known limitations](KNOWN-LIMITATIONS.md) before choosing an example.
