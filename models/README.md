# Models

This directory holds downloaded model weights, one subdirectory per
engine. Nothing here is included in the repository or auto-downloaded by
the app — model weights are large and often have their own license terms
separate from the inference code.

Expected layout once populated:

```
models/
├── liveportrait/    # see docs/engine-evaluation.md before downloading
├── musetalk/
└── wav2lip/
```

The app's Diagnostics screen (planned) will report which engines have
their weights installed and their approximate disk usage — see
`docs/architecture.md`'s Model Management section.
