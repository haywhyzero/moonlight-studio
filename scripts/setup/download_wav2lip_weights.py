"""
Downloads the Wav2Lip+GAN checkpoint from the exact Google Drive link
Rudrabha/Wav2Lip's own README lists, into
python/workers/wav2lip_worker/wav2lip/checkpoints/wav2lip_gan.pth.

The face-detection (s3fd) weights do NOT need a separate download step:
face_detection/detection/sfd/sfd_detector.py fetches them automatically
via torch.utils.model_zoo the first time the worker actually runs
face detection, and caches them in torch's usual model cache
(~/.cache/torch/hub/checkpoints on Windows: %USERPROFILE%/.cache/torch/hub/checkpoints).
That's upstream's own design, not something skipped here.

LICENSE REMINDER: Wav2Lip's README states personal/research/non-commercial
use only — see docs/engine-evaluation.md before using this on a monetized
stream.

Usage:
    pip install -r python/requirements/download.txt
    python scripts/setup/download_wav2lip_weights.py
"""

import os
import sys

DEST = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..",
    "python", "workers", "wav2lip_worker", "wav2lip", "checkpoints",
))

# The exact file ID from Rudrabha/Wav2Lip's README "Wav2Lip + GAN" link:
# https://drive.google.com/file/d/15G3U08c8xsCkOqQxE38Z2XXDnPcOptNk/view
GDRIVE_FILE_ID = "15G3U08c8xsCkOqQxE38Z2XXDnPcOptNk"


def main():
    try:
        import gdown
    except ImportError:
        print("gdown not installed — pip install -r python/requirements/download.txt", file=sys.stderr)
        sys.exit(1)

    os.makedirs(DEST, exist_ok=True)
    out_path = os.path.join(DEST, "wav2lip_gan.pth")
    print(f"Downloading Wav2Lip+GAN checkpoint -> {out_path} ...")
    gdown.download(id=GDRIVE_FILE_ID, output=out_path, quiet=False)
    print("Done.")
    print(
        "Note: face-detection (s3fd) weights download automatically on "
        "first run via torch's own model cache — no separate step needed."
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"Download failed: {exc}", file=sys.stderr)
        print(
            "Google Drive sometimes rate-limits automated downloads of "
            "popular files with a 'too many users' warning. If gdown fails "
            "repeatedly, download manually from:\n"
            "https://drive.google.com/file/d/15G3U08c8xsCkOqQxE38Z2XXDnPcOptNk/view\n"
            f"and place it at {os.path.join(DEST, 'wav2lip_gan.pth')}",
            file=sys.stderr,
        )
        sys.exit(1)
