"""
Downloads all of MuseTalk's weights — reproducing exactly what
TMElyralab/MuseTalk's own download_weights.bat does, just as a
cross-platform Python script instead of a Windows batch file (their .bat
depends on the `hf` CLI shim being on PATH, which isn't guaranteed right
after `pip install`; calling huggingface_hub's Python API directly avoids
that).

Fetches, into python/workers/musetalk_worker/musetalk/models/:
    musetalk/            (TMElyralab/MuseTalk)
    musetalkV15/          (TMElyralab/MuseTalk)
    sd-vae/                (stabilityai/sd-vae-ft-mse)
    whisper/               (openai/whisper-tiny)
    dwpose/                (yzd-v/DWPose)
    syncnet/               (ByteDance/LatentSync)
    face-parse-bisent/     (Google Drive + a direct pytorch.org URL)

Usage:
    pip install -r python/requirements/download.txt
    python scripts/setup/download_musetalk_weights.py
"""

import os
import sys

import requests
from huggingface_hub import snapshot_download

MODELS_ROOT = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..",
    "python", "workers", "musetalk_worker", "musetalk", "models",
))


def hf(repo_id, subdir, allow_patterns=None):
    dest = os.path.join(MODELS_ROOT, subdir)
    os.makedirs(dest, exist_ok=True)
    print(f"Downloading {repo_id} -> {dest} ...")
    snapshot_download(
        repo_id=repo_id,
        local_dir=dest,
        local_dir_use_symlinks=False,
        allow_patterns=allow_patterns,
    )


def download_face_parse_bisent():
    dest = os.path.join(MODELS_ROOT, "face-parse-bisent")
    os.makedirs(dest, exist_ok=True)

    try:
        import gdown
    except ImportError:
        print("gdown not installed — pip install -r python/requirements/download.txt", file=sys.stderr)
        raise

    ckpt_path = os.path.join(dest, "79999_iter.pth")
    print(f"Downloading face-parse-bisent checkpoint -> {ckpt_path} ...")
    gdown.download(id="154JgKpzCPW82qINcVieuPH3fZ2e0P812", output=ckpt_path, quiet=False)

    resnet_path = os.path.join(dest, "resnet18-5c106cde.pth")
    print(f"Downloading resnet18 backbone -> {resnet_path} ...")
    resp = requests.get("https://download.pytorch.org/models/resnet18-5c106cde.pth", stream=True)
    resp.raise_for_status()
    with open(resnet_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=1 << 20):
            f.write(chunk)


def main():
    os.makedirs(MODELS_ROOT, exist_ok=True)

    # MuseTalk's own script fetches v1.0 and v1.5 checkpoints from the same
    # repo into two different local subfolders via separate allow_patterns
    # calls — mirrored here rather than pulling the whole repo twice.
    hf("TMElyralab/MuseTalk", "musetalk", allow_patterns=["musetalk/musetalk.json", "musetalk/pytorch_model.bin"])
    hf("TMElyralab/MuseTalk", "musetalkV15", allow_patterns=["musetalkV15/musetalk.json", "musetalkV15/unet.pth"])
    hf("stabilityai/sd-vae-ft-mse", "sd-vae", allow_patterns=["config.json", "diffusion_pytorch_model.bin"])
    hf("openai/whisper-tiny", "whisper", allow_patterns=["config.json", "pytorch_model.bin", "preprocessor_config.json"])
    hf("yzd-v/DWPose", "dwpose", allow_patterns=["dw-ll_ucoco_384.pth"])
    hf("ByteDance/LatentSync", "syncnet", allow_patterns=["latentsync_syncnet.pt"])
    download_face_parse_bisent()

    print("\nAll MuseTalk weights downloaded into:", MODELS_ROOT)


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
