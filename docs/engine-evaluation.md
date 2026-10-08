# Engine Evaluation Notes

Updated from direct inspection of the actual upstream repos (cloned and
checked, not recalled from memory) — see each vendored engine directory
for the exact source. Re-check upstream before relying on any of this
long after this doc was written; repos change.

## RVC — Retrieval-based Voice Conversion (RVC-Project/Retrieval-based-Voice-Conversion-WebUI)
- **License**: MIT. Vendored at
  `python/workers/voice_clone_worker/rvc/` (LICENSE included) — the
  real-time inference subset only (`infer/rtrvc.py` + its direct
  dependencies), not RVC's WebUI or training tools.
- **Weights**: `scripts/setup/download_rvc_base_models.py` fetches the
  shared HuBERT + RMVPE feature-extraction models (from Hugging Face,
  `lj1995/VoiceConversionWebUI`) every conversion needs regardless of
  target voice. A per-voice `.pth`/`.index` model is a SEPARATE thing —
  see "What a voice actually is" below.
- **What a voice actually is — this is the important part**: RVC has no
  code path that turns one raw audio sample into a usable voice model.
  `RVC(...)` loads an already-TRAINED `.pth` file. Getting one means
  either using an existing trained model (yours from a previous run, or
  a community one) or running RVC's own training pipeline against
  several minutes of clean audio — a real, non-instant GPU job. The
  Effects panel's Voice Model picker expects an already-trained
  `.pth`/optional `.index` pair; there's no "record 10 seconds and go
  live" button because that isn't a real capability of this technology.
