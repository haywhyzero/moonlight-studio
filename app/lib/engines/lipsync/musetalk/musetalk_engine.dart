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

/// Adapter over the MuseTalk Python worker. MuseTalk's published real-time
/// benchmark (30fps+) is on an NVIDIA V100 — treat this as a GPU-oriented
/// optional lip-sync stage, not a baseline requirement. See
/// docs/engine-evaluation.md.
///
/// REQUIRES: python/requirements/musetalk.txt installed + weights under
/// models/musetalk/. Times out to passthrough rather than blocking video.
class MuseTalkEngine implements LipSyncEngine {
  WorkerManager? _worker;
  WorkerIpcClient? _ipc;
  int _seq = 0;

  @override
  String get id => 'musetalk';
  @override
  String get name => 'MuseTalk';

  @override
  LipSyncCapabilities get capabilities => const LipSyncCapabilities(
        supportsGpu: true,
        supportsCpu: false,
        supportsRealtime: true,
        recommendedFps: 30,
        minimumMemoryMb: 8000,
      );

  @override
  Future<void> initialize(EngineConfig config) async {
    final port = config.getOr<int>('port', 8802);
    _worker = WorkerManager(
      workerName: 'musetalk',
      scriptPath: 'python/workers/musetalk_worker/main.py',
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
