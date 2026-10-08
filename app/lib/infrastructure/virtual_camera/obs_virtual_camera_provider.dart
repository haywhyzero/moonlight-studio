import '../../domain/interfaces/virtual_camera_provider.dart';
import '../../domain/models/video_frame.dart';
import 'obs_websocket_client.dart';

/// OBS integration, restructured around the standard way VTuber-style
/// apps actually work with OBS: this app renders its own preview window,
/// and you add that window to OBS as a native "Window Capture" source —
/// hardware-accelerated, zero extra encode/decode passes. OBS's own
/// "Start Virtual Camera" then outputs whatever the OBS scene shows,
/// which includes that Window Capture source, for free.
///
/// What this class does NOT do anymore: push pixels into OBS itself. An
/// earlier version ran a local MJPEG HTTP server and had OBS re-capture
/// that as a Browser Source — which meant every frame was decoded once
/// by this app, re-encoded to JPEG, sent over HTTP, decoded again by OBS,
/// then re-encoded again for OBS's own virtual camera output. Three
/// codec passes for one frame, competing with everything else for a
/// single CPU thread, was a real and significant part of the performance
/// problems this app had — Window Capture has none of that: OBS reads
/// the rendered window directly.
///
/// What this class still does: optionally toggle OBS's Start/Stop Virtual
/// Camera via obs-websocket when you press Start/Stop Studio, so you
/// don't have to click it in OBS yourself. This is a pure control-plane
/// call — no pixel data crosses this connection. If OBS or obs-websocket
/// isn't reachable, start()/stop() just log and continue; toggling the
/// virtual camera manually in OBS always still works regardless.
///
/// One-time OBS setup (see docs/virtual-devices.md):
///   1. Add this app's window as a Window Capture source in OBS.
///   2. Enable obs-websocket (Tools > WebSocket Server Settings) if you
///      want the automatic Start/Stop Virtual Camera behavior below.
class ObsVirtualCameraProvider implements VirtualCameraProvider {
  @override
  String get id => 'obs_virtual_camera';

  final String obsHost;
  final int obsPort;
  final String? obsPassword;

  ObsWebSocketClient? _obsClient;
  bool _obsConnected = false;

  ObsVirtualCameraProvider({
    this.obsHost = '127.0.0.1',
    this.obsPort = 4455,
    this.obsPassword,
  });

  @override
  Future<void> initialize() async {
    _obsClient = ObsWebSocketClient(host: obsHost, port: obsPort, password: obsPassword);
    try {
      await _obsClient!.connect();
      _obsConnected = true;
    } catch (e) {
      _obsConnected = false;
      // ignore: avoid_print
      print('[ObsVirtualCameraProvider] Could not connect to obs-websocket '
          'at $obsHost:$obsPort ($e). Video still reaches OBS fine via '
          'Window Capture — this only affects whether Start/Stop Studio '
          'can also toggle OBS\'s virtual camera automatically. Toggle it '
          'manually in OBS, or fix the connection and retry.');
    }
  }

  @override
  Future<void> start() async {
    if (_obsConnected) {
      await _obsClient!.startVirtualCam();
    }
  }

  @override
  Future<void> pushFrame(VideoFrame frame) async {
    // Deliberately a no-op — see class doc comment. Video reaches OBS via
    // Window Capture of this app's own rendered preview, not by pushing
    // frames through this provider.
  }

  @override
  Future<void> stop() async {
    if (_obsConnected) {
      try {
        await _obsClient!.stopVirtualCam();
      } catch (_) {
        // best-effort — OBS may already have it stopped
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _obsClient?.close();
  }
}
