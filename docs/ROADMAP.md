# Roadmap

The next milestone is a stable, limited early-access release. Preparation and testing take place in private repositories. Public access follows the owner's tests and a separate decision to open the repositories.

## Current milestone

| Work | Status |
| --- | --- |
| Establish OmDet numerical acceptance | Accepted for two fixed Windows CPU cases under a documented application-level contract; the original strict raw failure is retained |
| Independently review the corrected source candidate | Complete |
| Check the candidate's file origins, licenses, and private data | Complete for the accepted input set; each published snapshot requires final inventory and privacy checks |
| Prepare separate repository copies and accurate documentation | Source files and documentation prepared for private testing |
| Complete source preparation and validate the final RTL example | Complete: 10 Pascal files passed formatting and the formatter check; final Windows Delphi 37 Win64 tests passed 541 Geometry checks and 9 DisjointSet checks, with no failures |
| Upload to private repositories and test clean clones | See the [GitHub release notes](https://github.com/pisarev/crosspascal/releases) for delivery status and clean-clone check results |
| Owner testing and public opening | Public access follows owner testing and separate approval |

## Project structure

`crosspascal-leptonica`, `crosspascal-opencv`, `crosspascal-tvm`, and `crosspascal-convert` have separate product boundaries and release schedules. The `crosspascal` repository connects their documentation, compatibility information, and examples.

Separate repositories do not remove implementation dependencies. The current Pascal TVM image interface uses DLPack, OpenCV types, and CrossVision.Mat; its image conversion requires OpenCV. A standalone tensor/runtime core with a separate image adapter remains future work. The current TVM preview contains only a build-options template and notices.

## Wider scope

The full project includes foundation types, numerical and geometric algorithms, OpenCV and Leptonica bindings, image processing, machine learning, domain examples, and applications. Planned model work includes YOLO generations, RT-DETR, PaddleOCR, OmDet, BiRefNet, classification, segmentation, Qwen, Gemma, TensorFlow/TFLite, and medical experiments.

Those areas retain their own implementation and acceptance work. Their presence in this roadmap does not promise support in the current distribution. Historical milestones also do not establish that an external user can install every component today.

A complete native OpenCV distribution, broader platform support, and unfinished model acceptance do not block the limited source preview. A runnable OmDet distribution still needs a complete package with redistribution rights and installation instructions, even though the selected numerical investigation is resolved.

## Acceptance policy

Each required check must protect a declared property of the product within a stated model, input, platform, and artifact scope. Interface shape and type, discrete identifiers, valid values, execution outcomes, and file identity remain required where the contract promises them. Numerical tolerances must follow the meaning and required accuracy of the result.

Keep a raw observation (PASS, FAIL, NOT_RUN, or ERROR) separate from the acceptance decision. A strict diagnostic mismatch may coexist with acceptance under a documented application contract. The original mismatch stays visible, and the accepted variation applies only to its recorded scope and evidence. It must not become a blanket skip, a general increase in tolerance, or acceptance of an unrelated execution error.

Start a discrepancy review with the existing contract and saved evidence. Bound the investigation to a question whose answer can change the decision. Reopen an accepted case only for a concrete trigger: a changed dependency or contract, a newly reproducible behavioral failure, or an expansion of the claimed scope. Recheck affected requirements after a change; do not repeat unchanged successful calculations merely to recover context.

Existing executable checkers are being updated individually. The incomplete converter snapshot still needs explicit consumer profiles and common result aggregation before it can apply this policy throughout a complete conversion workflow. The separately accepted two-case OmDet decision does not grant acceptance to new synthetic inputs or other models.

## Before public access

Prepare the final files, verify their inventories, and run the examples promised by each package. Then test clean clones from the private repositories. Fix failures against those exact files and repeat the affected checks. The owner tests the result before deciding whether to make it public.
