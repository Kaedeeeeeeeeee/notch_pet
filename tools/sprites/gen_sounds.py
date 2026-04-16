#!/usr/bin/env python3
"""Generate 8-bit style SFX for NotchPet.

Emits six short WAV files to NotchPet/Assets/Audio/. stdlib only
(`wave`, `struct`, `math`). Run via:

    python3 tools/sprites/gen_sounds.py

AudioServicesCreateSystemSoundID accepts .aif / .caf / .wav; we use
.wav because Python 3.13+ removed the stdlib `aifc` module.
"""

from __future__ import annotations

import math
import os
import struct
import sys
import wave

SAMPLE_RATE = 22050
SAMPLE_WIDTH = 2  # 16-bit
AMPLITUDE = 0.60  # 60% — leave headroom for combined play
OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "..",
    "NotchPet",
    "Assets",
    "Audio",
)


def square(t: float, freq: float) -> float:
    return 1.0 if (t * freq) % 1.0 < 0.5 else -1.0


def triangle(t: float, freq: float) -> float:
    phase = (t * freq) % 1.0
    if phase < 0.5:
        return 4.0 * phase - 1.0
    return 3.0 - 4.0 * phase


def synth_segment(
    freq: float,
    duration: float,
    waveform: str = "square",
    envelope: str = "linear",
) -> list[int]:
    """Generate PCM samples for one segment."""
    wave_fn = square if waveform == "square" else triangle
    n = int(duration * SAMPLE_RATE)
    out: list[int] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = wave_fn(t, freq)
        if envelope == "linear":
            env = 1.0 - (i / max(1, n))
        elif envelope == "slow":
            env = 1.0 - 0.5 * (i / max(1, n))
        elif envelope == "adsr":
            # quick attack → hold → linear release
            if i < n * 0.1:
                env = i / (n * 0.1)
            elif i < n * 0.6:
                env = 1.0
            else:
                env = 1.0 - (i - n * 0.6) / (n * 0.4)
        else:
            env = 1.0
        sample = s * env * AMPLITUDE
        out.append(max(-32767, min(32767, int(sample * 32767))))
    return out


def synth_sound(spec: list[tuple[float, float, str, str]]) -> list[int]:
    """`spec` is a list of (freq, duration, waveform, envelope) segments."""
    samples: list[int] = []
    for freq, duration, wave, env in spec:
        samples.extend(synth_segment(freq, duration, wave, env))
    return samples


def write_wav(path: str, samples: list[int]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(SAMPLE_WIDTH)
        out.setframerate(SAMPLE_RATE)
        # WAV is little-endian signed 16-bit PCM.
        frame_bytes = b"".join(struct.pack("<h", s) for s in samples)
        out.writeframes(frame_bytes)


# ---------------------------------------------------------------
# Sound recipes (see plan file for the table)
# ---------------------------------------------------------------

SOUNDS: dict[str, list[tuple[float, float, str, str]]] = {
    # Chomp — fast freq sweep
    "feed": [
        (440.0, 0.040, "square", "linear"),
        (520.0, 0.040, "square", "linear"),
        (660.0, 0.040, "square", "linear"),
    ],
    # Bounce — three-step jump
    "play": [
        (660.0, 0.060, "square", "linear"),
        (880.0, 0.060, "square", "linear"),
        (660.0, 0.060, "square", "linear"),
    ],
    # Yawn — slow descending triangle
    "rest": [
        (220.0, 0.100, "triangle", "slow"),
        (165.0, 0.100, "triangle", "slow"),
    ],
    # Hatch — ascending chirp with a held middle note
    "hatch": [
        (523.0, 0.100, "square", "adsr"),
        (784.0, 0.120, "square", "adsr"),
        (1047.0, 0.130, "square", "linear"),
    ],
    # Farewell — slow descending triangle (tragic fall)
    "depart": [
        (330.0, 0.200, "triangle", "linear"),
        (165.0, 0.200, "triangle", "linear"),
        (82.0,  0.200, "triangle", "slow"),
    ],
    # Jingle — three ascending notes
    "happy": [
        (784.0,  0.080, "square", "linear"),
        (988.0,  0.080, "square", "linear"),
        (1175.0, 0.090, "square", "linear"),
    ],
    # Aloof feed rejection — short descending "nope"
    "feedReject": [
        (660.0, 0.060, "square", "linear"),
        (440.0, 0.080, "square", "linear"),
    ],
    # Grumpy anger buzz — low sustained growl
    "angry": [
        (140.0, 0.100, "triangle", "slow"),
        (110.0, 0.120, "triangle", "linear"),
    ],
    # Medicine — soft bell ding
    "medicine": [
        (1047.0, 0.080, "triangle", "linear"),
        (1319.0, 0.120, "triangle", "linear"),
    ],
    # Clean sweep — airy rising chirp
    "clean": [
        (660.0, 0.050, "square", "linear"),
        (880.0, 0.050, "square", "linear"),
        (1100.0, 0.070, "square", "linear"),
    ],
}


def main() -> int:
    out_dir = os.path.normpath(OUT_DIR)
    for name, spec in SOUNDS.items():
        samples = synth_sound(spec)
        path = os.path.join(out_dir, f"{name}.wav")
        write_wav(path, samples)
        size = os.path.getsize(path)
        print(f"  {name:7} → {path} ({size} bytes, {len(samples)} samples)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
