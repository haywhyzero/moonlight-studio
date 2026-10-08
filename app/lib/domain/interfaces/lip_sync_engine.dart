import '../models/video_frame.dart';
import '../models/audio_frame.dart';
import '../models/engine_capabilities.dart';
import '../models/engine_config.dart';

/// Optional pipeline stage that refines mouth movement using audio.
/// A pipeline may skip this stage entirely (see docs/engines.md — do not
/// chain avatar + lip-sync engines unless the user's pipeline asks for it).
abstract class LipSyncEngine {
  String get id;
  String get name;

  LipSyncCapabilities get capabilities;

  Future<void> initialize(EngineConfig config);
  Future<VideoFrame> process(VideoFrame frame, AudioFrame audio);
  Future<void> stop();
  Future<void> dispose();
}
