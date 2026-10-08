import '../models/video_frame.dart';
import '../models/audio_frame.dart';
import '../models/motion_data.dart';
import '../models/avatar.dart';
import '../models/engine_capabilities.dart';
import '../models/engine_config.dart';

/// Drives a prepared avatar image using tracked motion (and optionally
/// audio, for engines with built-in lip movement).
///
/// The rest of the application (Studio UI, StudioSession, Compositor) must
/// only ever depend on this interface — never on a concrete engine like
/// LivePortraitEngine. See docs/adding-an-engine.md before adding a new one.
abstract class AvatarEngine {
  String get id;
  String get name;

  AvatarEngineCapabilities get capabilities;

  Future<void> initialize(EngineConfig config);

  /// Runs (possibly expensive) per-avatar preprocessing. Cache the result
  /// keyed by this engine's [id] — never write it back onto [Avatar] itself.
  Future<AvatarPreparationResult> prepareAvatar(AvatarSource source);

  Future<void> start();

  /// Produces one output frame given the prepared avatar, this frame's
  /// tracked motion, and optionally synced audio.
  Future<VideoFrame> process(
    VideoFrame sourceFrame,
    MotionData motion,
    AudioFrame? audio,
  );

  Future<void> stop();
  Future<void> dispose();
}
