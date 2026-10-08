/// Reported by every AvatarEngine so the Studio/PerformanceManager can pick
/// an appropriate pipeline without knowing the concrete engine type.
class AvatarEngineCapabilities {
  final bool supportsGpu;
  final bool supportsCpu;
  final bool supportsMotionTransfer;
  final bool supportsAudioDrivenLipSync;
  final bool supportsRealtime;
  final int recommendedWidth;
  final int recommendedHeight;
  final int recommendedFps;
  final int minimumMemoryMb;

  const AvatarEngineCapabilities({
    required this.supportsGpu,
    required this.supportsCpu,
    required this.supportsMotionTransfer,
    required this.supportsAudioDrivenLipSync,
    required this.supportsRealtime,
    required this.recommendedWidth,
    required this.recommendedHeight,
    required this.recommendedFps,
    required this.minimumMemoryMb,
  });
}

class LipSyncCapabilities {
  final bool supportsGpu;
  final bool supportsCpu;
  final bool supportsRealtime;
  final int recommendedFps;
  final int minimumMemoryMb;

  const LipSyncCapabilities({
    required this.supportsGpu,
    required this.supportsCpu,
    required this.supportsRealtime,
    required this.recommendedFps,
    required this.minimumMemoryMb,
  });
}

class VoiceEngineCapabilities {
  final bool isRealtime;
  final bool requiresReferenceAudio;
  final int recommendedSampleRate;

  const VoiceEngineCapabilities({
    required this.isRealtime,
    required this.requiresReferenceAudio,
    required this.recommendedSampleRate,
  });
}
