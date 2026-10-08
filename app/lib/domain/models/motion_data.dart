/// Engine-independent representation of tracked motion for one frame.
///
/// Every MotionTracker implementation must normalize its output into this
/// shape. Avatar/LipSync engines consume MotionData, never a tracker's
/// native output type.
class MotionData {
  final FaceMotion? face;
  final PoseMotion? pose;
  final HandMotion? hands;
  final EyeMotion? eyes;
  final MouthMotion? mouth;
  final HeadPose? head;
  final DateTime timestamp;

  const MotionData({
    this.face,
    this.pose,
    this.hands,
    this.eyes,
    this.mouth,
    this.head,
    required this.timestamp,
  });

  static MotionData empty(DateTime timestamp) => MotionData(timestamp: timestamp);
}

class FaceMotion {
  final List<double> landmarks2d; // flattened x,y pairs, normalized 0..1
  final double confidence;
  const FaceMotion({required this.landmarks2d, required this.confidence});
}

class PoseMotion {
  final List<double> keypoints;
  const PoseMotion({required this.keypoints});
}

class HandMotion {
  final List<double>? left;
  final List<double>? right;
  const HandMotion({this.left, this.right});
}

class EyeMotion {
  final double leftOpenness;
  final double rightOpenness;
  final double gazeX;
  final double gazeY;
  const EyeMotion({
    required this.leftOpenness,
    required this.rightOpenness,
    required this.gazeX,
    required this.gazeY,
  });
}

class MouthMotion {
  final double openness;
  final double width;
  const MouthMotion({required this.openness, required this.width});
}

class HeadPose {
  final double yaw;
  final double pitch;
  final double roll;
  const HeadPose({required this.yaw, required this.pitch, required this.roll});
}
