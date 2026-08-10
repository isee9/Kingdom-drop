#!/usr/bin/env python3
"""Synthesise Kingdom Drop's sound effects and music loop.

Every sound in this game is generated from scratch by this script — sine
partials, filtered noise and a Karplus-Strong plucked string. Nothing is
sampled, recorded or licensed from anywhere, which keeps the project free of
third-party audio rights in the same way the art pack keeps it free of
third-party artwork.

Run it from the project root after changing anything here:

    python3 tool/generate_audio.py

It writes MP3s into ``assets/audio/`` and is deterministic (the noise is
seeded), so running it twice produces the same sound.

Requires: numpy, and ffmpeg on PATH for the MP3 encode.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"

SR = 44100


# ------------------------------------------------------------------ envelopes
def env_ad(n: int, attack: float, decay: float, curve: float = 2.5) -> np.ndarray:
    """Attack then exponential-ish decay, both as a fraction of the length."""
    a = max(1, int(n * attack))
    d = max(1, n - a)
    return np.concatenate(
        [
            np.linspace(0, 1, a) ** 0.6,
            (np.linspace(1, 0, d) ** curve),
        ]
    )[:n]


def env_pad(n: int, fade: float = 0.25) -> np.ndarray:
    """Slow in, slow out — for sustained pad tones."""
    f = max(1, int(n * fade))
    e = np.ones(n)
    e[:f] = np.linspace(0, 1, f) ** 2
    e[-f:] = np.linspace(1, 0, f) ** 2
    return e


# --------------------------------------------------------------------- voices
def tone(
    freq: float,
    dur: float,
    *,
    partials: tuple[float, ...] = (1.0,),
    detune: float = 0.0,
    attack: float = 0.01,
    curve: float = 2.5,
) -> np.ndarray:
    """A sine stack. `partials` are amplitudes for harmonics 1, 2, 3…"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, amp in enumerate(partials, start=1):
        if amp == 0:
            continue
        out += amp * np.sin(2 * np.pi * freq * i * t)
        if detune:
            out += amp * 0.5 * np.sin(2 * np.pi * freq * i * (1 + detune) * t)
    return out * env_ad(n, attack, 1 - attack, curve)


def bell(freq: float, dur: float, *, bright: float = 1.0) -> np.ndarray:
    """Inharmonic partials: what separates a bell from a flute."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # Ratios roughly following a struck metal bar. The high ones decay fastest,
    # which is what makes the strike read as a strike.
    for ratio, amp, decay in (
        (1.0, 1.0, 2.0),
        (2.01, 0.55 * bright, 3.2),
        (3.02, 0.32 * bright, 4.5),
        (4.97, 0.18 * bright, 6.0),
        (7.10, 0.10 * bright, 8.0),
    ):
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-decay * t)
    click = np.zeros(n)
    strike = min(n, int(SR * 0.004))
    click[:strike] = np.linspace(1, 0, strike) * 0.35
    return out * env_ad(n, 0.002, 0.998, 1.2) + click


def noise(
    dur: float,
    *,
    lowpass: float | None = None,
    highpass: float | None = None,
    attack: float = 0.01,
    curve: float = 3.0,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """Filtered noise, for thuds, creaks and impact transients."""
    n = int(SR * dur)
    rng = rng or np.random.default_rng(7)
    sig = rng.uniform(-1, 1, n)

    spectrum = np.fft.rfft(sig)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    if lowpass:
        spectrum *= 1 / (1 + (freqs / lowpass) ** 4)
    if highpass:
        spectrum *= (freqs / highpass) ** 2 / (1 + (freqs / highpass) ** 2)
    sig = np.fft.irfft(spectrum, n)

    return sig * env_ad(n, attack, 1 - attack, curve)


def sweep(f0: float, f1: float, dur: float, *, curve: float = 2.0) -> np.ndarray:
    """A glide from f0 to f1."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = f0 + (f1 - f0) * (t / max(t[-1], 1e-9))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * env_ad(n, 0.02, 0.98, curve)


