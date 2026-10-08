"""
Convenience wrapper: runs all three engine weight-download scripts in
sequence. Each one is also runnable standalone if you only want one
engine — see the individual scripts for what each actually fetches and
from where.

Usage:
    pip install -r python/requirements/download.txt
    python scripts/setup/download_all_weights.py
"""

import subprocess
import sys
from pathlib import Path

SCRIPTS = [
    "download_liveportrait_weights.py",
    "download_musetalk_weights.py",
    "download_wav2lip_weights.py",
]


def main():
    here = Path(__file__).parent
    failures = []
    for script in SCRIPTS:
        print(f"\n=== {script} ===")
        result = subprocess.run([sys.executable, str(here / script)])
        if result.returncode != 0:
            failures.append(script)

    if failures:
        print(f"\nCompleted with failures in: {', '.join(failures)}")
        print("Re-run the failed script(s) individually once the underlying issue is fixed.")
        sys.exit(1)
    print("\nAll weight downloads completed.")


if __name__ == "__main__":
    main()
