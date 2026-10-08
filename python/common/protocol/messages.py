"""
Shared JSON message protocol for Flutter <-> Python worker IPC over a
localhost WebSocket. Every worker (motion, liveportrait, musetalk,
wav2lip, voice) speaks this same envelope so WorkerIpcClient on the Dart
side needs no per-engine special-casing.

Inbound (Flutter -> worker):
    {"type": "init", "config": {...}}
    {"type": "prepare", "imagePath": "..."}
    {"type": "frame", "seq": <int>, "payload_b64": "...", "motion": {...}}
    {"type": "shutdown"}

Outbound (worker -> Flutter):
    {"type": "ready"}
    {"type": "prepare_result", "success": bool, "cacheData": {...}, "error": str|None}
    {"type": "result", "seq": <int>, "payload_b64": "..."}
    {"type": "error", "message": "..."}

All video payload_b64 fields (both directions) are PNG-encoded image bytes,
not a raw pixel buffer — this matches VideoPixelFormat.encodedPng on the
Dart side (see domain/models/video_frame.dart) and lets a worker decode
with any standard image library (Pillow's Image.open, etc.) without also
needing to know width/height/stride out of band.

Workers also print plain-text status lines to stdout for WorkerManager's
lightweight state parser: LOADING_MODEL / READY / PROCESSING / DEGRADED.
"""

import json


def parse(raw: str) -> dict:
    return json.loads(raw)


def encode(message: dict) -> str:
    return json.dumps(message)


def error(message: str) -> str:
    return encode({"type": "error", "message": message})


def result(seq: int, payload_b64: str) -> str:
    return encode({"type": "result", "seq": seq, "payload_b64": payload_b64})
