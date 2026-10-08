import '../models/video_frame.dart';

/// Publishes processed frames to a normal, OS-level selectable camera
/// device that other applications (Discord, Zoom, Meet, OBS) pick up
/// exactly like a physical webcam. Never bypasses another application's
/// own security boundary — this only ever exposes a standard virtual
/// input device that the user explicitly selects on the other end.
abstract class VirtualCameraProvider {
  String get id;

  Future<void> initialize();
  Future<void> start();
  Future<void> pushFrame(VideoFrame frame);
  Future<void> stop();
  Future<void> dispose();
}
