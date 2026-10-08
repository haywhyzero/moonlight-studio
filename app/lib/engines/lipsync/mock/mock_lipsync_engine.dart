import '../../../domain/interfaces/lip_sync_engine.dart';
import '../../../domain/models/video_frame.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';

class MockLipSyncEngine implements LipSyncEngine {
  @override
  String get id => 'mock_lipsync';
  @override
  String get name => 'Mock Lip Sync (no-op)';

  @override
  LipSyncCapabilities get capabilities => const LipSyncCapabilities(
        supportsGpu: false,
        supportsCpu: true,
        supportsRealtime: true,
        recommendedFps: 30,
        minimumMemoryMb: 64,
      );

  @override
  Future<void> initialize(EngineConfig config) async {}

  @override
  Future<VideoFrame> process(VideoFrame frame, AudioFrame audio) async => frame;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
