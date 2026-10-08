import 'dart:async';
import 'camera/ffmpeg_camera_capture.dart';
import 'audio/ffmpeg_audio_capture.dart';
import '../domain/pipeline/studio_session.dart';

/// Owns the actual FFmpeg capture processes and feeds their output into a
/// StudioSession. This is the piece that was missing before: engines were
/// wired to each other, but nothing was ever calling
/// session.processVideoFrame/processAudioFrame with real camera/mic data.
class CapturePipeline {
  final StudioSession session;
  final String cameraDeviceName;
  final String microphoneDeviceName;

  FfmpegCameraCapture? _camera;
  FfmpegAudioCapture? _mic;
  StreamSubscription? _videoSub;
  StreamSubscription? _audioSub;

  CapturePipeline({
    required this.session,
    required this.cameraDeviceName,
    required this.microphoneDeviceName,
  });

  Future<void> start() async {
    _camera = FfmpegCameraCapture(deviceName: cameraDeviceName);
    _mic = FfmpegAudioCapture(deviceName: microphoneDeviceName);

    await _camera!.start();
    await _mic!.start();

    // Backpressure: Stream.listen fires this callback for every incoming
    // frame regardless of whether the previous call finished, so without
    // a gate here, a downstream stage slower than the capture rate causes
    // an ever-growing backlog of in-flight frames — which is exactly what
    // was showing up as latency climbing over time rather than settling.
    // Dropping a frame outright (never queuing it) is the fix, per the
    // "drop old frames, don't let latency grow unbounded" rule in
    // docs/architecture.md — this just actually implements it now.
    var videoBusy = false;
    _videoSub = _camera!.frames.listen(
      (frame) {
        if (videoBusy) return; // drop — downstream is still busy with a previous frame
        videoBusy = true;
        session.processVideoFrame(frame).whenComplete(() => videoBusy = false);
      },
      onError: (e) => print('[CapturePipeline] camera error: $e'),
    );

    // Audio frames are small (a few KB) and cheap to process compared to
    // video, so they're not gated the same way — dropping audio would be
    // audible glitching, whereas dropping a video frame is invisible.
    _audioSub = _mic!.frames.listen(
      session.processAudioFrame,
      onError: (e) => print('[CapturePipeline] mic error: $e'),
    );
  }

  Future<void> stop() async {
    await _videoSub?.cancel();
    await _audioSub?.cancel();
    await _camera?.dispose();
    await _mic?.dispose();
    _camera = null;
    _mic = null;
  }
}
