import 'dart:math';
import '../../../domain/interfaces/motion_tracker.dart';
import '../../../domain/models/video_frame.dart';
import '../../../domain/models/motion_data.dart';
import '../../../domain/models/engine_config.dart';

/// Deterministic-ish fake motion so the UI/pipeline can be exercised and
/// tested without MediaPipe or any camera-vision dependency installed.
class MockMotionTracker implements MotionTracker {
  @override
  String get id => 'mock_motion';
  @override
  String get name => 'Mock Motion Tracker';

  final _rand = Random(42);

  @override
  Future<void> initialize(EngineConfig config) async {}

  @override
  Future<MotionData> process(VideoFrame frame) async {
    final t = frame.timestamp.millisecondsSinceEpoch / 1000.0;
    return MotionData(
      face: FaceMotion(landmarks2d: const [], confidence: 1.0),
      mouth: MouthMotion(
        openness: (sin(t * 2) + 1) / 2 * 0.4,
        width: 0.5,
      ),
      eyes: EyeMotion(
        leftOpenness: 1.0,
        rightOpenness: 1.0,
        gazeX: 0,
        gazeY: 0,
      ),
      head: HeadPose(
        yaw: sin(t * 0.5) * 5,
        pitch: cos(t * 0.3) * 2,
        roll: 0,
      ),
      timestamp: frame.timestamp,
    );
  }

  @override
  Future<void> dispose() async {}
}
