import '../../../domain/interfaces/voice_engine.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';

class MockVoiceEngine implements VoiceEngine {
  @override
  String get id => 'mock_voice';
  @override
  String get name => 'Mock Voice (passthrough)';

  @override
  VoiceEngineCapabilities get capabilities => const VoiceEngineCapabilities(
        isRealtime: true,
        requiresReferenceAudio: false,
        recommendedSampleRate: 48000,
      );

  @override
  Future<void> initialize(EngineConfig config) async {}

  @override
  Future<AudioFrame> process(AudioFrame input) async => input;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
