import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Localhost-only JSON-over-WebSocket client for talking to a Python
/// worker process. Never connects beyond 127.0.0.1.
///
/// Wire format (one JSON object per message) — see
/// python/common/protocol/messages.py for the authoritative description:
///   -> {"type": "prepare", ...engine-specific fields}
///   -> {"type": "frame", "seq": 1, "payload_b64": "..."}
///   <- {"type": "prepare_result", "success": true|false, "error": ...}
///   <- {"type": "result", "seq": 1, "payload_b64": "..."}
///   <- {"type": "error", "message": "..."}
class WorkerIpcClient {
  final int port;
  WebSocketChannel? _channel;
  final _responses = StreamController<Map<String, dynamic>>.broadcast();

  WorkerIpcClient({required this.port});

  Stream<Map<String, dynamic>> get messages => _responses.stream;

  /// Connects with retries. A Python worker takes seconds to start
  /// listening (importing torch alone can take 10+ s the first time), so
  /// a single connection attempt right after spawning the process would
  /// just get refused. Retries until [timeout], but gives up early if
  /// [shouldAbort] reports the worker process already died — no point
  /// waiting a minute on a process that crashed on import.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 90),
    bool Function()? shouldAbort,
    String Function()? failureDetail,
  }) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;

    while (DateTime.now().isBefore(deadline)) {
      if (shouldAbort?.call() ?? false) {
        throw StateError(
          'Worker process exited before accepting connections.\n'
          '${failureDetail?.call() ?? ''}',
        );
      }
      try {
        final channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port'));
        await channel.ready;
        _channel = channel;
        channel.stream.listen(
          (raw) {
            final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
            _responses.add(decoded);
          },
          onError: (Object e) => _responses.addError(e),
          onDone: () {},
        );
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    throw TimeoutException(
      'Could not connect to worker on port $port within ${timeout.inSeconds}s '
      '(last error: $lastError).\n${failureDetail?.call() ?? ''}',
    );
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