def pluck(freq: float, dur: float, *, decay: float = 0.996, seed: int = 0) -> np.ndarray:
    """Karplus-Strong: noise round a delay line, low-passed on every pass.

    A plucked string in about ten lines, and it sounds far more like an
    instrument than any stack of sines does.
    """
    n = int(SR * dur)
    size = max(2, int(SR / freq))
    rng = np.random.default_rng(seed)
    buf = rng.uniform(-1, 1, size)
    out = np.empty(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % size
        buf[idx] = decay * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    return out * env_ad(n, 0.001, 0.999, 1.4)


# ------------------------------------------------------------------ utilities
def mix(*parts: np.ndarray) -> np.ndarray:
    """Sum signals of differing lengths, padding to the longest."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(signal: np.ndarray, start: float, length: float | None = None) -> np.ndarray:
    """Place a signal at `start` seconds inside a buffer."""
    offset = int(SR * start)
    n = offset + len(signal) if length is None else int(SR * length)
    out = np.zeros(max(n, offset + len(signal)))
    out[offset : offset + len(signal)] += signal
    return out


def normalise(sig: np.ndarray, peak: float = 0.9) -> np.ndarray:
    """Scale to a target peak and taper both ends so nothing clicks."""
    high = np.max(np.abs(sig))
    if high > 0:
        sig = sig / high * peak
    edge = min(len(sig) // 8, int(SR * 0.004))
    if edge > 1:
        sig[:edge] *= np.linspace(0, 1, edge)
        sig[-edge:] *= np.linspace(1, 0, edge)
    return sig


def note(semitones: float, base: float = 440.0) -> float:
    """Frequency a number of semitones from A4."""
    return base * 2 ** (semitones / 12)


def write(name: str, sig: np.ndarray, *, bitrate: str = "128k") -> None:
    """Write a mono MP3 via a temporary WAV."""
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(sig, -1, 1)
    pcm = (pcm * 32767).astype("<i2")

    tmp = OUT / f".{name}.wav"
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())

    dest = OUT / f"{name}.mp3"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp),
         "-codec:a", "libmp3lame", "-b:a", bitrate, str(dest)],
        check=True,
    )
    tmp.unlink()
    print(f"  {name + '.mp3':24s} {len(sig) / SR:5.2f}s  "
          f"{dest.stat().st_size / 1024:6.1f} KB")


# ---------------------------------------------------------------------- SFX
# Peaks are set per sound rather than normalising everything to the same level:
# a combo has to feel bigger than a single clear, and a button tap has to stay
# out of the way of both.
def sfx_block_pickup() -> np.ndarray:
    return normalise(
        mix(sweep(520, 760, 0.07, curve=3.0) * 0.8,
            noise(0.03, highpass=3000, curve=5.0) * 0.15),
        0.42,
    )


def sfx_block_placed() -> np.ndarray:
    # A low body for weight, a mid click for the contact, a bright tick on top
    # so it still cuts through on a phone speaker.
    return normalise(
        mix(
            tone(150, 0.16, partials=(1.0, 0.3), curve=4.0),
            noise(0.05, lowpass=2400, highpass=180, curve=5.0) * 0.5,
            at(tone(880, 0.07, partials=(1.0, 0.25), curve=3.0) * 0.35, 0.005),
        ),
        0.72,
    )


def sfx_block_invalid() -> np.ndarray:
    n = int(SR * 0.14)
    t = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * np.pi * 116 * t)) * 0.5
    buzz += np.sign(np.sin(2 * np.pi * 123 * t)) * 0.35  # detuned, so it grates
    return normalise(buzz * env_ad(n, 0.01, 0.99, 2.2), 0.5)


def sfx_line_cleared() -> np.ndarray:
    # Rising major triad: C6 E6 G6.
    parts = [
        at(bell(note(s), 0.30) * 0.8, i * 0.055)
        for i, s in enumerate((15, 19, 22))
    ]
    return normalise(mix(*parts), 0.78)


def sfx_combo() -> np.ndarray:
    # The same idea but five notes, further, faster, with a shimmer tail — the
    # point is that it reads as bigger without simply being louder.
    parts = [
        at(bell(note(s), 0.42, bright=1.25) * 0.85, i * 0.05)
        for i, s in enumerate((15, 19, 22, 27, 31))
    ]
    parts.append(at(noise(0.5, highpass=6000, attack=0.3, curve=2.0) * 0.16, 0.10))
    return normalise(mix(*parts), 0.92)


def sfx_coin() -> np.ndarray:
    # Two quick bright notes, the second higher: the shape everyone reads as
    # "you picked something up".
    return normalise(
        mix(
            tone(1050, 0.07, partials=(1.0, 0.5, 0.2), curve=3.0),
            at(tone(1480, 0.20, partials=(1.0, 0.45, 0.18), curve=3.5), 0.055),
        ),
        0.62,
    )


def sfx_crown() -> np.ndarray:
    # Regal rather than jingly: a fifth and an octave struck together, with a
    # long shimmer.
    return normalise(
        mix(
            bell(note(3), 0.75) * 0.9,      # C5
            bell(note(10), 0.75) * 0.6,     # G5
            at(bell(note(15), 0.85) * 0.5, 0.06),
            at(noise(0.7, highpass=7000, attack=0.25, curve=2.0) * 0.12, 0.05),
        ),
        0.82,
    )


def sfx_level_up() -> np.ndarray:
    parts = [
        at(tone(note(s), 0.32, partials=(1.0, 0.4, 0.15), attack=0.02) * 0.7, i * 0.085)
        for i, s in enumerate((3, 7, 10, 15))
    ]
    parts.append(at(bell(note(15), 0.6) * 0.55, 0.255))
    return normalise(mix(*parts), 0.85)


def sfx_kingdom_upgrade() -> np.ndarray:
    # A block of stone set down, then the chime of the repair landing.
    return normalise(
        mix(
            tone(90, 0.22, partials=(1.0, 0.35, 0.12), curve=4.0) * 0.9,
            noise(0.14, lowpass=1400, curve=4.0) * 0.45,
            at(bell(note(10), 0.55) * 0.55, 0.13),
            at(bell(note(15), 0.65) * 0.45, 0.22),
        ),
        0.88,
    )


def sfx_chest() -> np.ndarray:
    # Lid creak, then a cascade of little bells falling out of it.
    rng = np.random.default_rng(11)
    parts = [
        sweep(210, 430, 0.28, curve=1.4) * 0.30,
        noise(0.3, lowpass=1800, highpass=300, attack=0.4, curve=2.0, rng=rng) * 0.22,
    ]
    for i, s in enumerate((22, 27, 31, 34, 39)):
        parts.append(at(bell(note(s), 0.45, bright=1.2) * (0.55 - i * 0.06),
                        0.24 + i * 0.045))
    return normalise(mix(*parts), 0.85)


def sfx_game_over() -> np.ndarray:
    # Descending minor triad, soft and unhurried. A run ending is not a failure
    # buzzer — the player is about to be offered a continue.
    parts = [
        at(tone(note(s), 0.5, partials=(1.0, 0.35, 0.12), attack=0.03) * 0.75, i * 0.14)
        for i, s in enumerate((12, 8, 5, 0))
    ]
    return normalise(mix(*parts), 0.62)


def sfx_button_tap() -> np.ndarray:
    return normalise(
        mix(tone(660, 0.045, partials=(1.0, 0.3), curve=3.5),
            noise(0.02, highpass=2500, curve=5.0) * 0.25),
        0.34,
    )


SFX = {
    "block_pickup": sfx_block_pickup,
    "block_placed": sfx_block_placed,
    "block_invalid": sfx_block_invalid,
    "line_cleared": sfx_line_cleared,
    "combo": sfx_combo,
    "coin": sfx_coin,
    "crown": sfx_crown,
    "level_up": sfx_level_up,
    "kingdom_upgrade": sfx_kingdom_upgrade,
    "chest": sfx_chest,
    "game_over": sfx_game_over,
    "button_tap": sfx_button_tap,
}


# --------------------------------------------------------------------- music
# A calm eight-bar loop in A minor: plucked arpeggios over a soft pad, with a
# sparse bell line. It plays under everything at 35% volume, so it is
# deliberately uneventful — background music you notice only when it stops.
BPM = 84
BEAT = 60 / BPM
BAR = BEAT * 4

# Am – F – C – G, twice. Semitones from A4; negatives are below it.
PROGRESSION = [
    (-12, (-12, -5, 0)),    # Am : A3  A3 E4 A4
    (-16, (-16, -9, -4)),   # F  : F3  F3 C4 F4
    (-21, (-21, -14, -9)),  # C  : C3  C3 G3 C4
    (-14, (-14, -7, -2)),   # G  : G3  G3 D4 G4
] * 2

MELODY = [  # (bar, beat, semitone) — sparse, high, never on the downbeat
    (0, 2.5, 0), (1, 1.5, -4), (2, 3.0, 3), (3, 2.0, -2),
    (4, 2.5, 7), (5, 1.5, 3), (6, 3.0, 0), (7, 2.0, -5),
]


def music_loop() -> np.ndarray:
    total = BAR * len(PROGRESSION)
    tail = 2.5                      # notes that ring past the end of the loop
    buf = np.zeros(int(SR * (total + tail)))

    def place(sig: np.ndarray, start: float) -> None:
        i = int(SR * start)
        end = min(len(buf), i + len(sig))
        buf[i:end] += sig[: end - i]

    for bar, (root, chord) in enumerate(PROGRESSION):
        t0 = bar * BAR

        # Pad: the chord held under everything, quiet and dull-toned.
        for s in chord:
            n = int(SR * (BAR + 0.35))
            t = np.arange(n) / SR
            f = note(s)
            pad = (
                np.sin(2 * np.pi * f * t)
                + 0.5 * np.sin(2 * np.pi * f * 1.005 * t)
                + 0.25 * np.sin(2 * np.pi * f * 2 * t)
            )
            place(pad * env_pad(n, 0.3) * 0.055, t0)

        # Bass on the downbeat and the third beat.
        for beat in (0.0, 2.0):
            place(pluck(note(root), 1.3, decay=0.9975, seed=bar * 7 + int(beat))
                  * 0.30, t0 + beat * BEAT)

        # Arpeggio: eighth notes climbing and falling through the chord.
        shape = [0, 1, 2, 1, 2, 1, 0, 1]
        for step, which in enumerate(shape):
            s = chord[which] + (12 if step in (4, 5) else 0)
            place(
                pluck(note(s), 0.85, decay=0.9962, seed=bar * 31 + step) * 0.17,
                t0 + step * BEAT / 2,
            )

    for bar, beat, s in MELODY:
        place(bell(note(s + 12), 1.1, bright=0.55) * 0.16, bar * BAR + beat * BEAT)

    # Fold the tail back over the opening so the loop joins without a seam.
    n = int(SR * total)
    loop = buf[:n].copy()
    overhang = buf[n:]
    loop[: len(overhang)] += overhang

    return normalise(loop, 0.72)


def main() -> None:
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is not on PATH — needed to encode the MP3s.")

    print("effects")
    for name, make in SFX.items():
        write(name, make(), bitrate="96k")

    print("music")
    write("theme_loop", music_loop(), bitrate="128k")

    total = sum(p.stat().st_size for p in OUT.glob("*.mp3"))
    print(f"\nTotal in assets/audio: {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
