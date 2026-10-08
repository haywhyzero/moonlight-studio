# Development Mode

Run the app with zero AI models installed using the mock engines already
wired up in `lib/app/bootstrap.dart` and the default config
(`config/default.yaml`, `avatar.engine: simple_avatar`, `motion.engine:
mock_motion`, `lipsync.engine: none`):

```
Camera → MockMotionTracker → SimpleAvatarEngine → Compositor → Virtual Camera
```

This exercises the complete pipeline — camera capture, motion data flow,
avatar processing, watermarking, and virtual device output — before any
GPU model is installed. Switch `avatar.engine` to `mock_avatar` for pure
passthrough, or to `liveportrait` once you've completed its setup (see
`docs/engine-evaluation.md` and the docstring in
`lib/engines/avatar/live_portrait/live_portrait_engine.dart`).

## Running Python workers standalone (for debugging)

```
cd python
pip install -r requirements/base.txt
python workers/liveportrait_worker/main.py --port 8801
```

It will report `DEGRADED liveportrait model/code not installed` on
stdout until you complete the setup steps in its own docstring — this is
expected and correct behavior, not a bug.

## Tests

```
cd app
flutter test
```

`tests/domain/` covers the registry, pipeline config, and session
lifecycle using the mock engines only — no Flutter widget dependencies,
no AI model required.
