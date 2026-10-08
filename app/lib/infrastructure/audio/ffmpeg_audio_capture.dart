import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../domain/models/audio_frame.dart';

/// Captures raw PCM audio from a Windows dshow microphone via FFmpeg,
/// mirroring FfmpegCameraCapture. Emits mono 32-bit float samples so
/// VoiceEngine implementations never have to branch on channel count.
class FfmpegAudioCapture {
  final String deviceName;
  final int sampleRate;
  final String ffmpegPath;
  final int samplesPerFrame;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  final _frameController = StreamController<AudioFrame>.broadcast();
  final List<Uint8List> _pendingChunks = [];
  int _pendingLength = 0;
  late final int _frameByteSize;

  FfmpegAudioCapture({
    required this.deviceName,
    this.sampleRate = 48000,
    this.ffmpegPath = 'ffmpeg',
    this.samplesPerFrame = 960, // 20ms @ 48kHz
  }) {
    _frameByteSize = samplesPerFrame * 4; // f32le, 4 bytes/sample
  }

  Stream<AudioFrame> get frames => _frameController.stream;

  Future<void> start() async {
    final args = [
      '-hide_banner',
      '-loglevel', 'error',
      '-f', 'dshow',
      '-i', 'audio=$deviceName',
      '-ac', '1',
      '-ar', '$sampleRate',
      '-f', 'f32le',
      'pipe:1',
    ];

    _process = await Process.start(ffmpegPath, args);
    _stdoutSub = _process!.stdout.listen(_onData, onError: (e) {
      _frameController.addError(e);
    });
    _process!.stderr.transform(const SystemEncoding().decoder).listen((line) {
      if (line.trim().isNotEmpty) {
        // ignore: avoid_print
        print('[mic:ffmpeg] $line'.trim());
      }
    });
  }

  void _onData(List<int> chunk) {
    _pendingChunks.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    _pendingLength += chunk.length;

    while (_pendingLength >= _frameByteSize) {
      final frameBytes = Uint8List(_frameByteSize);
      var copied = 0;
      while (copied < _frameByteSize) {
        final head = _pendingChunks.first;
        final needed = _frameByteSize - copied;
        if (head.length <= needed) {
          frameBytes.setRange(copied, copied + head.length, head);
          copied += head.length;
          _pendingChunks.removeAt(0);
        } else {
          frameBytes.setRange(copied, _frameByteSize, head, 0);
          _pendingChunks[0] = Uint8List.sublistView(head, needed);
          copied = _frameByteSize;
        }
      }
      _pendingLength -= _frameByteSize;

      final byteData = ByteData.sublistView(frameBytes);
      final samples = Float32List(samplesPerFrame);
      for (var i = 0; i < samplesPerFrame; i++) {
        samples[i] = byteData.getFloat32(i * 4, Endian.little);
      }
      _frameController.add(AudioFrame(
        samples: samples,
        sampleRate: sampleRate,
        channels: 1,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> stop() async {
    await _stdoutSub?.cancel();
    _process?.kill(ProcessSignal.sigterm);
    await _process?.exitCode;
    _process = null;
    _pendingChunks.clear();
    _pendingLength = 0;
  }

  Future<void> dispose() async {
    await stop();
    await _frameController.close();
  }
}
