import '../models/audio_frame.dart';

/// Publishes processed audio to a normal, OS-level selectable microphone
/// device. See VirtualCameraProvider for the equivalent contract on video.
abstract class VirtualMicrophoneProvider {
  String get id;

  Future<void> initialize();
  Future<void> start();
  Future<void> pushAudio(AudioFrame frame);
  Future<void> stop();
  Future<void> dispose();
}
