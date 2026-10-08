"""
Downloads LivePortrait's pretrained weights from Hugging Face
(KwaiVGI/LivePortrait) directly into
python/workers/liveportrait_worker/liveportrait/pretrained_weights/.

This is the exact method LivePortrait's own README recommends
(huggingface_hub download of the full repo) — just automated instead of
a manual copy-paste.

Usage:
    pip install -r python/requirements/download.txt
    python scripts/setup/download_liveportrait_weights.py

If you're in a region where huggingface.co is slow/blocked, set the
HF_ENDPOINT environment variable to https://hf-mirror.com before running
this (that's what LivePortrait's own maintainers point Chinese users to).
"""

import os
import sys

from huggingface_hub import snapshot_download

REPO_ID = "KwaiVGI/LivePortrait"
DEST = os.path.join(
    os.path.dirname(__file__), "..", "..",
    "python", "workers", "liveportrait_worker", "liveportrait", "pretrained_weights",
)


def main():
    dest = os.path.abspath(DEST)
    os.makedirs(dest, exist_ok=True)
    print(f"Downloading {REPO_ID} into {dest} ...")
    print("This includes both the LivePortrait and InsightFace weight sets "
          "and can be several GB — it may take a while.")
    snapshot_download(
        repo_id=REPO_ID,
        local_dir=dest,
        local_dir_use_symlinks=False,
        # README.md/docs aren't needed at runtime; skip them to save time.
        ignore_patterns=["README.md", "docs/*", "*.git*"],
    )
    print("Done. Weights are in:", dest)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"Download failed: {exc}", file=sys.stderr)
        print(
            "If huggingface.co is unreachable from your network, try:\n"
            "  set HF_ENDPOINT=https://hf-mirror.com   (Windows cmd)\n"
            "  $env:HF_ENDPOINT=\"https://hf-mirror.com\"   (PowerShell)\n"
            "then re-run this script.",
            file=sys.stderr,
        )
        sys.exit(1)
