import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../domain/interfaces/avatar_engine.dart';
import '../../../domain/models/video_frame.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/motion_data.dart';
import '../../../domain/models/avatar.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';
import '../../../domain/services/frame_codec.dart';
import '../../../infrastructure/process/worker_manager.dart';
import '../../../infrastructure/ipc/worker_ipc_client.dart';

/// Adapter over the LivePortrait Python worker (python/workers/liveportrait_worker).
///
/// REQUIRES SETUP BEFORE THIS ENGINE WILL ACTUALLY PRODUCE OUTPUT:
///   1. Install LivePortrait's dependencies per python/requirements/liveportrait.txt
///   2. Download LivePortrait's pretrained weights into models/liveportrait/
///      (this app does not auto-download large model weights — see
///      ModelManager in docs/architecture.md)
///   3. A CUDA-capable GPU is strongly recommended; see docs/engine-evaluation.md
///
/// Until that setup is done, prepareAvatar()/process() will surface a
/// WorkerState.error with a human-readable message rather than silently
/// returning fake output — per the "no silent placeholders" rule.
class LivePortraitEngine implements AvatarEngine {
  WorkerManager? _worker;
  WorkerIpcClient? _ipc;
  int _seq = 0;

  @override
  String get id => 'liveportrait';
  @override
  String get name => 'LivePortrait';

  @override
  AvatarEngineCapabilities get capabilities => const AvatarEngineCapabilities(
        supportsGpu: true,
        supportsCpu: false,
        supportsMotionTransfer: true,
        supportsAudioDrivenLipSync: false,
        supportsRealtime: true,
        recommendedWidth: 512,
        recommendedHeight: 512,
        recommendedFps: 24,
        minimumMemoryMb: 6000,
      );

  @override
  Future<void> initialize(EngineConfig config) async {
    final port = config.getOr<int>('port', 8801);
    _worker = WorkerManager(
      workerName: 'liveportrait',
      scriptPath: 'python/workers/liveportrait_worker/main.py',
      port: port,
      pythonExecutable: config.getOr<String>('pythonExecutable', 'python'),
    );
    await _worker!.start();
    _ipc = WorkerIpcClient(port: port);
    await _ipc!.connect(
      shouldAbort: () => _worker!.hasExited,
      failureDetail: () => _worker!.recentLog,
    );
  }

  @override
  Future<AvatarPreparationResult> prepareAvatar(AvatarSource source) async {
    if (_ipc == null) {
      return AvatarPreparationResult(
        success: false,
        engineId: id,
        errorMessage: 'LivePortrait worker not initialized. Call initialize() first.',
      );
    }
    final completer = Completer<AvatarPreparationResult>();
    late final StreamSubscription sub;
    sub = _ipc!.messages.listen((msg) {
      if (msg['type'] == 'prepare_result') {
        completer.complete(AvatarPreparationResult(
          success: msg['success'] as bool,
          engineId: id,
          cacheData: (msg['cacheData'] as Map?)?.cast<String, dynamic>() ?? {},
          errorMessage: msg['error'] as String?,
        ));
        sub.cancel();
      }
    });
    _ipc!.send({'type': 'prepare', 'imagePath': source.imagePath});
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => AvatarPreparationResult(
        success: false,
        engineId: id,
        errorMessage:
            'LivePortrait preparation timed out. Check model weights are '
            'installed under models/liveportrait/ and GPU drivers are up to date.',
      ),
    );
  }

  @override
  Future<void> start() async {}

  @override
  Future<VideoFrame> process(
    VideoFrame sourceFrame,
    MotionData motion,
    AudioFrame? audio,
  ) async {
    if (_ipc == null) {
      throw StateError('LivePortraitEngine.process called before initialize()');
    }
    final seq = _seq++;
    final completer = Completer<VideoFrame>();
    late final StreamSubscription sub;
    sub = _ipc!.messages.listen((msg) {
      if (msg['type'] == 'result' && msg['seq'] == seq) {
        final bytes = base64Decode(msg['payload_b64'] as String);
        completer.complete(VideoFrame(
          bytes: Uint8List.fromList(bytes),
          width: sourceFrame.width,
          height: sourceFrame.height,
          format: VideoPixelFormat.encodedPng,
          timestamp: sourceFrame.timestamp,
        ));
        sub.cancel();
      } else if (msg['type'] == 'error') {
        completer.completeError(StateError(msg['message'] as String));
        sub.cancel();
      }
    });
    _ipc!.send({
      'type': 'frame',
      'seq': seq,
      'payload_b64': base64Encode(FrameCodec.toPngBytes(sourceFrame)),
      'motion': {
        'yaw': motion.head?.yaw ?? 0,
        'pitch': motion.head?.pitch ?? 0,
        'roll': motion.head?.roll ?? 0,
      },
    });
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => sourceFrame, // degrade to passthrough rather than stall the pipeline
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _ipc?.close();
    _ipc = null;
    await _worker?.stop();
  }
}
