import 'dart:math';
import 'dart:typed_data';
import '../../../domain/interfaces/voice_engine.dart';
import '../../../domain/models/audio_frame.dart';
import '../../../domain/models/engine_capabilities.dart';
import '../../../domain/models/engine_config.dart';

enum VoiceEffectType { none, pitchUp, pitchDown, robot, radio, echo }

/// Pure-Dart, in-process DSP voice effects. No model files, no Python
/// worker, runs on anything. This is deliberately NOT voice cloning —
/// see docs/engines.md "Voice" section for why that distinction matters
/// for how this engine is presented in the UI.
class RealtimeVoiceEffectEngine implements VoiceEngine {
  VoiceEffectType effect = VoiceEffectType.none;
  final List<double> _echoBuffer = [];

  @override
  String get id => 'realtime_effects';
  @override
  String get name => 'Real-Time Voice Effects';

  @override
  VoiceEngineCapabilities get capabilities => const VoiceEngineCapabilities(
        isRealtime: true,
        requiresReferenceAudio: false,
        recommendedSampleRate: 48000,
      );

  @override
  Future<void> initialize(EngineConfig config) async {
    final effectName = config.getOr<String>('effect', 'none');
    effect = VoiceEffectType.values.firstWhere(
      (e) => e.name == effectName,
      orElse: () => VoiceEffectType.none,
    );
  }

  @override
  Future<AudioFrame> process(AudioFrame input) async {
    switch (effect) {
      case VoiceEffectType.none:
        return input;
      case VoiceEffectType.pitchUp:
        return _resamplePitch(input, 1.25);
      case VoiceEffectType.pitchDown:
        return _resamplePitch(input, 0.8);
      case VoiceEffectType.robot:
        return _ringModulate(input, 60);
      case VoiceEffectType.radio:
        return _bandLimitAndDistort(input);
      case VoiceEffectType.echo:
        return _addEcho(input);
    }
  }

  /// Simple time-domain resample-based pitch shift. Cheap, real-time safe,
  /// noticeably changes pitch at the cost of some naturalness — a fair
  /// trade for v1. A phase-vocoder based shift can replace this later
  /// behind the same interface without touching the rest of the app.
  AudioFrame _resamplePitch(AudioFrame input, double factor) {
    final src = input.samples;
    final outLen = (src.length / factor).floor();
    final out = Float32List(outLen);
    for (var i = 0; i < outLen; i++) {
      final srcIndex = i * factor;
      final i0 = srcIndex.floor().clamp(0, src.length - 1);
      final i1 = (i0 + 1).clamp(0, src.length - 1);
      final frac = srcIndex - i0;
      out[i] = src[i0] * (1 - frac) + src[i1] * frac;
    }
    return AudioFrame(
      samples: out,
      sampleRate: input.sampleRate,
      channels: input.channels,
      timestamp: input.timestamp,
    );
  }

  AudioFrame _ringModulate(AudioFrame input, double carrierHz) {
    final src = input.samples;
    final out = Float32List(src.length);
    for (var i = 0; i < src.length; i++) {
      final t = i / input.sampleRate;
      out[i] = (src[i] * sin(2 * pi * carrierHz * t)).clamp(-1.0, 1.0);
    }
    return AudioFrame(
      samples: out,
      sampleRate: input.sampleRate,
      channels: input.channels,
      timestamp: input.timestamp,
    );
  }

  AudioFrame _bandLimitAndDistort(AudioFrame input) {
    final src = input.samples;
    final out = Float32List(src.length);
    double prev = 0;
    for (var i = 0; i < src.length; i++) {
      // crude one-pole high-pass + soft clip to emulate a radio/telephone tone
      final hp = src[i] - prev * 0.95;
      prev = src[i];
      out[i] = (hp * 2.2).clamp(-1.0, 1.0);
    }
    return AudioFrame(
      samples: out,
      sampleRate: input.sampleRate,
      channels: input.channels,
      timestamp: input.timestamp,
    );
  }

  AudioFrame _addEcho(AudioFrame input) {
    final src = input.samples;
    final delaySamples = (input.sampleRate * 0.12).round();
    final out = Float32List(src.length);
    _echoBuffer.addAll(src);
    for (var i = 0; i < src.length; i++) {
      final delayed = (_echoBuffer.length - src.length + i - delaySamples);
      final echoVal = (delayed >= 0 && delayed < _echoBuffer.length)
          ? _echoBuffer[delayed] * 0.35
          : 0.0;
      out[i] = (src[i] + echoVal).clamp(-1.0, 1.0);
    }
    if (_echoBuffer.length > input.sampleRate * 2) {
      _echoBuffer.removeRange(0, _echoBuffer.length - (input.sampleRate * 2).round());
    }
    return AudioFrame(
      samples: out,
      sampleRate: input.sampleRate,
      channels: input.channels,
      timestamp: input.timestamp,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    _echoBuffer.clear();
  }
}
