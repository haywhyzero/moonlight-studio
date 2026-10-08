import 'dart:io';
import 'audio_source.dart';

/// Enumerates Windows dshow audio input devices via FFmpeg. Same
/// mechanism/tradeoffs as FfmpegCameraDiscovery — see its doc comment.
class FfmpegAudioDiscovery implements AudioDiscovery {
  final String ffmpegPath;
  const FfmpegAudioDiscovery({this.ffmpegPath = 'ffmpeg'});

  @override
  Future<List<AudioDevice>> list() async {
    final result = await Process.run(
      ffmpegPath,
      ['-hide_banner', '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
      runInShell: true,
    );
    return _parseAudioDevices(result.stderr as String);
  }

  static List<AudioDevice> _parseAudioDevices(String stderrOutput) {
    final devices = <AudioDevice>[];
    final lines = stderrOutput.split('\n');
    var inAudioSection = false;

    // See FfmpegCameraDiscovery._parseVideoDevices — the bracketed log tag
    // varies by ffmpeg version ("[dshow @ ...]" vs ffmpeg 9.x's
    // "[in#0 @ ...]"), so match any bracket content, not literally "dshow".
    final namePattern = RegExp(
      r'^\[[^\]]*\]\s*"(.+)"(?:\s*\(([a-z, ]+)\))?$',
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.contains('DirectShow video devices')) {
        inAudioSection = false;
        continue;
      }
      if (line.contains('DirectShow audio devices')) {
        inAudioSection = true;
        continue;
      }
      if (line.contains('Alternative name')) continue;

      final match = namePattern.firstMatch(line);
      if (match == null) continue;

      final name = match.group(1)!;
      final typeSuffix = match.group(2);

      final isAudio = typeSuffix != null ? typeSuffix.contains('audio') : inAudioSection;
      if (isAudio) {
        devices.add(AudioDevice(id: name, label: name));
      }
    }
    return devices;
  }
}
