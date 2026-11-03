# CrossPascal

CrossPascal brings image processing, algorithms, and native model inference to Object Pascal. Its libraries have separate release schedules and share this project overview.

**Early-access source preview, 2026-11-04.** Source preparation and the final Windows RTL checks are complete.

The files are prepared for private testing. See the [GitHub release notes](https://github.com/pisarev/crosspascal/releases) for delivery details and clean-clone check results. Public access follows owner testing and separate approval.

## What you can try

The current runnable example is the RTL algorithms package: Geometry and DisjointSet on Windows with Delphi 37 Win64. The final prepared sources passed 541 Geometry checks and 9 DisjointSet checks, with no failures.

From this repository's root, check the file inventory with Python 3.12 or later:

```powershell
python -B scripts/verify_source.py
```

With Delphi 37 installed, run the example:

```powershell
powershell -NoProfile -File scripts/smoke-win64.ps1
```

Set `BDS_BIN` if the compiler uses a different installation directory. By default, the script builds in a separate temporary directory. To choose an output location, set `CROSSPASCAL_PREVIEW_BUILD_ROOT` to a path outside the checkout that does not yet exist.

## Projects

| Repository | Responsibility | Contents of this preview |
| --- | --- | --- |
| [crosspascal](https://github.com/pisarev/crosspascal) | Project overview and common algorithms | RTL source, tests, and the Windows example |
| [crosspascal-leptonica](https://github.com/pisarev/crosspascal-leptonica) | Pascal bindings for Leptonica | 29 Pascal units, test and tool source, and license notices |
| [crosspascal-convert](https://github.com/pisarev/crosspascal-convert) | Model conversion tools | A selection of source files for architectural review |
| [crosspascal-tvm](https://github.com/pisarev/crosspascal-tvm) | TVM integration and native build recipes | A CPU build-options template and TVM notices |
| [crosspascal-opencv](https://github.com/pisarev/crosspascal-opencv) | Pascal bindings and native bridge for OpenCV | A description of the planned package |

These repositories form the CrossPascal project family. See [capabilities](docs/CAPABILITIES.md) for the precise scope and [roadmap](docs/ROADMAP.md) for the wider project and acceptance policy.

## File verification

Each repository has one inventory and a standalone checker. The inventory lists the distributed files by size and SHA-256. Root `.git` metadata is declared separately so verification works after a clone or in a Git worktree. Other unexpected files, including ignored build files, cause verification to fail.

The `.gitattributes` file preserves the snapshot's exact bytes across Git checkouts. Build outputs belong outside the source tree. Inventory checks detect changed files; they do not establish runtime correctness or release authorization.

## License

The original CrossPascal code, documentation, and utilities use the [MIT license](LICENSE). Separate projects retain their third-party notices. See [license scope](docs/LICENSE-SCOPE.md) and the corresponding project README.
