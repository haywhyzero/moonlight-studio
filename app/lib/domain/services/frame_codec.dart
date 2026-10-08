import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/video_frame.dart';

/// Shared raw-pixel-buffer <-> PNG conversion, used by both the
/// Compositor and any adapter (LivePortraitEngine, MuseTalkEngine,
/// Wav2LipEngine) that needs to send a frame to a Python worker over the
/// wire, where the protocol contract is "payload_b64 is always PNG" (see
/// python/common/protocol/messages.py).
class FrameCodec {
  static img.Image? decode(VideoFrame frame) {
    switch (frame.format) {
      case VideoPixelFormat.encodedPng:
        return img.decodeImage(frame.bytes);
      case VideoPixelFormat.bgra8888:
        return img.Image.fromBytes(
          width: frame.width,
          height: frame.height,
          bytes: frame.bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      case VideoPixelFormat.rgba8888:
        return img.Image.fromBytes(
          width: frame.width,
          height: frame.height,
          bytes: frame.bytes.buffer,
          order: img.ChannelOrder.rgba,
        );
      case VideoPixelFormat.nv12:
      case VideoPixelFormat.yuv420:
        return null; // not implemented yet — see Compositor's note
    }
  }

  /// Returns PNG bytes for [frame] regardless of its current format.
  /// Frames already tagged encodedPng are returned as-is (no re-encode).
  static Uint8List toPngBytes(VideoFrame frame) {
    if (frame.format == VideoPixelFormat.encodedPng) return frame.bytes;
    final decoded = decode(frame);
    if (decoded == null) {
      throw StateError('FrameCodec.toPngBytes: cannot decode frame with format ${frame.format}');
    }
    return Uint8List.fromList(img.encodePng(decoded));
  }
}
