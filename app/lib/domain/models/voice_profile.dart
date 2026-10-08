/// Reserved for future voice-clone support (see docs/engines.md, section on
/// VoiceCloneEngine). Not wired into the pipeline yet in v1.
class VoiceProfile {
  final String id;
  final String name;
  final String? referenceAudioPath;
  final String engineId;

  const VoiceProfile({
    required this.id,
    required this.name,
    required this.engineId,
    this.referenceAudioPath,
  });
}
