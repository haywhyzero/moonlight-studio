# Virtual Camera & Microphone

## Why OBS first, and how video actually reaches it

OBS already ships a working, widely-compatible virtual camera
(obs-virtualcam) that Discord/Zoom/Meet/Skype all recognize as a normal
webcam. Reusing it for v1 avoids writing and signing a Windows camera
driver before the rest of the app even works.

Video reaches OBS via **Window Capture** — you add this app's window as
a source in OBS, the same way you'd add any other application window.
This is standard practice for VTuber-style software (VTube Studio,
Animaze, etc.) and is hardware-accelerated on OBS's side with zero extra
encode/decode work from this app.

An earlier version instead ran a local MJPEG HTTP server and had OBS
re-capture that as a Browser Source. That meant every frame was decoded
once by this app, re-encoded to JPEG, sent over HTTP, decoded again by
OBS, then re-encoded again for OBS's own virtual camera output — three
codec passes for one frame, all competing for a single CPU thread. That
was a real, significant contributor to this app's early performance
problems and has been removed. `ObsVirtualCameraProvider` now only
talks to obs-websocket as a control-plane connection (starting/stopping
OBS's virtual camera) — no pixel data crosses it.

### Setup (current)
1. Install OBS Studio + obs-websocket (bundled in recent OBS versions;
   enable it under Tools > WebSocket Server Settings and note the
   port/password if you set one — needed only for the automatic
   Start/Stop Virtual Camera behavior below, not for video itself).
2. In OBS, add this app's window as a **Window Capture** source.
3. In the calling app (Discord, Zoom, Twitch's OBS-based flow, etc.),
   select "OBS Virtual Camera" as the camera device; Moonlight Studio
   calls `StartVirtualCam`/`StopVirtualCam` over obs-websocket
   automatically when you press Start/Stop Studio if that connection
   succeeded (falls back to toggling it manually in OBS otherwise — see
   the log line `ObsVirtualCameraProvider` prints in that case).

### Path off OBS

`NativeWindowsVirtualCameraProvider` (not yet implemented) will register
a proper Windows virtual camera driver so OBS is optional. Because
everything depends only on `VirtualCameraProvider`, adding it later is a
one-file change plus a config default switch — see
`docs/adding-an-engine.md`'s pattern (same idea applies to providers).

## Virtual microphone

**Not implemented yet — `VirtualAudioCableProvider` is currently an
honest no-op.** An earlier version shelled out to
`ffmpeg -f dsound "<device>"` to pipe transformed PCM into a virtual
cable's playback device. That doesn't work: FFmpeg's own documentation
lists `dsound` only as an INPUT (capture) device — it has never existed
as an output/playback muxer, on any version. There is no built-in FFmpeg
CLI mechanism for playing audio out to an arbitrary named Windows device.

The real way to do this is WASAPI directly — the same approach
Discord/VoiceMeeter-style tools use — via Win32 COM interop (Dart FFI +
the `win32` package), opening a shared-mode render client on the target
endpoint (e.g. VB-CABLE's "CABLE Input"). That's meaningfully new code,
not a config fix, and hasn't been built yet. Your normal microphone
still works fine in Discord/Twitch/etc in the meantime — this only
affects routing the app's own voice-effect output into a virtual input.

## For Twitch specifically

Twitch itself doesn't need a virtual camera if you're already using OBS
to stream — you can add Moonlight Studio's output directly as an OBS
source instead of round-tripping through "OBS Virtual Camera". The
virtual-camera path matters when you want the transformed feed inside a
*different* app (Discord call, Zoom, etc.) that isn't OBS itself.
