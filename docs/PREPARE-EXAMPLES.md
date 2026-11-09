# Prepare and run an example

This Early Access release is private. Sign in to a GitHub account with access to
pisarev/crosspascal. Download crosspascal-examples-prepare-ea016.zip from the
[EA016 release](https://github.com/pisarev/crosspascal/releases/tag/early-access-016)
and extract it to a writable folder. Open the folder for your example and run
Prepare.cmd (the shared language-model and OpenCV folders offer a menu).

Prepare downloads a portable preparation runtime, the SDK, the required native
libraries, model bundles and a sample image. You do not need to install Python,
copy DLLs by hand or convert a model for the CPU examples. It verifies SHA-256
checksums and resumes interrupted package downloads. A private GitHub download
uses your existing GitHub CLI login or asks for a token with Contents: Read-only
access to this repository. Token input is hidden; saving it in Windows Credential
Manager is optional. Never put a token in a project, script or issue.

Wait for READY. Prepare opens the installed project folder. In Delphi 13.2, open
the .dproj; in Lazarus 4.8, open the .lpi. Select Windows 64-bit and Release, then
Run. Paths to models, libraries and sample inputs are already in the generated
*.prepared.ini files. Keep the prepared folder together. All distributed Pascal
executables are built with Lazarus; Delphi builds verify source compatibility.

The default installation is %LOCALAPPDATA%/CrossPascal/early-access-016. Models
and downloads are shared between examples. For another drive, set
CROSSPASCAL_PREPARE_HOME before running Prepare.cmd. The download cache is a
sibling downloads folder. Repeating preparation verifies installed dependencies
and preserves changes in editable SDK sources and existing settings. If a fixed
dependency has changed, Prepare stops and asks you to choose a fresh folder.

QwenChat and ImagePrompt use Qwen2.5-VL 3B CPU (about 24 GiB system RAM).
GemmaChat uses Gemma 3n E4B CPU with text and one image (about 32 GiB RAM).
The five other language examples use experimental Gemma 2 2B CPU (about 16 GiB
RAM). These are the accepted EA015 model bytes with their original terms and
documented scope. Downloads are about 5.2 GiB, 11.4 GiB and 3.6 GiB respectively,
plus runtime files. Prepare checks disk space before extraction. The model terms
are retained beside each bundle; use of Gemma and Qwen remains subject to them.

In either chat, click Load model and Generate. Auto (0) runs until the model ends
its response or reaches its context capacity; Stop remains available. The six
console examples run from their prepared settings without IDE arguments.
VisionModels opens a sample image and lets you choose any of five prepared CPU
profiles, then Run on CPU. MarkerLite opens a sample image for its image actions.
LoadResizeSave writes a resized image to the SDK results folder. CrossCVHello
and LeptonicaHello print a small native-library check.

GPU conversion remains available through CrossPascalConvert.exe. Let the wizard
detect the GPU architecture or choose it manually; use the bundle built for that
architecture. CPU preparation does not install a CUDA toolchain. See the existing
model documentation for inference scope, conversion dependencies and limitations.
