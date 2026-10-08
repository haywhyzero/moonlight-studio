/// Generic config bag passed to Engine.initialize(). Kept as a typed
/// wrapper around a map so each engine can read what it needs without the
/// domain layer knowing engine-specific keys.
class EngineConfig {
  final Map<String, dynamic> values;
  const EngineConfig([this.values = const {}]);

  T? get<T>(String key) => values[key] as T?;
  T getOr<T>(String key, T fallback) => (values[key] as T?) ?? fallback;
}

enum WorkerState {
  starting,
  loadingModel,
  ready,
  processing,
  degraded,
  error,
  stopped,
}

enum PerformanceMode { ultra, high, balanced, performance, cpuSafe }
