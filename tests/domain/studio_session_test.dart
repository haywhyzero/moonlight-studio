import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight_studio/domain/services/engine_registry.dart';
import 'package:moonlight_studio/domain/pipeline/pipeline_config.dart';
import 'package:moonlight_studio/domain/pipeline/studio_session.dart';
import 'package:moonlight_studio/domain/models/video_frame.dart';
import 'package:moonlight_studio/domain/models/engine_config.dart';
import 'package:moonlight_studio/engines/motion/mock/mock_motion_tracker.dart';
import 'package:moonlight_studio/engines/avatar/mock/mock_avatar_engine.dart';
import 'package:moonlight_studio/engines/voice/mock/mock_voice_engine.dart';


PipelineConfig _mockConfig() => const PipelineConfig(
      motionTrackerId: 'mock_motion',
      avatarEngineId: 'mock_avatar',
      voiceEngineId: 'mock_voice',
      virtualCameraProviderId: 'obs_virtual_camera',
      virtualMicrophoneProviderId: 'virtual_audio_cable',
    );

EngineRegistry _mockRegistry() {
  final r = EngineRegistry();
  r.registerMotionTracker(MockMotionTracker());
  r.registerAvatarEngine(MockAvatarEngine());
  r.registerVoiceEngine(MockVoiceEngine());
  return r;
}

void main() {
  group('StudioSession', () {
    test('starts and stops using only mock engines', () async {
      final session = StudioSession(
        registry: _mockRegistry(),
        config: _mockConfig(),
      );
      await session.start();
      expect(session.isRunning, isTrue);
      await session.stop();
      expect(session.isRunning, isFalse);
    });

    test('throws a clear error if a configured engine id is not registered', () {
      final session = StudioSession(
        registry: EngineRegistry(), // nothing registered
        config: _mockConfig(),
      );
      expect(() => session.start(), throwsA(isA<StateError>()));
    });

    test('processVideoFrame emits a frame on the preview stream', () async {
      final session = StudioSession(
        registry: _mockRegistry(),
        config: _mockConfig(),
      );
      await session.start();

      final frames = <VideoFrame>[];
      final sub = session.previewController.stream.listen(frames.add);

      // Content doesn't matter here — the compositor is currently not in
      // this path (see StudioSession's doc comment), so processVideoFrame
      // just needs any frame to pass through to the preview stream.
      final bmp = _tinyBmp();
      await session.processVideoFrame(VideoFrame(
        bytes: bmp,
        width: 2,
        height: 2,
        format: VideoPixelFormat.bgra8888,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(frames, isNotEmpty);
      await sub.cancel();
      await session.stop();
    });
    test('start() actually initializes every engine, not just virtual devices', () async {
      // Regression test: an earlier version called initialize() on the
      // virtual camera/mic but never on the motion tracker, avatar, or
      // voice engine — meaning worker-backed engines (LivePortrait,
      // MuseTalk, Wav2Lip, VoiceClone) never actually spawned their
      // Python process or opened an IPC connection, regardless of
      // whether weights were installed. This pins the fix.
      final motion = _InitTrackingMotionTracker();
      final avatar = _InitTrackingAvatarEngine();
      final voice = _InitTrackingVoiceEngine();
      final registry = EngineRegistry()
        ..registerMotionTracker(motion)
        ..registerAvatarEngine(avatar)
        ..registerVoiceEngine(voice);

      final session = StudioSession(registry: registry, config: _mockConfig());
      await session.start();

      expect(motion.initialized, isTrue);
      expect(avatar.initialized, isTrue);
      expect(voice.initialized, isTrue);

      await session.stop();
    });
  });
}

class _InitTrackingMotionTracker extends MockMotionTracker {
  bool initialized = false;
  @override
  Future<void> initialize(EngineConfig config) async {
    initialized = true;
    await super.initialize(config);
  }
}

class _InitTrackingAvatarEngine extends MockAvatarEngine {
  bool initialized = false;
  @override
  Future<void> initialize(EngineConfig config) async {
    initialized = true;
    await super.initialize(config);
  }
}

class _InitTrackingVoiceEngine extends MockVoiceEngine {
  bool initialized = false;
  @override
  Future<void> initialize(EngineConfig config) async {
    initialized = true;
    await super.initialize(config);
  }
}

// Minimal valid 2x2 24-bit BMP, used only so image.decodeImage() succeeds
// in the compositor test above without shipping a binary fixture file.
List<int> _tinyBmp() {
  const width = 2, height = 2;
  const rowSize = ((24 * width + 31) ~/ 32) * 4;
  const pixelDataSize = rowSize * height;
  const fileSize = 54 + pixelDataSize;
  final bytes = List<int>.filled(fileSize, 0);

  void writeU16(int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
  }

  void writeU32(int offset, int value) {
    bytes[offset] = value & 0xFF;
    bytes[offset + 1] = (value >> 8) & 0xFF;
    bytes[offset + 2] = (value >> 16) & 0xFF;
    bytes[offset + 3] = (value >> 24) & 0xFF;
  }

  bytes[0] = 0x42; // 'B'
  bytes[1] = 0x4D; // 'M'
  writeU32(2, fileSize);
  writeU32(10, 54);
  writeU32(14, 40);
  writeU32(18, width);
  writeU32(22, height);
  writeU16(26, 1);
  writeU16(28, 24);
  writeU32(34, pixelDataSize);

  for (var i = 54; i < fileSize; i += 3) {
    bytes[i] = 0;
    bytes[i + 1] = 0;
    bytes[i + 2] = 200;
  }

  return bytes;
}
