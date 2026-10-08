import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../domain/models/video_frame.dart';

/// Actually captures frames from a Windows dshow camera device by piping
/// raw BGRA video out of FFmpeg. This is the class that makes "camera
/// preview" real instead of a placeholder icon.
///
/// FFmpeg is asked to normalize whatever the device natively outputs to
/// [width]x[height]@[fps] via its own scale filter, so the rest of the
/// pipeline never has to deal with per-device native resolutions.
class FfmpegCameraCapture {
  final String deviceName;
  final int width;
  final int height;
  final int fps;
  final String ffmpegPath;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  final _frameController = StreamController<VideoFrame>.broadcast();

  // Efficient accumulation: keep raw chunks in a queue and only copy bytes
  // once, into the final frame buffer, instead of re-copying everything
  // accumulated so far on every incoming chunk (that O(n^2) pattern is
  // what was pegging CPU/RAM before this fix).
  final List<Uint8List> _pendingChunks = [];
  int _pendingLength = 0;
  late final int _frameByteSize;

  FfmpegCameraCapture({
    required this.deviceName,
    // Defaults lowered from 1280x720@30 (~3.7MB/frame raw BGRA) — nothing
    // downstream needs full 720p yet: the mock/simple avatar engines don't
    // benefit from it, and real model-based engines (LivePortrait etc.)
    // work on small internal crops regardless of input size. 640x360@24
    // is ~1/6th the raw byte volume per second, which directly cuts the
    // decode/encode cost in Compositor proportionally. Bump this back up
    // once the pipeline comfortably keeps up, or if you need higher-res
    // output for something downstream that actually uses it.
    this.width = 640,
    this.height = 360,
    this.fps = 24,
    this.ffmpegPath = 'ffmpeg',
  }) {
    _frameByteSize = width * height * 4; // BGRA, 4 bytes/pixel
  }

  Stream<VideoFrame> get frames => _frameController.stream;

  Future<void> start() async {
    final args = [
      '-hide_banner',
      '-loglevel', 'error',
      '-f', 'dshow',
      '-rtbufsize', '100M',
      '-video_size', '${width}x$height',
      '-framerate', '$fps',
      '-i', 'video=$deviceName',
      '-vf', 'scale=$width:$height',
      '-pix_fmt', 'bgra',
      '-f', 'rawvideo',
      'pipe:1',
    ];

    // No runInShell here either — see FfmpegCameraDiscovery for why the
    // extra cmd.exe hop is avoided from a GUI (non-console) process.
    _process = await Process.start(ffmpegPath, args);

    _stdoutSub = _process!.stdout.listen(_onData, onError: (e) {
      _frameController.addError(e);
    });

    _process!.stderr.transform(const SystemEncoding().decoder).listen((line) {
      if (line.trim().isNotEmpty) {
        // ignore: avoid_print
        print('[camera:ffmpeg] $line'.trim());
      }
    });
  }

  void _onData(List<int> chunk) {
    // Process.stdout already yields Uint8List chunks in practice, but
    // guard against the List<int> interface type just in case.
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

      _frameController.add(VideoFrame(
        bytes: frameBytes,
        width: width,
        height: height,
        format: VideoPixelFormat.bgra8888,
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
