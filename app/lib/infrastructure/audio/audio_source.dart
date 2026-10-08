/// Describes one enumerated audio input device.
class AudioDevice {
  final String id;
  final String label;
  const AudioDevice({required this.id, required this.label});
}

abstract class AudioDiscovery {
  Future<List<AudioDevice>> list();
}
