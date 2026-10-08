import '../models/audio_frame.dart';
import '../models/engine_capabilities.dart';
import '../models/engine_config.dart';

/// Transforms live microphone audio. v1 implementations are DSP-based
/// real-time effects (pitch/formant/robot/radio/echo) — never represent
/// these as "AI voice cloning". Voice-clone/conversion engines are a
/// distinct future implementation of this same interface.
abstract class VoiceEngine {
  String get id;
  String get name;

  VoiceEngineCapabilities get capabilities;

  Future<void> initialize(EngineConfig config);
  Future<AudioFrame> process(AudioFrame input);
  Future<void> stop();
  Future<void> dispose();
}
