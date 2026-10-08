import '../models/video_frame.dart';
import '../models/motion_data.dart';
import '../models/engine_config.dart';

/// Turns raw camera frames into engine-independent MotionData.
///
/// Implementations: engines/motion/mediapipe (real), engines/motion/mock
/// (deterministic fake data for UI dev without any AI installed).
abstract class MotionTracker {
  String get id;
  String get name;

  Future<void> initialize(EngineConfig config);
  Future<MotionData> process(VideoFrame frame);
  Future<void> dispose();
}
