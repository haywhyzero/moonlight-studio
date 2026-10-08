import 'dart:async';
import '../interfaces/motion_tracker.dart';
import '../interfaces/avatar_engine.dart';
import '../interfaces/lip_sync_engine.dart';
import '../interfaces/voice_engine.dart';
import '../interfaces/virtual_camera_provider.dart';
import '../interfaces/virtual_microphone_provider.dart';
import '../models/video_frame.dart';
import '../models/audio_frame.dart';
import '../models/motion_data.dart';
import '../models/avatar.dart';
import '../models/engine_config.dart';
import '../services/engine_registry.dart';
import '../../core/performance/metrics_collector.dart';
import 'pipeline_config.dart';

/// Owns the live pipeline for one studio run.
///
/// Lifecycle: start() initializes every selected engine (spawning Python
/// workers where needed), stop() tears them all down again — engines are
/// initialized fresh on every start, so changing settings between runs
/// always takes effect.
///
/// Frame flow (see docs/architecture.md):
///   camera -> motionTracker -> avatarEngine -> [lipSyncEngine] -> preview
///   mic -> voiceEngine -> local monitor + virtualMicrophone
///
/// The watermark/compositor stage is deliberately out of this path for
/// now — see Compositor's doc comment.
class StudioSession {
  final EngineRegistry registry;
  PipelineConfig config;

  MotionTracker? _motionTracker;
  AvatarEngine? _avatarEngine;
  LipSyncEngine? _lipSyncEngine;
  VoiceEngine? _voiceEngine;
  VirtualCameraProvider? _virtualCamera;
  VirtualMicrophoneProvider? _virtualMicrophone;

  final StreamController<VideoFrame> previewController =
      StreamController<VideoFrame>.broadcast();
  final MetricsCollector metrics = MetricsCollector();
  AudioFrame? _latestAudioFrame;

  bool _running = false;
  bool get isRunning => _running;

  StudioSession({required this.registry, required this.config});

  EngineConfig _settingsFor(String engineId) =>
      EngineConfig(config.engineSettings[engineId] ?? const {});

  /// Initializes and starts every engine in the configured pipeline.
  /// [avatarImagePath] is handed to the avatar engine's prepareAvatar().
  /// Throws (with a human-readable message) if any engine fails — on
  /// failure everything already started is torn down again.
  Future<void> start({String? avatarImagePath}) async {
    _motionTracker = registry.getMotionTracker(config.motionTrackerId);
    _avatarEngine = registry.getAvatarEngine(config.avatarEngineId);
    _lipSyncEngine = config.lipSyncEngineId == null
        ? null
        : registry.getLipSyncEngine(config.lipSyncEngineId!);
    _voiceEngine = registry.getVoiceEngine(config.voiceEngineId);
    _virtualCamera = registry.getVirtualCamera(config.virtualCameraProviderId);
    _virtualMicrophone =
        registry.getVirtualMicrophone(config.virtualMicrophoneProviderId);

    if (_motionTracker == null || _avatarEngine == null || _voiceEngine == null) {
      throw StateError(
        'One or more configured engine ids are not registered. '
        'Check EngineRegistry registrations at app startup.',
      );
    }

    try {
      await _motionTracker!.initialize(_settingsFor(config.motionTrackerId));

      await _avatarEngine!.initialize(_settingsFor(config.avatarEngineId));
      if (avatarImagePath != null) {
        final prep = await _avatarEngine!.prepareAvatar(
          AvatarSource(imagePath: avatarImagePath),
        );
        if (!prep.success) {
          throw StateError(prep.errorMessage ?? 'Avatar preparation failed.');
        }
      }
      await _avatarEngine!.start();

      await _lipSyncEngine?.initialize(_settingsFor(config.lipSyncEngineId!));
      await _voiceEngine!.initialize(_settingsFor(config.voiceEngineId));

      await _virtualCamera?.initialize();
      await _virtualCamera?.start();
      await _virtualMicrophone?.initialize();
      await _virtualMicrophone?.start();
    } catch (_) {
      await _teardownEngines();
      rethrow;
    }

    metrics.start();
    _running = true;
  }

  /// Called once per captured camera frame (CapturePipeline holds the
  /// drop-if-busy gate — this assumes it isn't re-entered concurrently).
  Future<void> processVideoFrame(VideoFrame frame) async {
    if (!_running || _avatarEngine == null || _motionTracker == null) return;

    final MotionData motion = await _motionTracker!.process(frame);
    VideoFrame output = await _avatarEngine!.process(frame, motion, null);

    if (_lipSyncEngine != null && _latestAudioFrame != null) {
      output = await _lipSyncEngine!.process(output, _latestAudioFrame!);
    }

    metrics.recordFrame(frame.timestamp);
    previewController.add(output);
    await _virtualCamera?.pushFrame(output);
  }

  Future<AudioFrame> processAudioFrame(AudioFrame frame) async {
    if (!_running || _voiceEngine == null) return frame;
    _latestAudioFrame = frame;
    final out = await _voiceEngine!.process(frame);
    await _virtualMicrophone?.pushAudio(out);
    return out;
  }

  Future<void> _teardownEngines() async {
    // Each step is guarded individually so one failing dispose can't
    // leave the others (and their Python worker processes) running.
    Future<void> safe(Future<void>? Function() step) async {
      try {
        await step();
      } catch (_) {}
    }

    await safe(() => _avatarEngine?.stop());
    await safe(() => _lipSyncEngine?.stop());
    await safe(() => _voiceEngine?.stop());
    await safe(() => _virtualCamera?.stop());
    await safe(() => _virtualMicrophone?.stop());

    await safe(() => _motionTracker?.dispose());
    await safe(() => _avatarEngine?.dispose());
    await safe(() => _lipSyncEngine?.dispose());
    await safe(() => _voiceEngine?.dispose());
    await safe(() => _virtualCamera?.dispose());
    await safe(() => _virtualMicrophone?.dispose());
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    metrics.stop();
    await _teardownEngines();
  }

  Future<void> dispose() async {
    await stop();
    metrics.dispose();
    await previewController.close();
  }
}
