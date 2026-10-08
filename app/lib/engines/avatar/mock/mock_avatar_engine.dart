import '../../../domain/interfaces/avatar_engine.dart';
import '../../../domain/models/video_frame.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/motion_data.dart';
import '../../../domain/models/avatar.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';

/// Passes the source frame straight through. Used for development-mode
/// pipeline testing and as a fallback when no real avatar engine is
/// installed/configured. Runs on any hardware, including 4GB/no-GPU boxes.
class MockAvatarEngine implements AvatarEngine {
  @override
  String get id => 'mock_avatar';
  @override
  String get name => 'Mock Avatar (passthrough)';

  @override
  AvatarEngineCapabilities get capabilities => const AvatarEngineCapabilities(
        supportsGpu: false,
        supportsCpu: true,
        supportsMotionTransfer: false,
        supportsAudioDrivenLipSync: false,
        supportsRealtime: true,
        recommendedWidth: 1280,
        recommendedHeight: 720,
        recommendedFps: 30,
        minimumMemoryMb: 256,
      );

  @override
  Future<void> initialize(EngineConfig config) async {}

  @override
  Future<AvatarPreparationResult> prepareAvatar(AvatarSource source) async {
    return AvatarPreparationResult(success: true, engineId: id);
  }

  @override
  Future<void> start() async {}

  @override
  Future<VideoFrame> process(
    VideoFrame sourceFrame,
    MotionData motion,
    AudioFrame? audio,
  ) async {
    return sourceFrame;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
