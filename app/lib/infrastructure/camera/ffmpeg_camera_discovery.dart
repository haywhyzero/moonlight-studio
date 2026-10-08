import 'dart:io';
import 'camera_source.dart';

/// Enumerates Windows DirectShow (dshow) video devices via FFmpeg.
///
/// This is a real, working implementation — not a stub. It requires
/// ffmpeg.exe to be installed and on PATH (see docs/development.md for the
/// one-line winget/choco install). We use FFmpeg here instead of a native
/// Windows camera plugin because it needs zero platform-channel code and
/// already does the heavy lifting for both listing devices and, in
/// [FfmpegCameraCapture], actually pulling frames off them.
///
/// `ffmpeg -list_devices true -f dshow -i dummy` always exits non-zero
/// (it isn't actually trying to open "dummy") but prints the device list
/// to stderr, which is what we parse.
class FfmpegCameraDiscovery implements CameraDiscovery {
  final String ffmpegPath;
  const FfmpegCameraDiscovery({this.ffmpegPath = 'ffmpeg'});

  @override
  Future<List<CameraDevice>> list() async {
    final result = await Process.run(
      ffmpegPath,
      ['-hide_banner', '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
      // No shell features (pipes, &&, wildcards) are needed for this call,
      // so runInShell is deliberately OFF: on Windows, a GUI process
      // (which Flutter desktop is) spawning through cmd.exe /C adds an
      // extra hop that can interfere with stderr getting piped back
      // correctly. Calling ffmpeg.exe directly avoids that.
    );
    // FFmpeg always writes the device list to stderr for this invocation
    // and always returns a non-zero exit code — that is expected, not a
    // failure, so we don't check result.exitCode here.
    final raw = result.stderr as String;
    // ignore: avoid_print
    print('[ffmpeg-discovery:camera] exitCode=${result.exitCode} stderr follows:\n$raw');
    return _parseVideoDevices(raw);
  }

  static List<CameraDevice> _parseVideoDevices(String stderrOutput) {
    final devices = <CameraDevice>[];
    final lines = stderrOutput.split('\n');
    var inVideoSection = false;

    // The bracketed log tag varies by ffmpeg version/build — older builds
    // use "[dshow @ <addr>]", ffmpeg 9.x uses "[in#0 @ <addr>]" instead.
    // Match any bracket content rather than hardcoding "dshow".
    final namePattern = RegExp(
      r'^\[[^\]]*\]\s*"(.+)"(?:\s*\(([a-z, ]+)\))?$',
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.contains('DirectShow video devices')) {
        inVideoSection = true;
        continue;
      }
      if (line.contains('DirectShow audio devices')) {
        inVideoSection = false;
        continue;
      }
      if (line.contains('Alternative name')) continue;

      final match = namePattern.firstMatch(line);
      if (match == null) continue;

      final name = match.group(1)!;
      final typeSuffix = match.group(2); // e.g. "video", "audio", "audio, video", or null

      final isVideo = typeSuffix != null ? typeSuffix.contains('video') : inVideoSection;
      if (isVideo) {
        devices.add(CameraDevice(id: name, label: name));
      }
    }
    return devices;
  }
}
