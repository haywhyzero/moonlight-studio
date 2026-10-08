import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Real obs-websocket v5 client: Hello/Identify handshake (with password
/// auth when OBS has one set), request/response correlation by requestId,
/// and typed helpers for the two calls this app actually needs
/// (StartVirtualCam/StopVirtualCam). Talks to OBS on localhost only.
///
/// Protocol reference: https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md
class ObsWebSocketClient {
  final String host;
  final int port;
  final String? password;

  WebSocketChannel? _channel;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _identified = Completer<void>();
  StreamSubscription? _sub;

  ObsWebSocketClient({this.host = '127.0.0.1', this.port = 4455, this.password});

  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    _channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
    _sub = _channel!.stream.listen(_onMessage, onError: (e) {
      if (!_identified.isCompleted) _identified.completeError(e);
    }, onDone: () {
      if (!_identified.isCompleted) {
        _identified.completeError(StateError('OBS WebSocket closed before Identify completed'));
      }
    });
    await _identified.future.timeout(timeout);
  }

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final op = msg['op'] as int;
    final d = msg['d'] as Map<String, dynamic>? ?? {};

    switch (op) {
      case 0: // Hello
        _handleHello(d);
        break;
      case 2: // Identified
        if (!_identified.isCompleted) _identified.complete();
        break;
      case 7: // RequestResponse
        final requestId = d['requestId'] as String?;
        final completer = requestId != null ? _pending.remove(requestId) : null;
        if (completer == null) return;
        final status = d['requestStatus'] as Map<String, dynamic>?;
        final ok = status?['result'] == true;
        if (ok) {
          completer.complete((d['responseData'] as Map<String, dynamic>?) ?? {});
        } else {
          completer.completeError(StateError(
            'OBS request failed: ${status?['comment'] ?? status?['code']}',
          ));
        }
        break;
    }
  }

  void _handleHello(Map<String, dynamic> hello) {
    final identify = <String, dynamic>{
      'rpcVersion': hello['rpcVersion'] ?? 1,
      'eventSubscriptions': 0, // this app only issues requests, never needs events
    };

    final auth = hello['authentication'] as Map<String, dynamic>?;
    if (auth != null) {
      if (password == null) {
        _identified.completeError(StateError(
          'OBS requires a password (WebSocket auth is enabled) but none was configured.',
        ));
        return;
      }
      final challenge = auth['challenge'] as String;
      final salt = auth['salt'] as String;
      final secret = base64.encode(sha256.convert(utf8.encode('$password$salt')).bytes);
      final authResponse = base64.encode(sha256.convert(utf8.encode('$secret$challenge')).bytes);
      identify['authentication'] = authResponse;
    }

    _send({'op': 1, 'd': identify});
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<Map<String, dynamic>> request(String requestType, [Map<String, dynamic>? requestData]) async {
    if (!_identified.isCompleted) {
      throw StateError('ObsWebSocketClient.request called before connect() completed');
    }
    final requestId = _randomId();
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    _send({
      'op': 6,
      'd': {
        'requestType': requestType,
        'requestId': requestId,
        if (requestData != null) 'requestData': requestData,
      },
    });

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      _pending.remove(requestId);
      throw TimeoutException('OBS request "$requestType" timed out');
    });
  }

  Future<void> startVirtualCam() => request('StartVirtualCam');
  Future<void> stopVirtualCam() => request('StopVirtualCam');
  Future<bool> isVirtualCamActive() async {
    final res = await request('GetVirtualCamStatus');
    return res['outputActive'] as bool? ?? false;
  }

  static String _randomId() {
    final rand = Random.secure();
    return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _channel?.sink.close();
  }
}
