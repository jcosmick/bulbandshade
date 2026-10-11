"""Sintetizza gli effetti sonori del gioco come WAV mono 16 bit.

Uso: python make_sfx.py <cartella> [nome ...]
Senza nomi rigenera tutti gli effetti (la musica solo se richiesta: "music").
Con "varianti" scrive in sounds/varianti le alternative di flash e vittoria.

Palette sonora: la protagonista è una lampadina, quindi vetro (campanelli FM
inarmonici, "tink"), filamento elettrico (ronzii, scatti di interruttore) e
metallo dell'attacco (tonfi corti). Le note stanno in Fa maggiore come la musica.
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(sys.argv[1])
rng = np.random.default_rng(7)

# Fa maggiore (come la musica).
F5, A5, C6, F6, A6, C7, F7 = 698.46, 880.0, 1046.5, 1396.9, 1760.0, 2093.0, 2793.8


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


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


def pad(x, dur):
    out = np.zeros(int(RATE * dur))
    out[: len(x)] += x[: len(out)]
    return out


def place(out, x, at, gain=1.0):
    """Somma x dentro out a partire dal secondo at."""
    i = int(RATE * at)
    if i >= len(out):
        return
    m = min(len(x), len(out) - i)
    out[i:i + m] += x[:m] * gain


def noise(dur):
    return rng.standard_normal(int(RATE * dur))


def _comb(x, delay, g):
    y = x.copy()
    for s in range(delay, len(y), delay):
        e = min(s + delay, len(y))
        y[s:e] += g * y[s - delay:e - delay]
    return y


def _allpass(x, delay, g):
    y = -g * x
    y[delay:] += x[:-delay]
    for s in range(delay, len(y), delay):
        e = min(s + delay, len(y))
        y[s:e] += g * y[s - delay:e - delay]
    return y


def reverb(x, wet=0.2, size=1.0, tone=5000):
    """Riverbero Schroeder: la stanza buia e vuota del vecchio edificio."""
    combs = ((1557, 0.84), (1617, 0.83), (1491, 0.82), (1422, 0.81))
    w = sum(_comb(x, int(d * size), g) for d, g in combs) / len(combs)
    for d, g in ((225, 0.7), (556, 0.7)):
        w = _allpass(w, d, g)
    return x + lowpass(w, tone) * wet


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


def glass(freq, dur, decay, index=2.5, ratio=3.5):
    """Campanello di vetro (FM): attacco brillante che si addolcisce in un tono puro."""
    t = t_of(dur)
    mod_env = np.exp(-t / (decay * 0.25))
    x = np.sin(2 * np.pi * freq * t + index * mod_env * np.sin(2 * np.pi * freq * ratio * t))
    # Parziale inarmonico tipico del vetro, che muore subito.
    x += 0.2 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (decay * 0.3))
    return x * env(len(t), 0.0015, decay)


def click(dur=0.02, decay=0.003, cutoff=2500):
    """Scatto secco (interruttore, attacco metallico)."""
    return highpass(noise(dur), cutoff) * env(int(RATE * dur), 0.0002, decay)


def thump(f0, f1, dur, decay):
    """Tonfo grave che scende di intonazione: dà peso al suono."""
    return sweep(f0, f1, dur) * env(int(RATE * dur), 0.002, decay)


def sparkles(out, count, start, end, gain, lo=3200, hi=5200):
    """Luccichii: tante micro-note di vetro sparse nel tempo, sempre più deboli."""
    for _ in range(count):
        at = rng.uniform(start, end)
        fade = 1 - (at - start) / (end - start) * 0.7
        place(out, glass(rng.uniform(lo, hi), 0.12, 0.03, index=1.0), at, gain * fade)


def jump():
    # "Pwip!" elastico: tono che schizza verso l'alto, soffio d'aria e un "tink" del vetro.
    dur = 0.24
    out = np.zeros(int(RATE * dur))
    body = sweep(260, 900, 0.1) * env(int(RATE * 0.1), 0.003, 0.045)
    body += 0.3 * sweep(520, 1800, 0.1) * env(int(RATE * 0.1), 0.003, 0.025)
    place(out, body, 0.0)
    place(out, bandpass(noise(0.06), 900, 4500) * env(int(RATE * 0.06), 0.002, 0.018), 0.0, 0.35)
    place(out, glass(C7, 0.15, 0.04, index=1.5), 0.012, 0.18)
    save("jump.wav", reverb(lowpass(out, 7000), 0.06, 0.6), peak=0.6)


def land():
    # Atterraggio: tonfo morbido dell'attacco metallico + leggero "clink" del vetro.
    dur = 0.2
    out = np.zeros(int(RATE * dur))
    place(out, thump(170, 60, 0.12, 0.035), 0.0)
    place(out, click(0.02, 0.004, 1800), 0.0, 0.45)
    place(out, lowpass(noise(0.05), 1200) * env(int(RATE * 0.05), 0.001, 0.012), 0.0, 0.5)
    place(out, glass(A6, 0.12, 0.035, index=1.2), 0.004, 0.08)
    save("land.wav", lowpass(out, 6000), peak=0.6)


def flash_ready():
    # Flash di nuovo carico: due "ping" di vetro che salgono, discreti ma riconoscibili.
    dur = 0.5
    out = np.zeros(int(RATE * dur))
    place(out, glass(C7, 0.4, 0.09, index=1.8), 0.0, 0.6)
    place(out, glass(F7, 0.4, 0.14, index=1.8), 0.065, 0.75)
    save("flash_ready.wav", reverb(out, 0.18, 0.7), peak=0.55)


def flash_dud():
    # Flash non ancora pronto: il filamento fa "tsk-tsk" e ronza a vuoto.
    dur = 0.24
    out = np.zeros(int(RATE * dur))
    for at in (0.0, 0.07):
        place(out, lowpass(click(0.02, 0.005, 400), 3000), at, 0.8)
    t = t_of(0.16)
    buzz = np.tanh(4 * np.sin(2 * np.pi * 110 * t)) * env(len(t), 0.004, 0.045)
    place(out, lowpass(buzz, 1400), 0.0, 0.35)
    save("flash_dud.wav", out, peak=0.5)


def drip():
    # Goccia: "bloop" rotondo che sale, un "plop" più piccolo, eco nei tubi.
    dur = 0.4
    n = int(RATE * dur)
    t = t_of(dur)
    f = np.where(t < 0.06, 300 * (900 / 300) ** (t / 0.06), 900)
    bloop = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.003, 0.04)
    out = bloop.copy()
    place(out, sweep(500, 1100, 0.035) * env(int(RATE * 0.035), 0.002, 0.012), 0.085, 0.3)
    save("drip.wav", reverb(lowpass(out, 3000), 0.22, 0.8, 3000), peak=0.55)


def death():
    # Cortocircuito: ZZZT saturo che sfarfalla come la luce, crepitii, il filamento che
    # si spezza con un "tink" e un ronzio che si spegne scendendo.
    dur = 1.2
    n = int(RATE * dur)
    t = t_of(dur)
    # Stessa frequenza dello sfarfallio visivo (|sin(40 t)|).
    flicker = 0.35 + 0.65 * np.abs(np.sin(40 * t))
    zzzt = np.tanh(5 * np.sin(2 * np.pi * 100 * t) + 1.5 * rng.standard_normal(n) * 0.3)
    zzzt = lowpass(zzzt, 4000) * np.exp(-t / 0.22) * np.clip(t / 0.003, 0, 1)
    power_down = np.tanh(2.5 * sweep(700, 60, dur)) * np.exp(-t / 0.4) * np.clip(t / 0.01, 0, 1)
    out = (zzzt * 0.55 + lowpass(power_down, 2500) * 0.6) * flicker
    raw = rng.standard_normal(n)
    crackle = np.zeros(n)
    for start in rng.uniform(0, 0.55, 18):
        i = int(start * RATE)
        length = int(rng.uniform(0.006, 0.022) * RATE)
        seg = raw[i:i + length] * np.exp(-np.arange(min(length, n - i)) / (RATE * 0.005))
        crackle[i:i + len(seg)] += seg * rng.uniform(0.4, 1.0) * np.exp(-start / 0.3)
    out += highpass(crackle, 1500) * 0.6
    place(out, thump(220, 90, 0.08, 0.02), 0.0, 0.5)
    for freq, gain in ((2400, 0.35), (3650, 0.25), (5100, 0.15)):
        place(out, glass(freq, 0.3, 0.05, index=1.0), 0.05, gain)
    save("death.wav", reverb(out, 0.2, 0.9), peak=0.8)


def tap():
    # Tap dell'interfaccia: "tok-tink" di vetro, corto e morbido.
    dur = 0.14
    out = np.zeros(int(RATE * dur))
    place(out, thump(700, 380, 0.05, 0.012), 0.0, 0.6)
    place(out, glass(1568, 0.12, 0.03, index=1.6), 0.0, 0.5)
    place(out, click(0.01, 0.0012, 3000), 0.0, 0.2)
    save("tap.wav", lowpass(out, 8000), peak=0.6)


def button():
    # Pulsante a pavimento: "ka-chunk" meccanico e un bip di conferma che sale.
    dur = 0.5
    out = np.zeros(int(RATE * dur))
    place(out, click(0.02, 0.003, 2000), 0.0, 0.5)
    place(out, thump(150, 65, 0.12, 0.04), 0.0, 0.9)
    place(out, click(0.02, 0.004, 1200), 0.045, 0.4)
    for i, freq in enumerate((A5, C6)):
        t = t_of(0.12)
        blip = np.tanh(2 * np.sin(2 * np.pi * freq * t)) * env(len(t), 0.003, 0.05)
        place(out, lowpass(blip, 4000), 0.09 + i * 0.07, 0.3)
    save("button.wav", reverb(out, 0.15, 0.8), peak=0.65)


def checkpoint():
    # Checkpoint che si accende: scatto, ronzio del filamento che si scalda, "ding-dong" in su.
    dur = 1.5
    out = np.zeros(int(RATE * dur))
    place(out, click(0.02, 0.003, 2500), 0.0, 0.5)
    t = t_of(0.35)
    hum = np.tanh(3 * np.sin(2 * np.pi * 120 * t)) * np.clip(t / 0.06, 0, 1) * np.exp(-t / 0.1)
    place(out, lowpass(hum, 1500), 0.0, 0.25)
    place(out, glass(C6, 0.8, 0.25), 0.04, 0.55)
    place(out, glass(F6, 0.9, 0.4), 0.15, 0.6)
    sparkles(out, 5, 0.18, 0.5, 0.07)
    save("checkpoint.wav", reverb(out, 0.25, 1.0), peak=0.65)


def collect():
    # Mini lampadina raccolta: glissando che gira su se stesso fino al "pop" in cima
    # (dura quanto il saltello con giravolta, poi parte il mini flash).
    dur = 0.5
    out = np.zeros(int(RATE * dur))
    t = t_of(0.35)
    spin = sweep(450, 1900, 0.35) * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t))
    spin *= np.clip(t / 0.02, 0, 1) * np.clip((0.35 - t) / 0.03, 0, 1) * (0.4 + 0.6 * t / 0.35)
    place(out, spin, 0.0, 0.35)
    place(out, thump(500, 1400, 0.04, 0.012), 0.34, 0.5)
    place(out, click(0.01, 0.0015, 3000), 0.34, 0.3)
    save("collect.wav", reverb(lowpass(out, 7000), 0.15, 0.7), peak=0.55)


def mini_flash():
    # Mini flash delle lampadine colorate: versione piccola e cristallina del flash.
    dur = 0.8
    out = np.zeros(int(RATE * dur))
    place(out, click(0.015, 0.002, 3500), 0.0, 0.4)
    place(out, thump(300, 140, 0.15, 0.04), 0.0, 0.35)
    place(out, glass(C7, 0.6, 0.15), 0.01, 0.5)
    place(out, glass(F7, 0.7, 0.28), 0.04, 0.55)
    sparkles(out, 6, 0.05, 0.45, 0.1, 4000, 6500)
    save("mini_flash.wav", reverb(lowpass(out, 10000), 0.22, 0.8), peak=0.6)


# --- Flash e vittoria: strumenti "musicali" (armonici, intonati in Fa) -------------
# Qui niente parziali inarmonici né note a caso: tutto sta in tonalità con la musica.


def midi(m):
    return 440 * 2 ** ((m - 69) / 12)


def svf_lowpass(x, cutoff, q=0.707):
    """Passa-basso risonante (SVF TPT) con frequenza di taglio variabile nel tempo."""
    cutoff = np.broadcast_to(np.minimum(cutoff, RATE * 0.45), x.shape)
    g = np.tan(np.pi * cutoff / RATE)
    k = 1 / q
    a1 = 1 / (1 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    y = np.empty_like(x)
    ic1 = ic2 = 0.0
    for i in range(len(x)):
        v3 = x[i] - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        y[i] = v2
    return y


def saw(freq, dur, detune=0.0):
    """Dente di sega senza aliasing (somma di armoniche), con un leggero chorus."""
    t = t_of(dur)
    out = np.zeros(len(t))
    for f in (freq * (1 - detune), freq * (1 + detune)) if detune else (freq,):
        phase = rng.uniform(0, 2 * np.pi)
        for k in range(1, int(16000 / f) + 1):
            out += np.sin(2 * np.pi * k * f * t + k * phase) / k
    return out


def kalimba(freq, dur, decay=0.45):
    """Lo stesso strumento della musica: tono rotondo + "tink" metallico armonico."""
    t = t_of(dur)
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)
    x += 0.35 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.03)
    x += 0.15 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / (decay * 0.45))
    return x * np.clip(t / 0.002, 0, 1)


def music_box(freq, dur, decay=0.7):
    """Carillon: armoniche pure, la terza armonica dà la "punta" di metallo."""
    t = t_of(dur)
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)
    x += 0.4 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / (decay * 0.4))
    x += 0.25 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t / (decay * 0.15))
    return x * np.clip(t / 0.001, 0, 1)


def pluck_bass(freq, dur, decay=0.4):
    t = t_of(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / 0.08)
    return x * np.clip(t / 0.004, 0, 1) * np.exp(-t / decay)


def warm_pad(notes, dur, attack, release):
    t = t_of(dur)
    x = sum(np.sin(2 * np.pi * midi(m) * t) + np.sin(2 * np.pi * midi(m) * 1.004 * t) for m in notes)
    return x * np.clip(t / attack, 0, 1) * np.exp(-t / release)


def brass(freq, dur, hold):
    """Ottone sintetico: dente di sega che "si apre" col filtro, vibrato sulle note lunghe."""
    t = t_of(dur)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vib) / RATE
    x = sum(np.sin(k * phase) / k for k in range(1, int(14000 / freq) + 1))
    x += sum(np.sin(k * phase * 1.003) / k for k in range(1, int(14000 / freq) + 1))
    amp = np.clip(t / 0.02, 0, 1) * np.where(t < hold, 1.0, np.exp(-(t - hold) / 0.12))
    cutoff = 600 + 3800 * np.clip(t / 0.04, 0, 1) * (0.55 + 0.45 * np.exp(-t / 0.15)) * amp
    return svf_lowpass(x * amp, cutoff, 0.9)


def room(x, decay=0.9, wet=0.22, predelay=0.012, tone=5500):
    """Riverbero a convoluzione con coda di rumore: morbido, senza risonanze metalliche."""
    ir_rng = np.random.default_rng(42)
    t = t_of(decay)
    ir = ir_rng.standard_normal(len(t)) * np.exp(-6.9 * t / decay)
    ir = lowpass(ir, tone) * np.clip(t / 0.01, 0, 1)
    ir /= np.sqrt(np.sum(ir ** 2))
    ir = np.concatenate([np.zeros(int(RATE * predelay)), ir])
    size = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    w = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return x + w * wet * 0.35


def whoosh(dur, f0, f1, decay, q=1.5):
    """Soffio di rumore con filtro che si sposta (effetto "fwoom")."""
    n = int(RATE * dur)
    t = t_of(dur)
    cutoff = f0 * (f1 / f0) ** np.clip(t / 0.12, 0, 1)
    return svf_lowpass(rng.standard_normal(n), cutoff, q) * env(n, 0.008, decay)


def flash_kalimba():
    # A: "strum" di kalimba Fa-La-Do-Fa-La, lo strumento della colonna sonora, con un
    # colpetto grave che dà peso e un soffio d'aria che si apre.
    dur = 1.9
    out = np.zeros(int(RATE * dur))
    place(out, thump(190, 55, 0.2, 0.055), 0.0, 0.8)
    place(out, whoosh(0.4, 700, 7000, 0.09), 0.0, 0.18)
    for i, m in enumerate((77, 81, 84, 89, 93)):
        place(out, kalimba(midi(m), 1.8, 0.3 if i < 4 else 0.55), i * 0.028, 0.32 + i * 0.06)
    return room(out, 1.0, 0.25)


def flash_stab():
    # B: accordo di synth "chunky" che si apre e si chiude di colpo + cassa grave.
    dur = 1.1
    out = np.zeros(int(RATE * dur))
    place(out, thump(160, 42, 0.35, 0.1), 0.0, 1.0)
    place(out, click(0.01, 0.0015, 3000), 0.0, 0.25)
    t = t_of(0.8)
    chord = sum(saw(midi(m), 0.8, 0.004) for m in (65, 69, 72, 77, 81))
    cutoff = 350 + 6500 * np.clip(t / 0.006, 0, 1) * np.exp(-t / 0.09)
    stab = svf_lowpass(chord, cutoff, 1.6) * env(len(t), 0.002, 0.22)
    place(out, stab, 0.0, 0.16)
    place(out, highpass(noise(0.15), 4000) * env(int(RATE * 0.15), 0.001, 0.03), 0.0, 0.08)
    return room(lowpass(out, 9000), 0.9, 0.22)


def flash_burst():
    # C: "shwoom" luminoso e corto: rumore con filtro risonante che scende rapido e un
    # bagliore di toni puri Fa-La-Do che tremola e si spegne in fretta.
    dur = 0.75
    out = np.zeros(int(RATE * dur))
    place(out, thump(220, 70, 0.12, 0.035), 0.0, 0.6)
    n = int(RATE * 0.3)
    t = t_of(0.3)
    sweep_noise = svf_lowpass(rng.standard_normal(n), 6000 * (900 / 6000) ** (t / 0.3), 4.0)
    place(out, sweep_noise * env(n, 0.002, 0.07), 0.0, 0.16)
    t = t_of(0.7)
    shimmer = 1 + 0.3 * np.sin(2 * np.pi * 12 * t)
    for i, m in enumerate((89, 93, 96)):
        tone = np.sin(2 * np.pi * midi(m) * t) + 0.2 * np.sin(4 * np.pi * midi(m) * t)
        place(out, tone * shimmer * env(len(t), 0.003, 0.13), i * 0.012, 0.25)
    return room(out, 0.6, 0.22)


def victory_kalimba():
    # A: mini-finale nello stile della musica: arpeggio Do-Fa-La-Do sopra il basso in Do
    # che si risolve sull'accordo di Fa, con pad caldo e tre note che luccicano.
    dur = 3.0
    out = np.zeros(int(RATE * dur))
    place(out, pluck_bass(midi(48), 0.6, 0.25), 0.0, 0.5)
    for i, m in enumerate((72, 77, 81, 84)):
        place(out, kalimba(midi(m), 0.8, 0.3), i * 0.1, 0.45)
    land_at = 0.5
    place(out, kalimba(midi(88), 0.3, 0.12), land_at - 0.06, 0.3)
    place(out, pluck_bass(midi(41), 2.0, 0.8), land_at, 0.7)
    for i, m in enumerate((69, 72, 77, 81, 89)):
        place(out, kalimba(midi(m), 2.4, 0.9), land_at + i * 0.018, 0.3 if m < 89 else 0.5)
    place(out, warm_pad((65, 69, 72, 77), 2.4, 0.25, 0.9), land_at, 0.06)
    for i, m in enumerate((93, 96, 101)):
        place(out, kalimba(midi(m), 1.2, 0.4), 1.0 + i * 0.12, 0.18)
    return room(out, 1.4, 0.3)


def victory_fanfare():
    # B: fanfara d'ottoni "ta-ta-ta-TAAA" Fa-La-Do-Fa con colpo di timpano sul finale.
    dur = 2.6
    out = np.zeros(int(RATE * dur))
    for i, m in enumerate((77, 81, 84)):
        place(out, brass(midi(m), 0.3, 0.08), i * 0.12, 0.3)
    land_at = 0.38
    place(out, brass(midi(89), 2.0, 1.1), land_at, 0.32)
    for m in (65, 69, 72):
        place(out, brass(midi(m), 2.0, 1.1), land_at, 0.17)
    place(out, thump(110, 48, 0.8, 0.25), land_at, 0.9)
    place(out, pluck_bass(midi(41), 2.0, 0.6), land_at, 0.5)
    return room(out, 1.4, 0.3)


def victory_carillon():
    # C: carillon dolce che si risolve su Fa, con armonie di pad: tenero e "notturno".
    dur = 3.2
    out = np.zeros(int(RATE * dur))
    tune = ((0.0, 84), (0.14, 89), (0.28, 93), (0.42, 91), (0.6, 89))
    for at, m in tune:
        place(out, music_box(midi(m), 1.6, 0.7 if at < 0.6 else 1.2), at, 0.4)
    for m in (77, 81):
        place(out, music_box(midi(m), 2.0, 1.0), 0.6, 0.22)
    place(out, pluck_bass(midi(41), 2.0, 0.9), 0.6, 0.45)
    place(out, warm_pad((65, 69, 72, 77), 2.6, 0.4, 1.0), 0.6, 0.06)
    place(out, music_box(midi(101), 1.2, 0.8), 1.1, 0.12)
    return room(out, 1.6, 0.35)


VARIANTS = {
    "flash": {"a_kalimba": flash_kalimba, "b_synth": flash_stab, "c_bagliore": flash_burst},
    "victory": {"a_kalimba": victory_kalimba, "b_fanfara": victory_fanfare,
                "c_carillon": victory_carillon},
}
## Variante usata in gioco (le altre si ascoltano in sounds/varianti con "varianti").
FLASH_VARIANT = "c_bagliore"
VICTORY_VARIANT = "c_carillon"


def flash():
    save("flash.wav", VARIANTS["flash"][FLASH_VARIANT](), peak=0.75)


def victory():
    save("victory.wav", VARIANTS["victory"][VICTORY_VARIANT](), peak=0.75)


def varianti():
    """Tutte le varianti di flash e vittoria in sounds/varianti, da ascoltare e scegliere."""
    folder = OUT / "varianti"
    folder.mkdir(exist_ok=True)
    (folder / ".gdignore").touch()
    for sound, variants in VARIANTS.items():
        for name, make in variants.items():
            save(f"varianti/{sound}_{name}.wav", make(), peak=0.75)


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




def lowpass_rate(x, cutoff, rate):
    alpha = 1 - np.exp(-2 * np.pi * cutoff / rate)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


SFX = (jump, land, flash, flash_ready, flash_dud, drip, death, tap, button,
       checkpoint, collect, mini_flash, victory)
ALL = {f.__name__: f for f in SFX + (music, varianti)}

OUT.mkdir(parents=True, exist_ok=True)
for name in sys.argv[2:] or [f.__name__ for f in SFX]:
    ALL[name]()
