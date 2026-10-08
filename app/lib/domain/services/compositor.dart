import 'dart:isolate';
import 'package:image/image.dart' as img;
import '../models/video_frame.dart';
import 'frame_codec.dart';

/// CURRENTLY NOT CALLED FROM THE LIVE PIPELINE. StudioSession.processVideoFrame
/// deliberately skips this stage for now to get the raw capture pipeline
/// running smoothly first (per explicit direction) — see that class's doc
/// comment. Kept here, working and isolate-backed, to be wired back in
/// once the base pipeline is confirmed solid. If you're wondering why no
/// watermark shows up in the preview right now, this is why.
///
/// Final stage before a frame reaches local preview / the virtual camera.
///
/// Always burns in a small "Moonlight Studio" watermark, bottom-right.
/// This is intentionally NOT a toggleable setting: the app's output is a
/// synthetic/transformed avatar feed, and every frame that leaves this
/// process should carry a visible indicator of that regardless of which
/// avatar/lip-sync/voice engine produced it.
///
/// Handles BOTH kinds of frame the pipeline can hand it: raw pixel buffers
/// (VideoPixelFormat.bgra8888/rgba8888, as produced directly by
/// FfmpegCameraCapture or a passthrough engine like MockAvatarEngine) and
/// already-encoded bytes (VideoPixelFormat.encodedPng, as produced by
/// SimpleAvatarEngine/LivePortraitEngine/etc — img.decodeImage sniffs the
/// actual format from the file header, so a PNG-tagged frame from those
/// engines still decodes fine here even though this class's own output is
/// JPEG, not PNG — see the encode call below for why).
class Compositor {
  static const String _label = 'Moonlight Studio';

  /// Runs the actual (CPU-heavy) compositing work on a throwaway background
  /// isolate via Isolate.run, instead of on the calling isolate directly.
  ///
  /// This matters beyond raw speed: Flutter's main isolate is also what
  /// drains the ffmpeg capture pipe and renders the UI. Running decode +
  /// watermark + JPEG-encode synchronously on that isolate blocks BOTH —
  /// which is what was causing ffmpeg's own dshow buffer to overflow
  /// ("real-time buffer ... too full") even after the drop-if-busy fix in
  /// CapturePipeline: dropping frames earlier doesn't help if the one
  /// frame that IS being processed still freezes the thread responsible
  /// for reading fresh ones.
  ///
  /// Caveat, stated plainly: Isolate.run spawns and tears down a new
  /// isolate on every call, which has its own (much smaller, low-single-
  /// digit-ms) overhead. At 24-30fps that's an acceptable trade for no
  /// longer blocking the main isolate, but a persistent worker isolate
  /// (spawned once, fed frames over a SendPort) would be more efficient
  /// still if this needs further tuning later.
  static Future<VideoFrame> applyInBackground(VideoFrame frame) {
    return Isolate.run(() => _apply(frame));
  }

  /// Synchronous version, kept for callers that explicitly want to run on
  /// the calling isolate (e.g. tests).
  VideoFrame apply(VideoFrame frame) => _apply(frame);

  static VideoFrame _apply(VideoFrame frame) {
    final decoded = _decode(frame);
    if (decoded == null) return frame;

    _drawWatermark(decoded);

    // JPEG, not PNG: the `image` package's PNG encoder is pure-Dart
    // deflate compression, which is far too slow for real-time 720p/30fps
    // (this was the dominant source of the CPU/latency blowup — PNG encode
    // alone could take several hundred ms per frame). JPEG's DCT-based
    // compression is much cheaper to compute even in pure Dart. Quality
    // 85 is a reasonable speed/visual-quality tradeoff for a live preview
    // feed; lower it further if CPU is still the bottleneck on your machine.
    final encoded = img.encodeJpg(decoded, quality: 85);
    return VideoFrame(
      bytes: encoded,
      width: frame.width,
      height: frame.height,
      format: VideoPixelFormat.encodedPng,
      timestamp: frame.timestamp,
    );
  }

  static img.Image? _decode(VideoFrame frame) {
    final decoded = FrameCodec.decode(frame);
    if (decoded == null) {
      // ignore: avoid_print
      print('[Compositor] ${frame.format} decoding not implemented yet.');
    }
    return decoded;
  }

  static void _drawWatermark(img.Image image) {
    final fontSize = (image.width * 0.022).clamp(12, 28).toInt();
    final font = img.arial24;
    final textWidth = _label.length * (fontSize * 0.6).toInt();
    final padding = 12;

    final x = image.width - textWidth - padding;
    final y = image.height - fontSize - padding;

    // Subtle translucent backing so the watermark stays legible on any
    // background without dominating the frame.
    img.fillRect(
      image,
      x1: x - 8,
      y1: y - 6,
      x2: image.width - padding + 8,
      y2: image.height - padding + 6,
      color: img.ColorRgba8(10, 10, 20, 120),
    );

    img.drawString(
      image,
      _label,
      font: font,
      x: x,
      y: y,
      color: img.ColorRgba8(220, 225, 255, 230),
    );
  }
}
