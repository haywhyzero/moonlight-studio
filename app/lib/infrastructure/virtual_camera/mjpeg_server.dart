import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A tiny localhost MJPEG server. This is what makes pushFrame() actually
/// deliver pixels somewhere, in real time, without writing a Windows
/// camera driver: OBS's own "Browser Source" pointed at
/// http://127.0.0.1:<port>/stream.mjpg renders it like any other source.
///
/// This is a deliberate v1 shortcut, not the final architecture — see
/// docs/virtual-devices.md for the native-driver path this gets replaced
/// by later, behind the same VirtualCameraProvider interface.
class MjpegServer {
  final int port;
  HttpServer? _server;
  Uint8List? _latestJpeg;
  final _clients = <HttpResponse>[];

  MjpegServer({this.port = 8894});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleRequest);
  }

  void _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/stream.mjpg') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/x-mixed-replace; boundary=moonlightstudio',
    );
    request.response.bufferOutput = false;
    _clients.add(request.response);

    // If we already have a frame, send it immediately so OBS doesn't
    // show a blank source while waiting for the next pushFrame() call.
    if (_latestJpeg != null) {
      _writeFrame(request.response, _latestJpeg!);
    }

    request.response.done.then((_) => _clients.remove(request.response));
  }

  void publishJpeg(Uint8List jpegBytes) {
    _latestJpeg = jpegBytes;
    for (final client in List.of(_clients)) {
      _writeFrame(client, jpegBytes);
    }
  }

  void _writeFrame(HttpResponse response, Uint8List jpegBytes) {
    try {
      response.write('--moonlightstudio\r\n');
      response.write('Content-Type: image/jpeg\r\n');
      response.write('Content-Length: ${jpegBytes.length}\r\n\r\n');
      response.add(jpegBytes);
      response.write('\r\n');
    } catch (_) {
      // Client disconnected mid-write — it will be pruned via .done above.
    }
  }

  Future<void> stop() async {
    for (final client in List.of(_clients)) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
