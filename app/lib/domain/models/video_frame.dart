import 'dart:typed_data';

/// A single decoded video frame passed between pipeline stages.
///
/// Kept engine-independent: raw pixels + format metadata only.
/// No engine may attach its own fields here — see AvatarPreparationResult
/// for where engine-specific data belongs.
class VideoFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final VideoPixelFormat format;
  final DateTime timestamp;

  const VideoFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.timestamp,
  });

  VideoFrame copyWith({Uint8List? bytes}) => VideoFrame(
        bytes: bytes ?? this.bytes,
        width: width,
        height: height,
        format: format,
        timestamp: timestamp,
      );
}

enum VideoPixelFormat { bgra8888, rgba8888, nv12, yuv420, encodedPng }
