# License scope

The [MIT license](../LICENSE) covers original CrossPascal code and documentation. Third-party components keep their own terms. The Binarize and Curve units retain [MPL 1.1](../rtl-algorithms/licenses/MPL-1.1.txt) and their [CrossFPC-Common attribution](../rtl-algorithms/licenses/CROSSFPCCOMMON-NOTICE.md).

| Material | Where to find the applicable terms |
| --- | --- |
| OpenCV bindings and C++ bridge | [OpenCV license and third-party notices](https://github.com/pisarev/crosspascal-opencv/blob/main/THIRD-PARTY-NOTICES.md) |
| OpenCV, contrib, and native codec dependencies | Original notices and license files in the OpenCV companion source asset |
| Leptonica bindings, runtime, and codec dependencies | [Leptonica notices](https://github.com/pisarev/crosspascal-leptonica/blob/main/THIRD-PARTY-NOTICES.md) and its companion source asset |
| Apache TVM, TVM FFI, and DLPack | [TVM notices and setup](https://github.com/pisarev/crosspascal-tvm), the original wheel metadata, and the runtime notices |
| SentencePiece and its dependencies | `runtime/third-party-licenses/sentencepiece` in the Windows SDK |
| GGML dequantization library | [Source and license notes](https://github.com/pisarev/crosspascal-convert/blob/main/licenses/ggml-base.md) |
| Qwen2.5-0.5B-Instruct and tokenizer | Apache 2.0 notices and the exact upstream revision in the TVM runtime source metadata |
| CPU vision inputs | Each model pack's `SOURCE.json` and accompanying license and provenance files |

## OpenCV and FFmpeg

The OpenCV source asset builds the CrossCV DLL with statically linked FFmpeg under LGPL 2.1 or later. The FFmpeg configuration does not enable GPL, version 3, or nonfree code. OpenCV itself is built with `OPENCV_ENABLE_NONFREE=ON`, which is a separate setting.

The companion OpenCV source asset includes FFmpeg, OpenCV and contrib inputs, and the C++ bridge sources. Follow `RELINKING.md` and `Dockerfile.ffmpeg-relink.example` in that asset to rebuild with a modified FFmpeg. It uses a full-source rebuild. The asset does not supply precompiled relink objects.

The Leptonica asset includes its original source archives, codec sources, build configuration, and notices. Preserve the notices when redistributing the matching libraries or sources.

## Supplied language and vision models

| Model | Applicable terms |
| --- | --- |
| Qwen2.5-VL 3B Instruct, used by CPU QwenChat/ImagePrompt | [Qwen Research License](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct/blob/66285546d2b821cf421d4f5eb2576359d3770cd3/LICENSE): non-commercial research and evaluation; commercial use requires a separate license from Alibaba Cloud. Built with Qwen. |
| Gemma 2 and Gemma 3n | [Gemma Terms of Use](https://ai.google.dev/gemma/terms) and [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). Copies, NOTICE, modification records and use/redistribution conditions accompany each supplied bundle. |
| YOLO11n detection and classification | AGPL-3.0 as declared in the source packs. Review [Ultralytics licensing](https://www.ultralytics.com/license) for proprietary deployments. |
| SqueezeNet 1.1, ResNet50 and RT-DETR R18vd | Apache-2.0 as declared by the pinned source packs; keep all additional notices. |
| PP-OCRv5 Server detector and recognizer, used by PaddleOCR | Apache-2.0. The PaddleOCR example also uses Clipper 6.4.2 under the Boost Software License. [Model sources and notices](https://github.com/pisarev/crosspascal/tree/main/examples/paddle-ocr#licenses). |

Gemma use restrictions apply to these model derivatives and must remain enforceable
in onward distribution agreements. Keep all supplied licenses and notices, and mark
your changes. Qwen Research restrictions apply to the named 3B vision-language
checkpoint, not automatically to the separately licensed dense Qwen checkpoints.

The bundled bus photograph retains its upstream Ultralytics source and license.
Replace it with an image you have the right to use for your own application.
The preparation helper uses the public-domain 7zr executable from the
[LZMA SDK](https://www.7-zip.org/sdk.html).
