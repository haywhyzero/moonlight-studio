import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../domain/interfaces/lip_sync_engine.dart';
import '../../../domain/models/video_frame.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';
import '../../../domain/services/frame_codec.dart';
import '../../../infrastructure/process/worker_manager.dart';
import '../../../infrastructure/ipc/worker_ipc_client.dart';

/// Adapter over the Wav2Lip Python worker — a swappable alternative to
/// MuseTalk, not the "final" lip-sync solution. Same IPC contract as
/// MuseTalkEngine so either can be selected from Settings > AI without
/// touching the pipeline code. REQUIRES python/requirements/wav2lip.txt +
/// weights under models/wav2lip/.
class Wav2LipEngine implements LipSyncEngine {
  WorkerManager? _worker;
  WorkerIpcClient? _ipc;
  int _seq = 0;

  @override
  String get id => 'wav2lip';
  @override
  String get name => 'Wav2Lip';

  @override
  LipSyncCapabilities get capabilities => const LipSyncCapabilities(
        supportsGpu: true,
        supportsCpu: true,
        supportsRealtime: false,
        recommendedFps: 20,
        minimumMemoryMb: 4000,
      );

  @override
  Future<void> initialize(EngineConfig config) async {
    final port = config.getOr<int>('port', 8803);
    _worker = WorkerManager(
      workerName: 'wav2lip',
      scriptPath: 'python/workers/wav2lip_worker/main.py',
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
  Future<VideoFrame> process(VideoFrame frame, AudioFrame audio) async {
    if (_ipc == null) return frame;
    final seq = _seq++;
    final completer = Completer<VideoFrame>();
    late final StreamSubscription sub;
    sub = _ipc!.messages.listen((msg) {
      if (msg['type'] == 'result' && msg['seq'] == seq) {
        completer.complete(VideoFrame(
          bytes: Uint8List.fromList(base64Decode(msg['payload_b64'] as String)),
          width: frame.width,
          height: frame.height,
          format: VideoPixelFormat.encodedPng,
          timestamp: frame.timestamp,
        ));
        sub.cancel();
      }
    });
    _ipc!.send({
      'type': 'frame',
      'seq': seq,
      'video_payload_b64': base64Encode(FrameCodec.toPngBytes(frame)),
      'audio_payload_b64': base64Encode(audio.samples.buffer.asUint8List()),
    });
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => frame,
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
