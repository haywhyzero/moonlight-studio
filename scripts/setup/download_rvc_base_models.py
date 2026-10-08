"""
Downloads RVC's base feature-extraction models — the ones needed for
real-time voice CONVERSION regardless of which target voice you use.

This is NOT the same thing as a "voice model": this downloads the shared
HuBERT content-encoder and RMVPE pitch-extraction models RVC's pipeline
always needs. A voice model (.pth + .index, one per target voice) is a
separate thing you either train yourself with RVC's own training tools
or obtain from elsewhere — see docs/engine-evaluation.md's "Adding a
voice" section for why this app doesn't have a one-click "clone from a
5-second sample" button (RVC's real cloning process needs a training
step, not just a sample upload).

Reproduces exactly the commands in RVC-Project's own README ("下载模型"
section) for the inference-only assets, using huggingface_hub's Python
API instead of the `hf` CLI shim so it doesn't depend on that being on
PATH.

Usage:
    pip install -r python/requirements/download.txt
    python scripts/setup/download_rvc_base_models.py
"""

import os
import sys

from huggingface_hub import snapshot_download, hf_hub_download

REPO_ID = "lj1995/VoiceConversionWebUI"
ASSETS_ROOT = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..",
    "python", "workers", "voice_clone_worker", "rvc", "assets",
))


def main():
    os.makedirs(ASSETS_ROOT, exist_ok=True)

    print(f"Downloading HuBERT content encoder -> {ASSETS_ROOT}/hubert_base/ ...")
    snapshot_download(
        repo_id=REPO_ID,
        local_dir=ASSETS_ROOT,
        local_dir_use_symlinks=False,
        allow_patterns=["hubert_base/*"],
    )

    rmvpe_dir = os.path.join(ASSETS_ROOT, "rmvpe")
    os.makedirs(rmvpe_dir, exist_ok=True)
    print(f"Downloading RMVPE pitch model -> {rmvpe_dir}/rmvpe.pt ...")
    hf_hub_download(
        repo_id=REPO_ID,
        filename="rmvpe.pt",
        local_dir=rmvpe_dir,
        local_dir_use_symlinks=False,
    )

    print("\nDone. These are the shared inference assets only.")
    print("You still need an actual voice model (.pth, optionally + .index) "
          "for whichever voice you want to convert to — see "
          "docs/engine-evaluation.md.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"Download failed: {exc}", file=sys.stderr)
        print(
            "If huggingface.co is unreachable from your network, try setting\n"
            "HF_ENDPOINT=https://hf-mirror.com before re-running this script.",
            file=sys.stderr,
        )
        sys.exit(1)
