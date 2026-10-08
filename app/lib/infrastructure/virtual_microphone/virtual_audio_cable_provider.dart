import '../../domain/interfaces/virtual_microphone_provider.dart';
import '../../domain/models/audio_frame.dart';

/// NOT YET IMPLEMENTED — this is an honest no-op, not broken code
/// pretending to work.
///
/// An earlier version of this class shelled out to
/// `ffmpeg -f dsound "<device>"` to pipe PCM into a virtual audio cable's
/// playback device. That doesn't work: FFmpeg's own documentation lists
/// `dsound` only as an INPUT (capture) device — it has never existed as
/// an output/playback muxer, on any FFmpeg version. There is no built-in
/// FFmpeg CLI mechanism for playing audio out to an arbitrary named
/// Windows device at all.
///
/// The real way apps route audio into a virtual cable is via WASAPI
/// directly (the same approach Discord/VoiceMeeter-style tools use) —
/// opening a shared-mode render client on the target endpoint through
/// Win32 COM interop (e.g. via Dart FFI + the `win32` package). That is
/// meaningfully new code, not a config tweak, and hasn't been built yet.
///
/// Until it is: this class does nothing, cleanly, so you get silence
/// instead of a crashing/spamming ffmpeg process. Your normal microphone
/// still works fine in Discord/Twitch/etc in the meantime — this only
/// affects routing the *transformed* voice-effect output to a virtual
/// input.
class VirtualAudioCableProvider implements VirtualMicrophoneProvider {
  @override
  String get id => 'virtual_audio_cable';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {
    // ignore: avoid_print
    print('[VirtualAudioCableProvider] Not implemented yet — see class doc '
        'comment. Transformed audio is not being routed anywhere; your '
        'normal microphone is unaffected.');
  }

  @override
  Future<void> pushAudio(AudioFrame frame) async {
    // Intentionally does nothing — see class doc comment.
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
