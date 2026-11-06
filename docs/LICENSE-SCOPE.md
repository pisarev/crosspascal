# License scope

The [MIT license](../LICENSE) covers original CrossPascal code and documentation. Third-party components keep their own terms. The Binarize and Curve units retain [MPL 1.1](../rtl-algorithms/licenses/MPL-1.1.txt) and their [CrossFPC-Common attribution](../rtl-algorithms/licenses/CROSSFPCCOMMON-NOTICE.md).

| Material | Where to find the applicable terms |
| --- | --- |
| OpenCV bindings and C++ bridge | [OpenCV license and third-party notices](https://github.com/pisarev/crosspascal-opencv/blob/main/THIRD-PARTY-NOTICES.md) |
| OpenCV, contrib, and native codec dependencies | Original notices and license files in the OpenCV companion source asset |
| Leptonica bindings, runtime, and codec dependencies | [Leptonica notices](https://github.com/pisarev/crosspascal-leptonica/blob/main/THIRD-PARTY-NOTICES.md) and its companion source asset |
| Apache TVM, TVM FFI, and DLPack | [TVM notices and setup](https://github.com/pisarev/crosspascal-tvm), the original wheel metadata, and the runtime notices |
| Portable Python and its packages | The portable Python license under `runtime/python/` and the license files in the pinned upstream wheels fetched by the installer |
| Qwen2.5-0.5B-Instruct and tokenizer | Apache 2.0 notices and the exact upstream revision in the TVM runtime source metadata |
| CPU vision inputs | Each model pack's `SOURCE.json` and accompanying license and provenance files |

## OpenCV and FFmpeg

The OpenCV source asset builds the CrossCV DLL with statically linked FFmpeg under LGPL 2.1 or later. The FFmpeg configuration does not enable GPL, version 3, or nonfree code. OpenCV itself is built with `OPENCV_ENABLE_NONFREE=ON`, which is a separate setting.

The companion OpenCV source asset includes FFmpeg, OpenCV and contrib inputs, and the C++ bridge sources. Follow `RELINKING.md` and `Dockerfile.ffmpeg-relink.example` in that asset to rebuild with a modified FFmpeg. It uses a full-source rebuild. The asset does not supply precompiled relink objects.

The Leptonica asset includes its original source archives, codec sources, build configuration, and notices. Preserve the notices when redistributing the matching libraries or sources.
