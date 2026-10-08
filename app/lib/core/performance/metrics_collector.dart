import 'dart:async';
import 'dart:io';

/// Real, measured performance numbers — not placeholders. FPS and latency
/// come directly from frame timestamps the pipeline already has; CPU/RAM
/// come from polling `wmic` on Windows. If wmic isn't available (e.g. this
/// was ported to another OS later), the corresponding field is null and
/// the UI shows "N/A" rather than a fabricated number.
class PerformanceSample {
  final double? fps;
  final double? latencyMs;
  final double? cpuPercent;
  final double? usedMemoryMb;
  final double? totalMemoryMb;

  const PerformanceSample({
    this.fps,
    this.latencyMs,
    this.cpuPercent,
    this.usedMemoryMb,
    this.totalMemoryMb,
  });

  static const empty = PerformanceSample();
}

class MetricsCollector {
  final List<DateTime> _recentFrameTimestamps = [];
  double? _lastLatencyMs;
  Timer? _cpuPollTimer;
  double? _lastCpuPercent;
  double? _lastUsedMemoryMb;
  double? _lastTotalMemoryMb;

  final _samplesController = StreamController<PerformanceSample>.broadcast();
  Stream<PerformanceSample> get samples => _samplesController.stream;

  void start() {
    _cpuPollTimer?.cancel();
    _recentFrameTimestamps.clear();
    _cpuPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollSystemStats());
    _pollSystemStats(); // fire once immediately rather than waiting 2s
  }

  /// Call once per frame the pipeline actually processes, passing the
  /// frame's original capture timestamp so latency reflects true
  /// end-to-end delay, not just the compositor's own processing time.
  void recordFrame(DateTime capturedAt) {
    final now = DateTime.now();
    _lastLatencyMs = now.difference(capturedAt).inMicroseconds / 1000.0;

    _recentFrameTimestamps.add(now);
    final cutoff = now.subtract(const Duration(seconds: 1));
    _recentFrameTimestamps.removeWhere((t) => t.isBefore(cutoff));

    _emit();
  }

  Future<void> _pollSystemStats() async {
    if (!Platform.isWindows) return; // documented: metrics are Windows-only in v1
    try {
      final cpuResult = await Process.run(
        'wmic',
        ['cpu', 'get', 'loadpercentage'],
        runInShell: true,
      );
      _lastCpuPercent = _parseWmicNumber(cpuResult.stdout as String);

      final memResult = await Process.run(
        'wmic',
        ['OS', 'get', 'FreePhysicalMemory,TotalVisibleMemorySize', '/format:value'],
        runInShell: true,
      );
      final memText = memResult.stdout as String;
      final freeKb = _parseWmicField(memText, 'FreePhysicalMemory');
      final totalKb = _parseWmicField(memText, 'TotalVisibleMemorySize');
      if (freeKb != null && totalKb != null) {
        _lastTotalMemoryMb = totalKb / 1024.0;
        _lastUsedMemoryMb = (totalKb - freeKb) / 1024.0;
      }
    } catch (_) {
      // wmic unavailable/deprecated on this system — leave last-known
      // values in place rather than resetting to a fake zero.
    }
    _emit();
  }

  double? _parseWmicNumber(String output) {
    final match = RegExp(r'(\d+)').firstMatch(output);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  double? _parseWmicField(String output, String field) {
    final match = RegExp('$field=(\\d+)').firstMatch(output);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  void _emit() {
    final fps = _recentFrameTimestamps.length.toDouble();
    _samplesController.add(PerformanceSample(
      fps: fps > 0 ? fps : null,
      latencyMs: _lastLatencyMs,
      cpuPercent: _lastCpuPercent,
      usedMemoryMb: _lastUsedMemoryMb,
      totalMemoryMb: _lastTotalMemoryMb,
    ));
  }

  /// Stops polling without closing the sample stream, so the same
  /// collector can be started again for the next studio run.
  void stop() {
    _cpuPollTimer?.cancel();
    _cpuPollTimer = null;
  }

  void dispose() {
    _cpuPollTimer?.cancel();
    _samplesController.close();
  }
}
