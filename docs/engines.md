# Engines

## Interfaces

| Interface | Purpose | v1 implementations |
|---|---|---|
| `MotionTracker` | camera frame → `MotionData` | `MockMotionTracker`; `MediaPipeMotionTracker` (worker stub) |
| `AvatarEngine` | drives a prepared avatar with motion | `MockAvatarEngine`, `SimpleAvatarEngine` (real, non-ML), `LivePortraitEngine` (needs setup) |
| `LipSyncEngine` | optional audio-driven mouth refinement | `MockLipSyncEngine`, `MuseTalkEngine`, `Wav2LipEngine` (both need setup) |
| `VoiceEngine` | live mic transformation | `MockVoiceEngine`, `RealtimeVoiceEffectEngine` (real DSP, runs in-process), `VoiceCloneEngine` (RVC — model loads, real-time buffering not wired yet) |
| `VirtualCameraProvider` | publish frames as a system camera | `ObsVirtualCameraProvider` (needs OBS + obs-websocket) |
| `VirtualMicrophoneProvider` | publish audio as a system mic | `VirtualAudioCableProvider` (needs a virtual audio cable driver) |

## Why "Simple Avatar" exists

`SimpleAvatarEngine` is a legitimate, always-available fallback: it loads
your static designed image and drives it with cheap 2D transforms (yaw
rotation, mouth-open squash) — no GPU, no Python worker, no model
download. It will never look as good as LivePortrait, but it means the
app is usable the moment you `flutter run`, on any hardware.

## Voice: DSP effects vs. voice cloning

`RealtimeVoiceEffectEngine` (pitch shift, robot, radio, echo) is plain
signal processing, not AI voice conversion. Never present it in the UI as
"AI voice cloning" — see the class docstring. A real
`VoiceConversionEngine`/`VoiceCloneEngine` is a future, separate
implementation of the same `VoiceEngine` interface (see `VoiceProfile` in
`domain/models/voice_profile.dart`), landing in
`python/workers/voice_worker/` once you pick a model (RVC/OpenVoice/XTTS).

## Voice cloning (RVC)

`VoiceCloneEngine` wraps RVC (Retrieval-based Voice Conversion,
RVC-Project/Retrieval-based-Voice-Conversion-WebUI, MIT). Real-time voice
conversion needs a TRAINED model for the target voice — a `.pth` file,
optionally paired with a `.index` file — selected in the Effects panel's
Voice section. There is no "clone from one sample" path: RVC's own
training pipeline needs several minutes of clean target-voice audio and
real GPU training time. See docs/engine-evaluation.md for exactly what's
implemented vs. still needs GPU-verified work (short version: model
loading is real; the real-time SOLA crossfade buffering it needs to sound
clean is not wired yet).

## The Effects panel only shows real engines

`mock_*` engines are intentionally hidden from the Effects panel — they
exist for tests and pipeline-plumbing checks, not for a person to
select expecting output. If you're editing bootstrap.dart and want a new
engine to appear in the UI, don't prefix its id with `mock_`.

## Adding a new engine

See `docs/adding-an-engine.md`.
