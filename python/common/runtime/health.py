"""Small helpers every worker uses to emit the stdout status lines that
WorkerManager (Dart side) parses. Kept dependency-free on purpose."""

import sys


def loading_model():
    print("LOADING_MODEL", flush=True)


def ready():
    print("READY", flush=True)


def processing():
    print("PROCESSING", flush=True)


def degraded(reason: str = ""):
    print(f"DEGRADED {reason}", flush=True)


def fatal(message: str):
    print(f"FATAL {message}", file=sys.stderr, flush=True)
