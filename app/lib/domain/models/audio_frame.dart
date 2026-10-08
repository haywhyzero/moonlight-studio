import 'dart:typed_data';

/// A chunk of PCM audio passed between pipeline stages.
class AudioFrame {
  final Float32List samples;
  final int sampleRate;
  final int channels;
  final DateTime timestamp;

  const AudioFrame({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    required this.timestamp,
  });
}