- **Real API shape**: better than LivePortrait/MuseTalk here —
  `infer/rtrvc.py`'s `RVC` class is a purpose-built real-time streaming
  API (`.infer()` per audio chunk), not a batch/file pipeline. But the
  reference client (`realtime_gui.py`) wraps that call in ~150 lines of
  stateful SOLA (cross-correlation-based crossfade) buffer management to
  avoid audible clicks where consecutive converted chunks join. That
  logic was deliberately NOT blind-ported here: it's GPU-tensor-heavy and
  only verifiable by actually running and listening to output, which
  this sandbox cannot do. `VoiceCloneEngine`/the worker load the model
  for real (verifiable by reading — it's just object construction) and
  raise a specific, named error for the missing buffering loop rather
  than guessing at DSP correctness that could produce bad-sounding audio
  while appearing to "work."
- **GPU**: strongly recommended for real-time use; CPU works but expect
  higher latency.

## Downloading weights (automated)

`scripts/setup/download_<engine>_weights.py` automates the exact
download steps each upstream repo's own README/scripts specify —
`huggingface_hub`/`gdown` calls, not this sandbox trying to fetch
anything itself. Run them from your own machine, where huggingface.co
and Google Drive are ordinary reachable websites:

```
pip install -r python/requirements/download.txt
python scripts/setup/download_all_weights.py
```

or run one engine's script individually. Each script's docstring states
exactly which upstream repo/file it pulls from and what to do if a host
is unreachable from your network (a mirror env var for Hugging Face,
manual fallback for the one Google Drive file Wav2Lip needs).

This sandbox could not run these itself and verify the downloads
complete — huggingface.co/drive.google.com aren't on its network
allow-list — so treat your first real run of these scripts as the actual
first test of them, same caveat as the inference-loop code in
docs/engines.md.

## LivePortrait (KwaiVGI/LivePortrait)
- **License**: MIT. Vendored in full at
  `python/workers/liveportrait_worker/liveportrait/` (LICENSE included).
- **Weights**: NOT bundled, but `scripts/setup/download_liveportrait_weights.py`
  automates fetching them from Hugging Face (`KwaiVGI/LivePortrait`) —
  this sandbox's network policy only allows GitHub, so the script itself
  was written and vetted here but needs to actually run on your machine.
- **Real API shape**: `LivePortraitPipeline.execute()` (in
  `src/live_portrait_pipeline.py`) is a batch/CLI pipeline — source image
  path + driving *video file* path in, output video file out. It is
  **not** a native "process one live frame" API. See
  `liveportrait_worker/main.py`'s docstring for the two ways to bridge
  that gap and which one is actually implemented (the slower one; the
  fast one needs a GPU to write/verify).
- **GPU**: strongly recommended; requirements pin `onnxruntime-gpu`.

## MuseTalk (TMElyralab/MuseTalk)
- **License**: MIT. Vendored at
  `python/workers/musetalk_worker/musetalk/` (LICENSE included).
- **Weights**: NOT bundled, but `scripts/setup/download_musetalk_weights.py`
  reproduces the upstream repo's own `download_weights.bat`/`.sh` exactly
  (same Hugging Face repos, same Google Drive file for face-parse-bisent)
  as a single cross-platform Python script.
- **Real-time claim**: the upstream repo does document a real-time mode,
  unlike LivePortrait — but its published fps benchmark is on an NVIDIA
  V100. Treat "real-time" as GPU-class hardware, not a low-end-CPU claim.
- **Integration state**: code is vendored, but the persistent-loop glue
  around `musetalk/models/unet.py` + `musetalk/whisper/` has not been
  written — needs real weights + GPU to do correctly. Currently reports
  `NotImplementedError` rather than faking output.

## Wav2Lip (Rudrabha/Wav2Lip)
- **License — read this before shipping**: no LICENSE file; the README
  states the repo "can only be used for personal/research/non-commercial
  purposes," with commercial use requiring direct contact with the
  authors. If Moonlight Studio's stream is ever monetized, revisit
  whether that counts as commercial use of this specific component.
- **Weights**: NOT bundled, but `scripts/setup/download_wav2lip_weights.py`
  fetches the exact `wav2lip_gan.pth` file the upstream README links on
  Google Drive, by its real file ID. Face-detection (s3fd) weights need
  no separate step — `face_detection/`'s own code fetches those via
  torch's model cache on first use, which is upstream's design, not
  something skipped here.
- **Real API shape**: better than LivePortrait/MuseTalk here —
  `inference.py`'s `load_model()` function and the `Wav2Lip` class
  (`models/wav2lip.py`) are plain, reusable, not CLI-locked. The worker
  actually calls these directly. What's still missing is adapting the
  batch face-crop + mel-spectrogram preprocessing (`face_detect()` /
  `datagen()` in the vendored `inference.py`) to a single streaming
  frame — flagged with a clear `NotImplementedError`, not faked.
- **Pinned versions are old** (torch 1.1.0, numpy 1.17) — expect to need
  updated, compatible pins on a modern system; check the upstream repo's
  GitHub issues for community-maintained version fixes before assuming
  these exact pins install cleanly.

## MediaPipe
- Used for the eventual real `MotionTracker`. Runs on CPU, unlike the
  three engines above — this is why it stays the default motion-tracking
  candidate even on low-end hardware.

## What "vendored" means here, precisely
Each engine's actual inference source code (not demo assets, not
training scripts, not pretrained weights) has been copied into
`python/workers/<engine>_worker/<engine>/` from the real upstream repo.
`requirements_upstream.txt` in each of those directories is the
untouched original for reference; `python/requirements/<engine>.txt` is
the version this project actually installs from, with notes on what to
install manually first (GPU-matched torch builds).

## What is not done, and why
Downloading pretrained weights: blocked by this sandbox's network policy
(GitHub only) — a real, checkable constraint, not a shortcut. Writing and
verifying real-time inference glue code against those weights: requires
a GPU this sandbox doesn't have. Both are explicitly your next steps, not
silently skipped. For RVC specifically, there's a third thing that's on
you regardless of GPU access: actually training or obtaining a `.pth`
voice model in the first place — that's a real RVC workflow (or a
community-shared model), not something this app can generate from a
sample.
