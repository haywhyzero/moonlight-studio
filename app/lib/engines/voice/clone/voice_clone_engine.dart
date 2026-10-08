import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../domain/interfaces/voice_engine.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';
import '../../../infrastructure/process/worker_manager.dart';
import '../../../infrastructure/ipc/worker_ipc_client.dart';

/// Adapter over the RVC (Retrieval-based Voice Conversion) real-time
/// voice worker. See python/workers/voice_clone_worker/main.py for what's
/// actually implemented — model loading is real, but the sliding-window
/// SOLA buffering RVC's real-time mode needs has not been ported/verified
/// (needs a GPU and real audio to do safely) — process() will surface a
/// clear error rather than fake output until that's done.
///
/// "Loading a voice" here means an already-trained RVC model — a .pth
/// file, optionally with a .index file for better timbre accuracy — not
/// a raw audio sample. See loadVoice()'s doc comment and
/// docs/engine-evaluation.md for why RVC doesn't support instant cloning
/// from a single sample.
class VoiceCloneEngine implements VoiceEngine {
  WorkerManager? _worker;
  WorkerIpcClient? _ipc;
  int _seq = 0;
  bool _voiceLoaded = false;

  @override
  String get id => 'voice_clone';
  @override
  String get name => 'Voice Clone (RVC)';

  @override
  VoiceEngineCapabilities get capabilities => const VoiceEngineCapabilities(
        isRealtime: false, // honestly false until the buffering loop is wired — see class doc
        requiresReferenceAudio: true,
        recommendedSampleRate: 48000,
      );

  @override
  Future<void> initialize(EngineConfig config) async {
    final port = config.getOr<int>('port', 8805);
    _worker = WorkerManager(
      workerName: 'voice_clone',
      scriptPath: 'python/workers/voice_clone_worker/main.py',
      port: port,
      pythonExecutable: config.getOr<String>('pythonExecutable', 'python'),
    );
    await _worker!.start();
    _ipc = WorkerIpcClient(port: port);
    await _ipc!.connect(
      shouldAbort: () => _worker!.hasExited,
      failureDetail: () => _worker!.recentLog,
    );

    // A voice engine with no voice model can only ever fail later, per
    // frame, in a confusing way — fail here instead, with a clear message.
    final pthPath = config.get<String>('pthPath');
    if (pthPath == null || pthPath.isEmpty) {
      throw StateError('Voice Clone needs a voice model — choose a .pth file first.');
    }
    final result = await loadVoice(
      pthPath: pthPath,
      indexPath: config.get<String>('indexPath'),
      indexRate: config.getOr<double>('indexRate', 0.75),
    );
    if (!result.success) {
      throw StateError(result.error ?? 'Could not load the voice model.');
    }
  }

  /// Loads an already-trained RVC voice model. [pthPath] is required;
  /// [indexPath] is optional but improves conversion accuracy;
  /// [indexRate] (0..1) controls how strongly the index is applied.
  Future<({bool success, String? error})> loadVoice({
    required String pthPath,
    String? indexPath,
    double indexRate = 0.75,
  }) async {
    if (_ipc == null) {
      return (success: false, error: 'VoiceCloneEngine not initialized');
    }
    final completer = Completer<({bool success, String? error})>();
    late final StreamSubscription sub;
    sub = _ipc!.messages.listen((msg) {
      if (msg['type'] == 'prepare_result') {
        _voiceLoaded = msg['success'] as bool;
        completer.complete((
          success: _voiceLoaded,
          error: msg['error'] as String?,
        ));
        sub.cancel();
      }
    });
    _ipc!.send({
      'type': 'prepare',
      'pthPath': pthPath,
      if (indexPath != null) 'indexPath': indexPath,
      'indexRate': indexRate,
    });
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => (success: false, error: 'Loading voice model timed out'),
    );
  }

  @override
  Future<AudioFrame> process(AudioFrame input) async {
    if (!_voiceLoaded || _ipc == null) {
      throw StateError(
        'VoiceCloneEngine.process called with no voice model loaded — call loadVoice() first.',
      );
    }
    final seq = _seq++;
    final completer = Completer<AudioFrame>();
    late final StreamSubscription sub;
    sub = _ipc!.messages.listen((msg) {
      if (msg['type'] == 'result' && msg['seq'] == seq) {
        final bytes = base64Decode(msg['payload_b64'] as String);
        completer.complete(AudioFrame(
          samples: Float32List.sublistView(bytes),
          sampleRate: input.sampleRate,
          channels: input.channels,
          timestamp: input.timestamp,
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
      'payload_b64': base64Encode(input.samples.buffer.asUint8List()),
    });
    // Deliberately NOT catching the error into a passthrough fallback here
    // (unlike the video engines' timeout-to-passthrough pattern): silently
    // passing your unconverted voice through when voice conversion was
    // explicitly requested would be misleading, not graceful degradation.
    return completer.future.timeout(const Duration(seconds: 5));
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
