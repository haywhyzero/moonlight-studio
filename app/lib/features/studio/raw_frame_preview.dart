import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/video_frame.dart';

/// Renders a VideoFrame with the minimum possible decode cost.
///
/// For raw pixel buffers (VideoPixelFormat.bgra8888/rgba8888 — what the
/// capture pipeline produces directly, and what MockAvatarEngine passes
/// through unchanged) this uses ui.decodeImageFromPixels, which builds a
/// GPU-backed ui.Image straight from the pixel bytes with NO PNG/JPEG
/// encode or decode involved at all. That round trip (encode to a
/// compressed format just so Image.memory could decode it again) was a
/// real, avoidable cost on the hot path — this removes it for the common
/// case.
///
/// For already-encoded frames (VideoPixelFormat.encodedPng, as produced by
/// SimpleAvatarEngine/LivePortrait/etc, which return actual image files,
/// not raw buffers) this falls back to ui.instantiateImageCodec, which is
/// the only correct way to decode a compressed format — unavoidable for
/// those engines, but not paid for the raw passthrough path.
class RawFramePreview extends StatefulWidget {
  final Stream<VideoFrame> frames;
  const RawFramePreview({super.key, required this.frames});

  @override
  State<RawFramePreview> createState() => _RawFramePreviewState();
}

class _RawFramePreviewState extends State<RawFramePreview> {
  ui.Image? _image;
  StreamSubscription<VideoFrame>? _sub;
  bool _decoding = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.frames.listen(_onFrame);
  }

  @override
  void didUpdateWidget(covariant RawFramePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing engine settings rebuilds the StudioSession (and therefore
    // its preview stream). Without this, the widget would keep listening
    // to the old, closed stream and the preview would silently go dead.
    if (oldWidget.frames != widget.frames) {
      _sub?.cancel();
      _sub = widget.frames.listen(_onFrame);
    }
  }

  void _onFrame(VideoFrame frame) {
    // Same drop-if-busy principle as CapturePipeline: never let decode
    // work queue up behind itself — always work on the latest frame.
    if (_decoding) return;
    _decoding = true;
    _decode(frame).then((image) {
      _decoding = false;
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _image;
      setState(() => _image = image);
      old?.dispose();
    }).catchError((_) {
      _decoding = false;
    });
  }

  Future<ui.Image> _decode(VideoFrame frame) {
    switch (frame.format) {
      case VideoPixelFormat.bgra8888:
        return _decodeRaw(frame, ui.PixelFormat.bgra8888);
      case VideoPixelFormat.rgba8888:
        return _decodeRaw(frame, ui.PixelFormat.rgba8888);
      case VideoPixelFormat.encodedPng:
        return _decodeCompressed(frame);
      case VideoPixelFormat.nv12:
      case VideoPixelFormat.yuv420:
        throw UnsupportedError('${frame.format} preview decoding not implemented yet');
    }
  }

  Future<ui.Image> _decodeRaw(VideoFrame frame, ui.PixelFormat format) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      frame.bytes,
      frame.width,
      frame.height,
      format,
      completer.complete,
      rowBytes: frame.width * 4,
    );
    return completer.future;
  }

  Future<ui.Image> _decodeCompressed(VideoFrame frame) async {
    final codec = await ui.instantiateImageCodec(frame.bytes);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Icon(Icons.videocam_off_outlined, size: 40, color: Colors.white38);
    }
    return RawImage(image: _image, fit: BoxFit.contain);
  }
}
