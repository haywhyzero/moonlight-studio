import 'dart:async';
import 'dart:collection';
import 'dart:io';
import '../../domain/models/engine_config.dart';

/// Starts, monitors, and cleanly tears down a Python worker subprocess.
/// One WorkerManager per worker (liveportrait / musetalk / wav2lip /
/// voice_clone / ...) — see python/workers/*.
class WorkerManager {
  final String workerName;
  final String pythonExecutable;

  /// Path to the worker's main.py, relative to the repository root (the
  /// folder containing `python/`). Resolved at start() — see
  /// _resolveScript for why this isn't just used as-is.
  final String scriptPath;
  final int port;

  Process? _process;
  final _stateController = StreamController<WorkerState>.broadcast();
  WorkerState _state = WorkerState.stopped;
  bool _exited = false;
  final Queue<String> _recentLog = Queue<String>();

  WorkerManager({
    required this.workerName,
    required this.scriptPath,
    required this.port,
    this.pythonExecutable = 'python',
  });

  Stream<WorkerState> get stateChanges => _stateController.stream;
  WorkerState get state => _state;

  /// True once the subprocess has terminated (crash or clean exit).
  bool get hasExited => _exited;

  /// Last ~15 lines of the worker's stdout/stderr, for error messages.
  String get recentLog => _recentLog.join('\n');

  void _setState(WorkerState s) {
    _state = s;
    _stateController.add(s);
  }

  void _log(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _recentLog.addLast(trimmed);
    while (_recentLog.length > 15) {
      _recentLog.removeFirst();
    }
    // ignore: avoid_print
    print('[$workerName] $trimmed');
  }

  /// `flutter run` executes with the app/ folder as the working directory,
  /// but python/ lives next to app/, not inside it — so a plain relative
  /// path like "python/workers/x/main.py" points at nothing. Walk up from
  /// the working directory until the script is found.
  String _resolveScript() {
    var dir = Directory.current.absolute;
    for (var i = 0; i < 8; i++) {
      final candidate = File('${dir.path}${Platform.pathSeparator}$scriptPath');
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    throw StateError(
      'Could not find $scriptPath searching upward from ${Directory.current.path}. '
      'Run the app from inside the moonlight-studio repository.',
    );
  }

  Future<void> start() async {
    _setState(WorkerState.starting);
    _exited = false;
    _recentLog.clear();
    final script = _resolveScript();

    _process = await Process.start(pythonExecutable, [script, '--port', '$port']);

    _process!.stdout.transform(const SystemEncoding().decoder).listen((text) {
      for (final line in text.split('\n')) {
        _parseStdoutForState(line);
        _log(line);
      }
    });
    _process!.stderr.transform(const SystemEncoding().decoder).listen((text) {
      for (final line in text.split('\n')) {
        _log(line);
      }
      if (text.toLowerCase().contains('traceback')) {
        _setState(WorkerState.error);
      }
    });

    unawaited(_process!.exitCode.then((code) {
      _exited = true;
      if (_state != WorkerState.stopped) {
        _setState(code == 0 ? WorkerState.stopped : WorkerState.error);
        if (code != 0) _log('worker exited with code $code');
      }
    }));
  }

  void _parseStdoutForState(String line) {
    if (line.contains('LOADING_MODEL')) _setState(WorkerState.loadingModel);
    if (line.contains('DEGRADED')) {
      _setState(WorkerState.degraded);
    } else if (line.contains('READY') && _state != WorkerState.degraded) {
      _setState(WorkerState.ready);
    }
    if (line.contains('PROCESSING')) _setState(WorkerState.processing);
  }

  Future<void> stop() async {
    _setState(WorkerState.stopped);
    _process?.kill();
    try {
      await _process?.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      _process?.kill(ProcessSignal.sigkill);
    }
    _process = null;
  }

  Future<void> restart() async {
    await stop();
    await start();
  }
}
