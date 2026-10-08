# Moonlight Studio

A personal, local-first real-time AI avatar/voice transformation studio.
Take a self-designed avatar image, drive it live from your webcam and
microphone, and expose the result as a normal virtual camera + virtual
microphone that Twitch (via OBS), Discord, Zoom, and similar apps can
select as their input device.

Built for anonymous streaming with a self-made avatar (VTubing-style) —
not for impersonating real people. Every frame the app outputs carries a
small "Moonlight Studio" watermark, bottom-right, baked in by the
Compositor and not user-toggleable.

## Architecture in one sentence

Every AI component (motion tracking, avatar animation, lip sync, voice
transformation, virtual camera/mic) sits behind a small Dart interface in
`domain/interfaces/`; nothing else in the app is allowed to know which
concrete engine is running. See `docs/architecture.md`.

## Requirements

- **Windows 10/11** (primary target)
- **Flutter SDK** (stable channel) — <https://docs.flutter.dev/get-started/install/windows>
- **Python 3.10+** on PATH, for the optional GPU-backed workers
  (LivePortrait/MuseTalk/Wav2Lip) — not required for development mode
- A GPU is only needed once you enable LivePortrait/MuseTalk; the default
  `SimpleAvatarEngine` + DSP voice effects run on CPU only

## First run

```powershell
cd app
flutter create --platforms=windows .   # generates windows/ platform runner (not hand-written here)
flutter pub get
flutter run -d windows
```

This launches with the development-mode pipeline: mock motion tracking +
`SimpleAvatarEngine` (your avatar image driven by cheap 2D transforms) +
DSP voice effects — no model downloads, no Python required. See
`docs/development.md`.

## Enabling a real avatar engine (LivePortrait)

`python/workers/liveportrait_worker/liveportrait/` already contains
LivePortrait's actual source (MIT license, vendored from
KwaiVGI/LivePortrait — not a stub). What's left:

1. Read `docs/engine-evaluation.md` — it documents a real integration
   gap (LivePortrait's public API is a batch/video pipeline, not a
   native live-frame API) and which approach this worker currently uses.
2. Install a GPU-matched torch build per LivePortrait's own README.
3. Download the pretrained weights automatically:
   ```powershell
   pip install -r python/requirements/download.txt
   python scripts/setup/download_liveportrait_weights.py
   ```
   (or `download_all_weights.py` to fetch LivePortrait + MuseTalk +
   Wav2Lip in one go). These scripts run the exact same
   huggingface_hub/gdown calls the upstream projects' own download
   scripts use — see docs/engine-evaluation.md for exactly what each
   fetches and from where.
4. `pip install -r python/requirements/liveportrait.txt`
5. Set `avatar.engine: liveportrait` in `config/default.yaml`.

MuseTalk and Wav2Lip follow the same pattern — real vendored code, real
pinned dependencies, and a real automated weight-download script for
each. Where the streaming-inference glue code still needs writing/testing
against a real GPU, the worker reports a specific `NotImplementedError`
rather than faking output — see `docs/engine-evaluation.md` for exactly
what's missing in each case. Wav2Lip's license also restricts commercial
use — read that section before enabling it if the stream is ever
monetized.

## Adding a new engine

See `docs/adding-an-engine.md` — implement the interface, register it in
`lib/app/bootstrap.dart`, done. No other file should need to change.

## Repository layout

```
app/            Flutter application (Dart)
python/         Python AI worker processes + shared protocol
models/         Downloaded model weights (gitignored, not included)
docs/           Architecture, engine, and setup documentation
scripts/        Setup/dev/packaging helper scripts (add as needed)
tests/          Domain/infrastructure/adapter tests
config/         default.yaml — engine selection without code changes
```

## Documentation index

- `docs/architecture.md` — layers, frame/audio pipeline, diagrams
- `docs/engines.md` — interface list, what each v1 engine actually does
- `docs/adding-an-engine.md` — the one workflow you need for new engines
- `docs/virtual-devices.md` — OBS virtual camera + virtual audio cable setup
- `docs/engine-evaluation.md` — license/hardware notes on LivePortrait/MuseTalk/Wav2Lip/MediaPipe
- `docs/development.md` — running with zero AI models installed, tests

## Privacy

Local-first by design: camera, microphone, and all inference stay on your
machine. No cloud upload, no telemetry, no accounts.
