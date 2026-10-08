import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/bootstrap.dart';
import '../../domain/services/engine_registry.dart';
import '../../domain/pipeline/pipeline_config.dart';
import '../../domain/pipeline/studio_session.dart';
import '../../core/performance/metrics_collector.dart';
import '../../infrastructure/camera/camera_source.dart';
import '../../infrastructure/camera/ffmpeg_camera_discovery.dart';
import '../../infrastructure/audio/audio_source.dart';
import '../../infrastructure/audio/ffmpeg_audio_discovery.dart';
import '../../infrastructure/capture_pipeline.dart';

final engineRegistryProvider = Provider<EngineRegistry>((ref) => buildEngineRegistry());

final pipelineConfigProvider = StateProvider<PipelineConfig>(
  (ref) => PipelineConfig.developmentDefault(),
);

final studioSessionProvider = Provider<StudioSession>((ref) {
  final session = StudioSession(
    registry: ref.watch(engineRegistryProvider),
    config: ref.watch(pipelineConfigProvider),
  );
  ref.onDispose(() => session.dispose());
  return session;
});

enum StudioStatus { idle, starting, running, stopping, error }

final studioStatusProvider = StateProvider<StudioStatus>((ref) => StudioStatus.idle);

/// Real device enumeration (see FfmpegCameraDiscovery/FfmpegAudioDiscovery)
/// — no longer a static hint string. Requires ffmpeg on PATH; if it's
/// missing, the FutureProvider surfaces the error and the UI shows it
/// rather than an empty-but-silent dropdown.
final cameraDevicesProvider = FutureProvider<List<CameraDevice>>(
  (ref) => const FfmpegCameraDiscovery().list(),
);

final audioDevicesProvider = FutureProvider<List<AudioDevice>>(
  (ref) => const FfmpegAudioDiscovery().list(),
);

final selectedCameraProvider = StateProvider<CameraDevice?>((ref) => null);
final selectedMicrophoneProvider = StateProvider<AudioDevice?>((ref) => null);
final selectedAvatarPathProvider = StateProvider<String?>((ref) => null);

/// Streams real FPS/latency/CPU/memory from the running session's
/// MetricsCollector. Before the session starts there's nothing to stream
/// yet, hence the nullable default.
final performanceProvider = StreamProvider<PerformanceSample>((ref) {
  final session = ref.watch(studioSessionProvider);
  return session.metrics.samples;
});

/// Holds the CapturePipeline created when Start Studio is pressed (see
/// _TransportBar in studio_screen.dart) so it can be stopped/disposed on
/// Stop Studio without re-reading provider state. Null while idle.
final capturePipelineProvider = StateProvider<CapturePipeline?>((ref) => null);
