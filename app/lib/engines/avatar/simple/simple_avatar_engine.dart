import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../../domain/interfaces/avatar_engine.dart';
import '../../../domain/models/video_frame.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/motion_data.dart';
import '../../../domain/models/avatar.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';

/// A non-ML avatar engine: takes your designed avatar image and drives it
/// with cheap 2D transforms — rotation from head yaw, a vertical squash
/// from mouth openness. Deliberately crude; it exists so there's a real,
/// always-available engine that runs on any hardware, not to compete with
/// LivePortrait on quality.
///
/// IMPORTANT: it is only as "live" as the MotionData it's fed. Right now
/// the only motion tracker is MockMotionTracker (a sine wave), so the
/// avatar sways on its own rather than following your face — see the
/// Studio UI's motion line and docs/engines.md.
///
/// Performance notes: the avatar is scaled to the output size once and
/// cached, and frames are returned as RAW BGRA (no PNG/JPEG encode) so the
/// preview can show them via ui.decodeImageFromPixels with no codec.
/// Rotation is still per-frame pure-Dart pixel work on the main isolate;
/// keep the capture resolution modest.
class SimpleAvatarEngine implements AvatarEngine {
  img.Image? _avatarImage;
  img.Image? _scaledBase;
  int _scaledW = 0;
  int _scaledH = 0;

  @override
  String get id => 'simple_avatar';
  @override
  String get name => 'Simple Avatar (2D transform)';

  @override
  AvatarEngineCapabilities get capabilities => const AvatarEngineCapabilities(
        supportsGpu: false,
        supportsCpu: true,
        supportsMotionTransfer: false,
        supportsAudioDrivenLipSync: false,
        supportsRealtime: true,
        recommendedWidth: 640,
        recommendedHeight: 360,
        recommendedFps: 24,
        minimumMemoryMb: 256,
      );

  @override
  Future<void> initialize(EngineConfig config) async {}

  @override
  Future<AvatarPreparationResult> prepareAvatar(AvatarSource source) async {
    try {
      final bytes = await File(source.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return AvatarPreparationResult(
          success: false,
          engineId: id,
          errorMessage: 'Could not decode image at ${source.imagePath}',
        );
      }
      _avatarImage = decoded;
      _scaledBase = null; // force re-scale for the new image
      return AvatarPreparationResult(success: true, engineId: id);
    } catch (e) {
      return AvatarPreparationResult(
        success: false,
        engineId: id,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<void> start() async {}

  @override
  Future<VideoFrame> process(
    VideoFrame sourceFrame,
    MotionData motion,
    AudioFrame? audio,
  ) async {
    final avatar = _avatarImage;
    if (avatar == null) return sourceFrame;

    final w = sourceFrame.width;
    final h = sourceFrame.height;

    // Scale the avatar to the output size once (fit inside, keep aspect
    // ratio, centered on a black canvas) instead of on every frame.
    if (_scaledBase == null || _scaledW != w || _scaledH != h) {
      final fitted = img.copyResize(
        avatar,
        width: avatar.width >= avatar.height ? w : null,
        height: avatar.width >= avatar.height ? null : h,
        interpolation: img.Interpolation.linear,
      );
      final canvas = img.Image(width: w, height: h, numChannels: 4);
      img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 255));
      img.compositeImage(
        canvas,
        fitted,
        dstX: (w - fitted.width) ~/ 2,
        dstY: (h - fitted.height) ~/ 2,
      );
      _scaledBase = canvas;
      _scaledW = w;
      _scaledH = h;
    }

    var frame = _scaledBase!;

    final yaw = motion.head?.yaw ?? 0.0;
    final mouthOpen = motion.mouth?.openness ?? 0.0;

    if (yaw.abs() > 0.5) {
      // copyRotate returns a new image; the cached base is never mutated.
      frame = img.copyRotate(frame, angle: yaw.clamp(-15.0, 15.0));
    }

    if (mouthOpen > 0.05) {
      final squash = 1.0 - (mouthOpen * 0.08).clamp(0.0, 0.2);
      frame = img.copyResize(frame, width: frame.width, height: (frame.height * squash).round());
    }

    // Rotation/squash can change dimensions — normalize back to the
    // pipeline's frame size so every downstream stage sees a constant size.
    if (frame.width != w || frame.height != h) {
      frame = img.copyResize(frame, width: w, height: h);
    }

    final bgra = frame.convert(numChannels: 4).getBytes(order: img.ChannelOrder.bgra);

    return VideoFrame(
      bytes: Uint8List.fromList(bgra),
      width: w,
      height: h,
      format: VideoPixelFormat.bgra8888,
      timestamp: sourceFrame.timestamp,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    _avatarImage = null;
    _scaledBase = null;
  }
}
