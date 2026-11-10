# Release notes

## EA017 maintenance update, 10 November 2026

The supplied GUI examples use aligned controls with consistent button dimensions and an explicit keyboard tab order. The Pascal sources were formatted with the updated pascal_fmt utility. Copyright notices are retained in library code and omitted from the examples. All 13 examples were built and started with Delphi 13.2 and Lazarus 4.8 on Windows x64; the interface checks did not load a model or run inference.

## EA017 initial release

Public downloads no longer require GitHub authorization. GitHub request-limit recovery can still use an optional authenticated retry. Release metadata is
cached during preparation to reduce API requests.

Model licenses are shown before dependency preparation and in the guides. Pascal comment headers were checked across all source extensions: two component
headers were completed and two test-program headers were removed. All accepted model, runtime and executable
bytes from EA016 are retained. This release changes preparation and documentation,
not model inference or the accepted Delphi/Lazarus example behavior.
