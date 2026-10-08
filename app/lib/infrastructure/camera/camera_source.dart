/// Describes one enumerated camera device.
class CameraDevice {
  final String id;
  final String label;
  const CameraDevice({required this.id, required this.label});
}

abstract class CameraDiscovery {
  Future<List<CameraDevice>> list();
}
