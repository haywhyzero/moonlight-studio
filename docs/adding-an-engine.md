# Adding a New Engine

Example: you find a better open-source lip-sync model six months from now.

1. Create `lib/engines/lipsync/new_model/new_model_engine.dart`
   implementing `LipSyncEngine` (and, if it needs a Python process, a
   worker under `python/workers/new_model_worker/` speaking the protocol
   in `python/common/protocol/messages.py`).
2. If it runs in-process (pure Dart/DSP, like the voice effects engine),
   skip the worker — just implement the interface directly.
3. Register it in `lib/app/bootstrap.dart`:
   `registry.registerLipSyncEngine(NewModelEngine());`
4. Add its requirements file under `python/requirements/` if applicable.
5. Add a config entry to `config/default.yaml` if you want it selectable
   by default.
6. Write a test under `tests/adapters/` using the same pattern as the
   mock engines.
7. The Settings > AI dropdown and the Studio's Effects panel pick it up
   automatically from `EngineRegistry.lipSyncEngines` — no UI code changes
   needed.

You should **not** need to touch: `StudioSession`, the Studio UI shell,
the camera/audio pipeline, the compositor, or either virtual-device
provider. If you find yourself editing those files to add an engine, the
new engine isn't actually behind the interface — stop and re-check step 1.
