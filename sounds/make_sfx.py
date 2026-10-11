"""Sintetizza gli effetti sonori del gioco come WAV mono 16 bit."""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(sys.argv[1])
rng = np.random.default_rng(7)


def t_of(dur):
    return np.arange(int(RATE * dur)) / RATE


def sweep(f0, f1, dur, curve="exp"):
    """Sinusoide con frequenza che va da f0 a f1 (fase integrata)."""
    t = t_of(dur)
    if curve == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def env(n, attack, decay):
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def lowpass(x, cutoff):
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def pad(x, dur):
    out = np.zeros(int(RATE * dur))
    out[: len(x)] += x[: len(out)]
    return out


def save(name, x, peak=0.8, rate=RATE, fade_out=True):
    # Piccola dissolvenza finale per evitare click.
    if fade_out:
        fade = min(len(x), int(rate * 0.01))
        x[-fade:] *= np.linspace(1, 0, fade)
    x = x / np.max(np.abs(x)) * peak
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)
    print(name, f"{len(x) / rate:.2f}s")


def note(freq, dur, decay, harmonics=((1, 1.0), (2, 0.25))):
    """Nota "pizzicata" morbida (tipo xilofono/carillon)."""
    t = t_of(dur)
    x = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in harmonics)
    return x * env(len(t), 0.004, decay)


def flash():
    # "Fwip" cartoon che sale + tre note di xilofono (do-mi-sol) in arpeggio.
    dur = 0.5
    n = int(RATE * dur)
    whoosh = pad(sweep(260, 820, 0.09) * env(int(RATE * 0.09), 0.01, 0.06), dur)
    out = whoosh * 0.5
    for i, freq in enumerate((784, 988, 1175)):
        start = int(RATE * (0.05 + i * 0.045))
        tone = note(freq, dur, 0.09 if i < 2 else 0.16)
        out[start:] += tone[: n - start] * (0.55 if i < 2 else 0.7)
    save("flash.wav", lowpass(out, 4000), peak=0.6)


def drip():
    # "Bloop" cartoon: tono rotondo che sale, seguito da un "plop" più piccolo.
    dur = 0.22
    n = int(RATE * dur)
    t = t_of(dur)
    f = np.where(t < 0.07, 280 * (760 / 280) ** (t / 0.07), 760)
    bloop = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.004, 0.05)
    plop = pad(sweep(420, 900, 0.04) * env(int(RATE * 0.04), 0.003, 0.015), dur)
    small = np.zeros(n)
    k = int(RATE * 0.09)
    small[k:] = plop[: n - k]
    save("drip.wav", lowpass(bloop + small * 0.35, 2500), peak=0.55)


def death():
    # Cortocircuito: crepitii elettrici + tono "pew" che scende e si spegne.
    dur = 0.9
    n = int(RATE * dur)
    t = t_of(dur)
    tone = sweep(880, 110, dur)
    buzz = np.sign(np.sin(2 * np.pi * 55 * t)) * 0.5 + 0.5  # tremolo a 55 Hz
    tone *= (0.6 + 0.4 * buzz) * np.exp(-t / 0.35) * np.clip(t / 0.01, 0, 1)
    tone = lowpass(tone, 3000)
    noise = rng.standard_normal(n)
    crackle = np.zeros(n)
    for start in rng.uniform(0, 0.5, 14):
        i = int(start * RATE)
        length = int(rng.uniform(0.008, 0.025) * RATE)
        seg = noise[i:i + length] * np.exp(-np.arange(min(length, n - i)) / (RATE * 0.006))
        crackle[i:i + len(seg)] += seg * rng.uniform(0.4, 1.0) * np.exp(-start / 0.3)
    crackle = crackle - lowpass(crackle, 1500)
    # "Tink" finale del filamento che si rompe.
    tink = np.zeros(n)
    k = int(RATE * 0.05)
    tink[k:] = np.sin(2 * np.pi * 2400 * t[: n - k]) * env(n - k, 0.001, 0.04) * 0.4
    save("death.wav", tone * 0.8 + crackle * 0.5 + tink)


def tap():
    # Tap dell'interfaccia: "pop" morbido e corto.
    dur = 0.08
    n = int(RATE * dur)
    pop = sweep(1300, 650, dur) * env(n, 0.001, 0.018)
    click = rng.standard_normal(n) * env(n, 0.0005, 0.002) * 0.25
    save("tap.wav", lowpass(pop + click, 6000), peak=0.6)


