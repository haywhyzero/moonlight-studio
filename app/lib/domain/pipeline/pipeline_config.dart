/// Declarative description of which engines to wire together, plus each
/// engine's own settings. The Studio never chains avatar -> lipsync
/// automatically; lipSyncEngineId is nullable so "just the avatar engine,
/// no lip sync" stays cheap.
class PipelineConfig {
  final String motionTrackerId;
  final String avatarEngineId;
  final String? lipSyncEngineId;
  final String voiceEngineId;
  final String virtualCameraProviderId;
  final String virtualMicrophoneProviderId;

  /// Per-engine settings, keyed by engine id, handed to that engine's
  /// initialize() as an EngineConfig. Examples:
  ///   'realtime_effects': {'effect': 'pitchDown'}
  ///   'voice_clone': {'pthPath': '...', 'indexPath': '...'}
  final Map<String, Map<String, dynamic>> engineSettings;

  const PipelineConfig({
    required this.motionTrackerId,
    required this.avatarEngineId,
    this.lipSyncEngineId,
    required this.voiceEngineId,
    required this.virtualCameraProviderId,
    required this.virtualMicrophoneProviderId,
    this.engineSettings = const {},
  });

  /// Defaults to the engines that actually do something today
  /// (SimpleAvatarEngine + DSP voice effects). The motion tracker is still
  /// the mock one — no real tracker exists yet.
  factory PipelineConfig.developmentDefault() => const PipelineConfig(
        motionTrackerId: 'mock_motion',
        avatarEngineId: 'simple_avatar',
        lipSyncEngineId: null,
        voiceEngineId: 'realtime_effects',
        virtualCameraProviderId: 'obs_virtual_camera',
        virtualMicrophoneProviderId: 'virtual_audio_cable',
      );

  PipelineConfig copyWith({
    String? motionTrackerId,
    String? avatarEngineId,
    String? lipSyncEngineId,
    bool clearLipSync = false,
    String? voiceEngineId,
    Map<String, Map<String, dynamic>>? engineSettings,
  }) =>
      PipelineConfig(
        motionTrackerId: motionTrackerId ?? this.motionTrackerId,
        avatarEngineId: avatarEngineId ?? this.avatarEngineId,
        lipSyncEngineId: clearLipSync ? null : (lipSyncEngineId ?? this.lipSyncEngineId),
        voiceEngineId: voiceEngineId ?? this.voiceEngineId,
        virtualCameraProviderId: virtualCameraProviderId,
        virtualMicrophoneProviderId: virtualMicrophoneProviderId,
        engineSettings: engineSettings ?? this.engineSettings,
      );

  /// Returns a copy with [key] set to [value] inside [engineId]'s settings.
  PipelineConfig withSetting(String engineId, String key, dynamic value) {
    final updated = {
      for (final e in engineSettings.entries) e.key: Map<String, dynamic>.of(e.value),
    };
    (updated[engineId] ??= {})[key] = value;
    return copyWith(engineSettings: updated);
  }
}
