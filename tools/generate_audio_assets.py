#!/usr/bin/env python3
"""Generate Almsth's original deterministic mono PCM sound set."""

from __future__ import annotations

import math
import random
import struct
from pathlib import Path
from typing import Callable, Iterable


SAMPLE_RATE = 22_050
PEAK = 0.48
SEED = 0xA1_57_4D
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"


def _fade(index: int, count: int, edge_seconds: float = 0.012) -> float:
    edge = max(1, int(SAMPLE_RATE * edge_seconds))
    return min(1.0, index / edge, (count - 1 - index) / edge)


def _normalize(samples: Iterable[float]) -> list[float]:
    values = list(samples)
    maximum = max((abs(value) for value in values), default=1.0)
    scale = PEAK / maximum if maximum > PEAK else 1.0
    return [max(-PEAK, min(PEAK, value * scale)) for value in values]


def _tone(
    duration: float,
    frequency: Callable[[float], float],
    amplitude: Callable[[float], float],
    noise: float = 0.0,
    seed_offset: int = 0,
) -> list[float]:
    count = int(round(duration * SAMPLE_RATE))
    rng = random.Random(SEED + seed_offset)
    phase = 0.0
    result: list[float] = []
    filtered_noise = 0.0
    for index in range(count):
        t = index / SAMPLE_RATE
        phase += math.tau * frequency(t) / SAMPLE_RATE
        filtered_noise = filtered_noise * 0.72 + rng.uniform(-1.0, 1.0) * 0.28
        result.append(
            (math.sin(phase) * amplitude(t) + filtered_noise * noise)
            * _fade(index, count)
        )
    return _normalize(result)


def _loop(duration: float, components: list[tuple[float, float, float]]) -> list[float]:
    """Periodic sine components produce matching loop endpoints without recordings."""
    count = int(round(duration * SAMPLE_RATE))
    result: list[float] = []
    for index in range(count):
        t = index / SAMPLE_RATE
        value = 0.0
        for cycles_per_loop, amplitude, phase in components:
            value += amplitude * math.sin(math.tau * cycles_per_loop * t / duration + phase)
        result.append(value)
    return _normalize(result)


def _write_wav(path: Path, samples: list[float], loop: bool = False) -> None:
    pcm = b"".join(
        struct.pack("<h", int(round(max(-1.0, min(1.0, sample)) * 32767.0)))
        for sample in samples
    )
    chunks = [
        (b"fmt ", struct.pack("<HHIIHH", 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)),
        (b"data", pcm),
    ]
    if loop:
        sample_period = round(1_000_000_000 / SAMPLE_RATE)
        smpl_header = struct.pack(
            "<9I", 0, 0, sample_period, 60, 0, 0, 0, 1, 0
        )
        smpl_loop = struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks.append((b"smpl", smpl_header + smpl_loop))
    body = b"WAVE"
    for chunk_id, chunk_data in chunks:
        body += chunk_id + struct.pack("<I", len(chunk_data)) + chunk_data
        if len(chunk_data) % 2:
            body += b"\0"
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def _mix(*tracks: list[float]) -> list[float]:
    count = max((len(track) for track in tracks), default=0)
    return _normalize(
        sum(track[index] if index < len(track) else 0.0 for track in tracks)
        for index in range(count)
    )


def generate() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    loops = {
        "base_ambience.wav": _loop(8.0, [
            (176.0, 0.16, 0.1), (264.0, 0.08, 1.2), (440.0, 0.035, 2.0),
            (9.0, 0.025, 0.5), (13.0, 0.018, 2.4),
        ]),
        "dungeon_ambience.wav": _loop(8.0, [
            (120.0, 0.19, 0.2), (168.0, 0.10, 1.9), (232.0, 0.045, 0.8),
            (5.0, 0.035, 2.7), (17.0, 0.015, 1.3),
        ]),
    }
    sounds = {
        "ui_confirm.wav": _tone(0.13, lambda t: 620 + 900 * t, lambda t: 0.24 * (1 - t / 0.13), seed_offset=1),
        "ui_cancel.wav": _tone(0.15, lambda t: 470 - 900 * t, lambda t: 0.22 * (1 - t / 0.15), seed_offset=2),
        "step.wav": _tone(0.10, lambda _t: 82, lambda t: 0.28 * (1 - t / 0.10), 0.10, 3),
        "dash.wav": _tone(0.28, lambda t: 170 + 520 * t, lambda t: 0.20 * math.sin(math.pi * t / 0.28), 0.18, 4),
        "melee_attack.wav": _tone(0.18, lambda t: 310 - 1_000 * t, lambda t: 0.24 * (1 - t / 0.18), 0.16, 5),
        "player_hurt.wav": _tone(0.25, lambda t: 115 - 140 * t, lambda t: 0.30 * (1 - t / 0.25), 0.08, 6),
        "ranged_shot.wav": _mix(
            _tone(0.16, lambda t: 920 - 2_400 * t, lambda t: 0.23 * (1 - t / 0.16), 0.06, 7),
            _tone(0.07, lambda _t: 148, lambda t: 0.17 * (1 - t / 0.07), seed_offset=8),
        ),
        "magic_cast.wav": _mix(
            _tone(0.34, lambda t: 380 + 1_600 * t, lambda t: 0.18 * math.sin(math.pi * t / 0.34), seed_offset=9),
            _tone(0.34, lambda t: 610 + 900 * t, lambda t: 0.10 * math.sin(math.pi * t / 0.34), seed_offset=10),
        ),
        "chest_open.wav": _mix(
            _tone(0.34, lambda t: 96 + 80 * t, lambda t: 0.18 * (1 - t / 0.34), 0.10, 11),
            _tone(0.34, lambda t: 520 + 220 * t, lambda t: 0.10 * math.sin(math.pi * t / 0.34), seed_offset=12),
        ),
        "world_transition.wav": _tone(0.55, lambda t: 90 + 430 * (t / 0.55) ** 2, lambda t: 0.24 * math.sin(math.pi * t / 0.55), 0.05, 13),
        "station_success.wav": _mix(
            _tone(0.36, lambda _t: 440, lambda t: 0.15 * (1 - t / 0.36), seed_offset=14),
            _tone(0.36, lambda _t: 660, lambda t: 0.12 * (1 - t / 0.36), seed_offset=15),
        ),
        "station_fail.wav": _tone(0.24, lambda t: 125 - 170 * t, lambda t: 0.30 * (1 - t / 0.24), 0.09, 16),
        "evolution.wav": _mix(
            _tone(0.90, lambda t: 180 + 520 * t, lambda t: 0.14 * math.sin(math.pi * t / 0.90), seed_offset=17),
            _tone(0.90, lambda t: 270 + 780 * t, lambda t: 0.11 * math.sin(math.pi * t / 0.90), seed_offset=18),
        ),
        "death.wav": _mix(
            _tone(1.05, lambda t: 180 - 115 * t / 1.05, lambda t: 0.22 * (1 - t / 1.05), seed_offset=19),
            _tone(1.05, lambda t: 95 - 45 * t / 1.05, lambda t: 0.14 * (1 - t / 1.05), 0.04, 20),
        ),
    }
    for name, samples in loops.items():
        _write_wav(OUTPUT / name, samples, loop=True)
    for name, samples in sounds.items():
        _write_wav(OUTPUT / name, samples)
    print(f"Generated {len(loops) + len(sounds)} deterministic WAV files in {OUTPUT}")


if __name__ == "__main__":
    generate()