def music():
    """Canzoncina in loop: kalimba su accordi jazz morbidi, swing leggero, Fa maggiore."""
    rate = 22050
    bpm = 88
    beat = 60 / bpm
    bars = 16
    length = int(rate * beat * 4 * bars)
    tail = int(rate * 3)
    out = np.zeros(length + tail)

    def midi(m):
        return 440 * 2 ** ((m - 69) / 12)

    def swing(at):
        # Le crome in levare arrivano un po' in ritardo (swing).
        whole = np.floor(at)
        return whole + 0.62 if abs(at - whole - 0.5) < 1e-6 else at

    def put(x, at_beat, gain):
        i = int(rate * swing(at_beat) * beat)
        out[i:i + len(x)] += x[: len(out) - i] * gain

    def kalimba(m, beats):
        n = int(rate * (beats * beat + 1.2))
        t = np.arange(n) / rate
        f = midi(m)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.45)
        x += 0.35 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.03)  # "tink" metallico
        x += 0.15 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.2)
        return x * np.clip(t / 0.003, 0, 1)

    def pluck_bass(m, beats):
        n = int(rate * (beats * beat + 0.3))
        t = np.arange(n) / rate
        f = midi(m)
        x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.08)
        return x * np.clip(t / 0.005, 0, 1) * np.exp(-t / 0.35)

    def pad(notes, beats):
        n = int(rate * beats * beat)
        t = np.arange(n) / rate
        x = sum(np.sin(2 * np.pi * midi(m) * t) + np.sin(2 * np.pi * midi(m) * 1.004 * t)
                for m in notes)
        attack = np.clip(t / 0.35, 0, 1)
        release = np.clip((t[-1] - t) / 0.3, 0, 1)
        return x * attack * release

    # Accordi: (basso, voci del pad).
    F, Am, Bb, C7, Dm, Gm = ((41, (57, 60, 64)), (45, (55, 60, 64)), (46, (57, 62, 65)),
                             (48, (55, 58, 64)), (50, (57, 60, 65)), (43, (58, 62, 65)))
    chords = [F, Am, Bb, C7, F, Dm, Gm, C7, Bb, Am, Gm, F, Bb, C7, F, C7]
    # Melodia per battuta: (beat, nota MIDI, durata in beat).
    melody = [
        [(0, 81, 1), (1, 84, .5), (1.5, 81, .5), (2, 79, 1), (3, 77, 1)],
        [(0, 76, 1.5), (1.5, 77, .5), (2, 79, 2)],
        [(0, 77, .5), (.5, 79, .5), (1, 81, 1), (2, 86, 1), (3, 84, 1)],
        [(0, 82, 1), (1, 81, .5), (1.5, 79, .5), (2, 76, 2)],
        [(0, 81, 1), (1, 84, .5), (1.5, 86, .5), (2, 88, 1.5), (3.5, 86, .5)],
        [(0, 84, 1), (1, 81, 1), (2, 77, 2)],
        [(0, 82, .5), (.5, 81, .5), (1, 79, .5), (1.5, 77, .5), (2, 74, 1), (3, 79, 1)],
        [(0, 76, 3), (3, 72, 1)],
        [(0, 74, .5), (.5, 77, .5), (1, 81, 1), (2, 82, 1), (3, 81, .5), (3.5, 77, .5)],
        [(0, 79, 1), (1, 76, 1), (2, 72, 2)],
        [(0, 74, .5), (.5, 77, .5), (1, 82, 1), (2, 81, 1), (3, 79, 1)],
        [(0, 77, 1), (1, 81, 1), (2, 84, 2)],
        [(0, 86, 1), (1, 84, .5), (1.5, 82, .5), (2, 81, 1), (3, 77, 1)],
        [(0, 79, 1), (1, 82, 1), (2, 88, 1), (3, 86, .5), (3.5, 84, .5)],
        [(0, 81, 2), (2, 77, 1), (3, 76, 1)],
        [(0, 79, 1), (1, 76, 1), (2, 72, 1), (3, 79, 1)],
    ]
    noise = rng.standard_normal(int(rate * 0.06))
    shaker = (noise - lowpass_rate(noise, 6000, rate)) * np.exp(-np.arange(len(noise)) / (rate * 0.012))
    for bar, ((root, voices), notes) in enumerate(zip(chords, melody)):
        start = bar * 4
        put(pad(voices, 4), start, 0.05)
        for at, m, dur in notes:
            put(kalimba(m, dur), start + at, 0.45)
        # Basso pizzicato: fondamentale, quinta, e una nota di passaggio.
        put(pluck_bass(root, 1.5), start, 0.55)
        put(pluck_bass(root + 7, 1), start + 2, 0.4)
        put(pluck_bass(root + 12, 0.5), start + 3.5, 0.3)
        for k in range(8):
            put(shaker, start + k * 0.5, 0.06 if k % 2 else 0.035)
    # Loop senza stacchi: le code che escono dalla fine rientrano all'inizio.
    out[:tail] += out[length:]
    save("music.wav", lowpass_rate(out[:length], 5000, rate), peak=0.7, rate=rate, fade_out=False)


def victory():
    # "Ta-da!": scivolata verso l'alto, arpeggio do-mi-sol-do e accordo che luccica.
    dur = 1.8
    n = int(RATE * dur)
    t = t_of(dur)
    out = pad(sweep(300, 1000, 0.12) * env(int(RATE * 0.12), 0.02, 0.08), dur) * 0.35
    for i, freq in enumerate((523, 659, 784, 1047)):
        start = int(RATE * (0.08 + i * 0.08))
        out[start:] += note(freq, dur, 0.12)[: n - start] * 0.55
    start = int(RATE * 0.45)
    shimmer = 1 + 0.25 * np.sin(2 * np.pi * 7 * t)  # leggero tremolo
    for freq in (523, 659, 784, 1047, 1319):
        chord = note(freq, dur, 0.45, ((1, 1.0), (2, 0.2), (3, 0.05))) * shimmer
        out[start:] += chord[: n - start] * 0.3
    save("victory.wav", lowpass(out, 5000), peak=0.7)


def lowpass_rate(x, cutoff, rate):
    alpha = 1 - np.exp(-2 * np.pi * cutoff / rate)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


OUT.mkdir(parents=True, exist_ok=True)
flash()
drip()
death()
tap()
victory()
music()
