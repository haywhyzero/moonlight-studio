import '../../domain/models/engine_config.dart';

/// Watches live pipeline metrics and recommends/applies a PerformanceMode
/// (see docs/architecture.md section 17). Kept intentionally simple for
/// v1: threshold-based mode selection rather than a predictive model.
class PerformanceSample {
  final double fps;
  final double frameProcessingMs;
  final double cpuPercent;
  final double? gpuPercent;
  final double audioLatencyMs;

  const PerformanceSample({
    required this.fps,
    required this.frameProcessingMs,
    required this.cpuPercent,
    this.gpuPercent,
    required this.audioLatencyMs,
  });
}

class PerformanceManager {
  PerformanceMode evaluate(PerformanceSample sample) {
    if (sample.cpuPercent > 90 || sample.fps < 12) return PerformanceMode.cpuSafe;
    if (sample.cpuPercent > 75 || sample.fps < 18) return PerformanceMode.performance;
    if (sample.cpuPercent > 55 || sample.fps < 24) return PerformanceMode.balanced;
    if ((sample.gpuPercent ?? 0) > 80) return PerformanceMode.high;
    return PerformanceMode.ultra;
  }
}
