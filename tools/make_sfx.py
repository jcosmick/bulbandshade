"""Sintetizza gli effetti sonori del gioco come WAV mono 16 bit.

Uso: python tools/make_sfx.py sounds [nome ...]
Senza nomi rigenera tutti gli effetti (la musica solo se richiesta: "music", "music_dark", "music_greenhouse").
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


def step():
    # Andatura della lampadina (niente gambe): saltellino sull'attacco a vite. Le spire
    # strisciano sul pavimento ("zz" di tre micro-scatti), poi il "tik" morbido dell'atterraggio
    # e un micro "tink" del vetro che vibra. Tre varianti che si alternano a caso.
    for i, (f0, tink) in enumerate(((260, C7), (235, A6), (285, F7)), 1):
        dur = 0.1
        out = np.zeros(int(RATE * dur))
        for k in range(3):
            place(out, bandpass(click(0.006, 0.0008, 2000), 2000, 5000), k * 0.005, 0.12 - k * 0.03)
        hit = 0.016
        place(out, lowpass(click(0.012, 0.0015, 1500), 4500), hit, 0.45)
        place(out, thump(f0, f0 * 0.55, 0.04, 0.012), hit, 0.55)
        place(out, glass(tink, 0.06, 0.012, index=0.8), hit + 0.003, 0.06)
        save(f"step_{i}.wav", lowpass(out, 5000), peak=0.5)


def shadow_step():
    # Passo sull'ombra: niente cemento duro, la lampadina affonda in qualcosa di morbido e
    # vellutato. Le spire non strisciano: c'è un "fff" scuro e soffice, un tonfo ovattato più
    # grave e una bollicina che scende (la stessa materia dello sfaldamento dell'ombra).
    for i, (f0, bub) in enumerate(((190, 900), (170, 780), (210, 1020)), 1):
        dur = 0.14
        out = np.zeros(int(RATE * dur))
        n = int(RATE * 0.07)
        place(out, bandpass(noise(0.07), 250, 1400) * env(n, 0.006, 0.018), 0.0, 0.35)
        hit = 0.012
        place(out, thump(f0, f0 * 0.5, 0.06, 0.02), hit, 0.6)
        place(out, pop(bub, 0.5), hit + 0.01, 1.0)
        save(f"shadow_step_{i}.wav", room(lowpass(out, 2200), 0.3, 0.1), peak=0.45)


def push():
    # Cassa che scivola (loop di 2 s): legno che striscia liscio sul cemento, con un'intensità
    # che "respira" piano (niente modulazioni veloci, che sembrano vibrazioni), un rombo grave
    # e qualche rara "presa" del legno. Coda e testa sfumate per un loop senza stacchi.
    dur, xfade = 2.0, 0.3
    n, nx = int(RATE * (dur + xfade)), int(RATE * xfade)
    t = t_of(dur + xfade)
    knots = np.arange(0, dur + xfade + 0.2, 0.2)
    breath = np.interp(t, knots, rng.uniform(0.65, 1.0, len(knots)))
    breath = lowpass(breath, 4)
    out = bandpass(noise(dur + xfade), 180, 1100) * breath
    out += lowpass(noise(dur + xfade), 120) * 1.2
    for at in (0.35, 0.9, 1.55, 2.05):
        for k in range(rng.integers(2, 4)):
            grain = bandpass(noise(0.03), 300, 1400) * env(int(RATE * 0.03), 0.001, 0.008)
            place(out, grain, at + k * rng.uniform(0.015, 0.03), 0.5)
    # Filtro prima della dissolvenza: filtrando dopo, il filtro ripartirebbe da zero in testa.
    out = lowpass(out, 2500)
    fade = np.linspace(0, 1, nx)
    loop = out[: int(RATE * dur)].copy()
    loop[:nx] = loop[:nx] * fade + out[-nx:] * (1 - fade)
    save("push.wav", loop, peak=0.5, fade_out=False)


def sizzle(dur, count, gain=1.0):
    """Sfrigolio elettrico: micro-crepitii sparsi e un soffio acuto che si spegne."""
    out = np.zeros(int(RATE * dur))
    for _ in range(count):
        at = rng.uniform(0, dur * 0.85)
        crack = highpass(noise(0.004), 3000) * env(int(RATE * 0.004), 0.0001, rng.uniform(0.0004, 0.0012))
        place(out, crack, at, rng.uniform(0.2, 1.0) * (1 - at / dur))
    t = t_of(dur)
    place(out, bandpass(noise(dur), 3000, 8000) * env(len(t), 0.002, dur * 0.3), 0.0, 0.25)
    return lowpass(out, 9000) * gain


def flicker_off():
    # Sfarfallio, la luce salta: doppio "tsk" del filamento, uno sfrigolio di contatto che
    # crepita e il ronzio che muore di colpo.
    dur = 0.11
    out = np.zeros(int(RATE * dur))
    place(out, bandpass(click(0.01, 0.0012, 1800), 1500, 4500), 0.0, 0.5)
    place(out, sizzle(0.1, 14), 0.002, 0.35)
    place(out, bandpass(click(0.008, 0.001, 1800), 1500, 4500), 0.008, 0.25)
    t = t_of(0.04)
    hum = np.tanh(3 * np.sin(2 * np.pi * 120 * t)) * np.exp(-t / 0.01)
    place(out, lowpass(hum, 1200), 0.0, 0.2)
    save("flicker_off.wav", out, peak=0.45)


def flicker_on():
    # Sfarfallio, la luce torna: scattino, breve "bzz" del filamento che si riscalda e un
    # tink di vetro appena accennato (stessa famiglia di flash_dud), con un filo di sfrigolio.
    dur = 0.12
    out = np.zeros(int(RATE * dur))
    place(out, lowpass(click(0.01, 0.0012, 1500), 4000), 0.0, 0.3)
    t = t_of(0.1)
    buzz = np.tanh(3 * np.sin(2 * np.pi * 120 * t)) * env(len(t), 0.003, 0.03)
    place(out, lowpass(buzz, 1500), 0.0, 0.35)
    place(out, glass(C7, 0.08, 0.03, index=1.0), 0.005, 0.06)
    place(out, sizzle(0.09, 9), 0.0, 0.25)
    save("flicker_on.wav", out, peak=0.45)


def pop(freq, gain=1.0):
    """Bollicina: un "blip" piccolissimo che scende di tono."""
    return sweep(freq, freq * 0.6, 0.02) * env(int(RATE * 0.02), 0.001, 0.005) * gain


def shadow_dissolve():
    # L'ombra si sfalda in pallini (ultimo secondo, è un avviso): bollicine che si fanno
    # sempre più fitte con la stessa curva dello shader (t^1.6) e un fruscio che cresce.
    dur = 1.0
    out = np.zeros(int(RATE * dur))
    for u in rng.uniform(0, 1, 40):
        at = u ** (1 / 2.6) * dur * 0.97
        place(out, pop(rng.uniform(1200, 2600)), at, 0.15 + 0.2 * at / dur)
    t = t_of(dur)
    place(out, bandpass(noise(dur), 800, 3000) * (t / dur) ** 1.6, 0.0, 0.12)
    save("shadow_dissolve.wav", room(lowpass(out, 6000), 0.4, 0.12), peak=0.45)


def shadow_puff():
    # L'ombra sparisce: "puff" leggero e arioso, come un soffio. Una "p" appena accennata,
    # un "u" breve di rumore nei medi e il "ff" d'aria acuta che sfuma. Niente bassi né coda
    # lunga: con quelli sembrava un tonfo lontano.
    dur = 0.28
    out = np.zeros(int(RATE * dur))
    place(out, highpass(noise(0.006), 500) * env(int(RATE * 0.006), 0.0005, 0.0015), 0.0, 0.3)
    n = int(RATE * 0.06)
    place(out, bandpass(noise(0.06), 300, 1200) * env(n, 0.004, 0.02), 0.002, 0.5)
    n = int(RATE * 0.25)
    place(out, bandpass(noise(0.25), 1500, 7000) * env(n, 0.012, 0.06), 0.01, 0.9)
    save("shadow_puff.wav", room(highpass(out, 250), 0.3, 0.08), peak=0.45)


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
    # Checkpoint che si accende: scattino ovattato e "ding-dong" di kalimba un'ottava sotto
    # (Do5 -> Fa5), corto e leggero per non coprire la musica.
    dur = 0.6
    out = np.zeros(int(RATE * dur))
    place(out, lowpass(click(0.015, 0.002, 800), 2000), 0.0, 0.3)
    place(out, kalimba(midi(72), 0.5, 0.12), 0.0, 0.5)
    place(out, kalimba(midi(77), 0.55, 0.18), 0.08, 0.6)
    save("checkpoint.wav", room(lowpass(out, 6000), 0.5, 0.15), peak=0.6)


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
    """Kalimba (come la prima versione della musica): tono rotondo + "tink" metallico armonico."""
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


def soft_tone(freq, dur, decay, bend=-2.0, bend_time=0.04):
    """Tono rotondo che "scivola" in su fino alla nota (glide cartoon da `bend` semitoni)."""
    t = t_of(dur)
    phase = 2 * np.pi * np.cumsum(freq * 2 ** (bend / 12 * np.exp(-t / bend_time))) / RATE
    x = np.sin(phase) + 0.18 * np.sin(2 * phase) * np.exp(-t / (decay * 0.5))
    return x * env(len(t), 0.008, decay)


def flash_soft():
    # D: "bloop-fwoom-ting" morbido. Pop tondo senza rumore, colpetto grave, soffio che si
    # apre come la luce, accordo Fa-La-Do-Fa che sale di un tono in 40 ms e luccichii puri.
    dur = 1.0
    out = np.zeros(int(RATE * dur))
    place(out, lowpass(sweep(620, 190, 0.06) * env(int(RATE * 0.06), 0.002, 0.02), 2500), 0.0, 0.45)
    place(out, lowpass(thump(130, 60, 0.18, 0.06), 400), 0.0, 0.5)
    place(out, whoosh(0.35, 400, 3200, 0.1, q=0.9), 0.0, 0.12)
    for i, (m, gain) in enumerate(((77, 0.32), (81, 0.28), (84, 0.24), (89, 0.18))):
        place(out, soft_tone(midi(m), 0.8, 0.2), 0.008 + i * 0.01, gain)
    for at, m in ((0.07, 96), (0.15, 101), (0.24, 93), (0.34, 98)):
        t = t_of(0.25)
        place(out, np.sin(2 * np.pi * midi(m) * t) * env(len(t), 0.003, 0.07), at, 0.07)
    return room(lowpass(out, 7500), 0.8, 0.22)


def victory_kalimba():
    # A: mini-finale nello stile della prima musica (kalimba): arpeggio Do-Fa-La-Do sopra il basso in Do
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


def nylon(freq, dur, damp=0.996, tone=2500):
    """Chitarra classica (Karplus-Strong): rumore filtrato che risuona nella "corda"."""
    n = int(RATE * dur)
    p = max(2, int(round(RATE / freq - 0.5)))
    out = np.zeros(n)
    out[:p] = lowpass(rng.uniform(-1, 1, p), tone)
    for i in range(p + 1, n):
        out[i] = damp * 0.5 * (out[i - p] + out[i - p - 1])
    return out * np.clip(t_of(dur) / 0.002, 0, 1)


def rhodes(freq, dur, decay=0.9):
    """Piano elettrico (FM): corpo tondo con un po' di "bark" e il tintinnio della lamella."""
    t = t_of(dur)
    x = np.sin(2 * np.pi * freq * t + 1.2 * np.exp(-t / 0.25) * np.sin(2 * np.pi * freq * t))
    x += 0.12 * np.sin(2 * np.pi * freq * 14 * t) * np.exp(-t / 0.02)
    x *= 1 + 0.08 * np.sin(2 * np.pi * 4.5 * t)
    return x * env(len(t), 0.003, decay)


def vibraphone(freq, dur, decay=1.0):
    """Vibrafono: tono puro con il quarto parziale della barra e il tremolo del motorino."""
    t = t_of(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.1)
    x *= 1 + 0.25 * np.sin(2 * np.pi * 5.5 * t)
    return x * env(len(t), 0.002, decay)


def victory_cozy():
    # D: "cozy" e corto. Chitarra nylon che sale Do-Fa-La-Do, poi Fa maj9 al piano
    # elettrico con basso, e il vibrafono che canta La -> Do sopra.
    dur = 2.0
    out = np.zeros(int(RATE * dur))
    for i, m in enumerate((60, 65, 69, 72)):
        place(out, nylon(midi(m), 1.2), i * 0.07, 1.0)
    land_at = 0.3
    place(out, rhodes(midi(41), 1.6, 0.8), land_at, 0.35)
    for i, m in enumerate((57, 64, 67, 72)):
        place(out, rhodes(midi(m), 1.6, 1.0), land_at + i * 0.015, 0.18)
    place(out, vibraphone(midi(81), 0.6, 0.25), land_at, 0.22)
    place(out, vibraphone(midi(84), 1.4, 0.9), land_at + 0.22, 0.25)
    return room(lowpass(out, 8000), 1.0, 0.25)


def victory_glow():
    # E: "irraggiamento" (1,5 s). La lampadina avvitata si accende e la luce invade la stanza:
    # un "bloom" che sale nella nota, un soffio luminoso che si apre, un pad caldo in Fa che
    # si gonfia e un luccichio di parziali acuti che tremolano piano.
    dur = 1.5
    out = np.zeros(int(RATE * dur))
    place(out, soft_tone(midi(89), 1.2, 0.45, bend=-3.0, bend_time=0.06), 0.0, 0.25)
    n = int(RATE * 0.9)
    t = t_of(0.9)
    cutoff = 300 * (5000 / 300) ** np.clip(t / 0.45, 0, 1)
    riser = svf_lowpass(rng.standard_normal(n), cutoff, 1.2) * np.clip(t / 0.3, 0, 1) * np.exp(-t / 0.35)
    place(out, riser, 0.0, 0.15)
    place(out, warm_pad((53, 60, 65, 69, 72), 1.5, 0.25, 0.6), 0.0, 0.12)
    t = t_of(1.2)
    for i, m in enumerate((84, 88, 89, 91, 93, 96)):
        shimmer = 1 + 0.35 * np.sin(2 * np.pi * rng.uniform(6, 9) * t + rng.uniform(0, 2 * np.pi))
        tone = np.sin(2 * np.pi * midi(m) * t) * shimmer
        place(out, tone * np.clip(t / 0.2, 0, 1) * np.exp(-t / 0.45), 0.08 + i * 0.04, 0.06)
    return room(lowpass(out, 9000), 0.9, 0.3)


VARIANTS = {
    "flash": {"a_kalimba": flash_kalimba, "b_synth": flash_stab, "c_bagliore": flash_burst,
              "d_morbido": flash_soft},
    "victory": {"a_kalimba": victory_kalimba, "b_fanfara": victory_fanfare,
                "c_carillon": victory_carillon, "d_cozy": victory_cozy,
                "e_irraggiamento": victory_glow},
}
## Variante usata in gioco (le altre si ascoltano in sounds/varianti con "varianti").
FLASH_VARIANT = "d_morbido"
VICTORY_VARIANT = "e_irraggiamento"


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
    """Tema di "Bulb & Shade": loop di 32 battute (~85 s) tra Re minore e Fa maggiore.

    Quattro sezioni da 8 battute che raccontano il gioco:
    A  "ombra": Re minore. Un orologio ticchetta nella stanza vuota, una marimba ovattata
       gira come un ingranaggio lontano e la celesta (la lampadina, vetro) sale Re-Fa-La
       e ricade nel buio.
    B  "luce": un luccichio e si accende tutto. Fa maggiore, piano elettrico, batteria,
       la melodia si apre in alto e un carillon la raddoppia come un riflesso.
    A' l'ombra torna, ma ora con il ritmo e un controcanto di carillon: l'ombra si usa.
    C  "la salita": il basso sale di grado (Sol La Sib Do Re), la melodia ripete il suo
       slancio sempre più in alto fino al Fa6, poi respira e rientra nel loop.
    Tutto diatonico a Fa maggiore: flash, vittoria e checkpoint stanno sempre in tono.
    """
    rate = 32000
    bpm = 90
    beat = 60 / bpm
    bars = 32
    length = int(round(rate * beat * 4 * bars))
    tail = int(rate * 4)
    dry = np.zeros(length + tail)
    send = np.zeros(length + tail)
    mrng = np.random.default_rng(1902)

    def hz(m):
        return 440 * 2 ** ((m - 69) / 12)

    def ts(sec):
        return np.arange(int(rate * sec)) / rate

    def damp(t, beats, release):
        """Smorzatore: la nota suona libera fino alla sua durata, poi si spegne."""
        off = beats * beat
        return np.where(t < off, 1.0, np.exp(-(t - off) / release))

    def put(x, at_beat, gain, verb=0.25, humanize=0.004):
        # Crome in levare un filo in ritardo (swing leggero) e micro-imprecisioni umane.
        whole = np.floor(at_beat + 1e-9)
        frac = at_beat - whole
        if abs(frac - 0.5) < 1e-6:
            frac = 0.56
        i = max(0, int(rate * ((whole + frac) * beat + mrng.uniform(-humanize, humanize))))
        m = min(len(x), len(dry) - i)
        dry[i:i + m] += x[:m] * gain
        send[i:i + m] += x[:m] * gain * verb

    def spectral(x, lo=None, hi=None):
        """Filtro a fase zero nel dominio della frequenza (circolare: perfetto per un loop)."""
        f = np.fft.rfftfreq(len(x), 1 / rate)
        g = np.ones(len(f))
        if hi:
            g /= np.sqrt(1 + (f / hi) ** 4)
        if lo:
            g /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)
        return np.fft.irfft(np.fft.rfft(x) * g, len(x))

    # --- Strumenti -----------------------------------------------------------------
    def celesta(m, beats):
        """La lampadina: campanello di vetro armonico, intonato, con la punta che brilla."""
        f = hz(m)
        t = ts(beats * beat + 1.2)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / 1.1)
        x += 0.3 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.35)
        x += 0.16 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.07)
        return x * damp(t, beats, 0.22) * np.clip(t / 0.002, 0, 1)

    def vibes(m, beats):
        """Vibrafono col motorino: il calore della luce accesa sotto la celesta."""
        f = hz(m)
        t = ts(beats * beat + 1.2)
        x = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.1)
        x *= 1 + 0.22 * np.sin(2 * np.pi * 5.2 * t)
        return x * np.exp(-t / 1.6) * damp(t, beats, 0.3) * np.clip(t / 0.003, 0, 1)

    def music_box(m):
        f = hz(m)
        t = ts(1.6)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.7)
        x += 0.3 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.08)
        return x * np.clip(t / 0.001, 0, 1)

    def mallet(m):
        """Marimba ovattata: l'ingranaggio della fabbrica, corto e legnoso."""
        f = hz(m)
        t = ts(0.5)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.15)
        x += 0.22 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t / 0.02)
        return x * np.clip(t / 0.0015, 0, 1)

    def bass(m, beats):
        """Basso pizzicato tondo; le armoniche lo fanno sentire anche sul telefono."""
        f = hz(m)
        t = ts(beats * beat + 0.3)
        x = np.sin(2 * np.pi * f * t)
        x += 0.5 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.3)
        x += 0.22 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.1)
        x *= np.exp(-t / 1.0) * damp(t, beats, 0.05) * np.clip(t / 0.006, 0, 1)
        return np.tanh(1.4 * x)

    def epiano(notes, beats):
        """Piano elettrico (FM): il tepore della stanza illuminata."""
        t = ts(beats * beat + 1.0)
        x = np.zeros(len(t))
        for m in notes:
            f = hz(m)
            x += np.sin(2 * np.pi * f * t + 1.0 * np.exp(-t / 0.2) * np.sin(2 * np.pi * f * t))
        x *= 1 + 0.07 * np.sin(2 * np.pi * 4.5 * t)
        return x * np.exp(-t / 1.4) * damp(t, beats, 0.12) * np.clip(t / 0.004, 0, 1)

    def pad(notes, beats):
        """Ombra: dente di sega morbido (poche armoniche), due voci leggermente stonate."""
        t = ts(beats * beat + 0.8)
        x = np.zeros(len(t))
        for m in notes:
            for det in (0.997, 1.003):
                ph = mrng.uniform(0, 2 * np.pi)
                for k in range(1, 6):
                    x += np.sin(2 * np.pi * hz(m) * det * k * t + ph * k) / k ** 1.8
        return x * np.clip(t / 0.6, 0, 1) * damp(t, beats, 0.5)

    def kick():
        t = ts(0.35)
        f = 48 + 70 * np.exp(-t / 0.03)
        x = np.sin(2 * np.pi * np.cumsum(f) / rate) * np.exp(-t / 0.2)
        x += 0.3 * np.sin(4 * np.pi * np.cumsum(f) / rate) * np.exp(-t / 0.06)
        return np.tanh(1.5 * x) * np.clip(t / 0.001, 0, 1)

    def tick(f0):
        """Tic-tac dell'orologio / colpo di bordo: legno piccolo e asciutto."""
        t = ts(0.12)
        x = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.012)
        x += 0.5 * np.sin(2 * np.pi * f0 * 1.73 * t) * np.exp(-t / 0.006)
        x += 0.3 * mrng.standard_normal(len(t)) * np.exp(-t / 0.002)
        return x

    hat_noise = mrng.standard_normal(int(rate * 0.08))

    def hat(decay=0.018):
        t = ts(0.08)
        x = np.diff(np.diff(hat_noise), prepend=0)  # rumore schiarito: resta solo il "tss"
        return x[:len(t)] * np.exp(-t[:len(x)] / decay) / 4

    def clank():
        """Tubo di metallo colpito lontano, in fondo al capannone."""
        t = ts(1.5)
        x = np.zeros(len(t))
        for ratio, amp, d in ((1, 1.0, 0.5), (2.76, 0.6, 0.3), (5.40, 0.35, 0.15), (8.93, 0.2, 0.08)):
            x += amp * np.sin(2 * np.pi * 196 * ratio * t) * np.exp(-t / d)
        return spectral(x * np.clip(t / 0.002, 0, 1), hi=2500)

    def riser(beats):
        """Soffio che sale verso il flash."""
        n = int(rate * beats * beat)
        t = np.arange(n) / rate
        x = mrng.standard_normal(n)
        y = np.empty(n)
        acc = 0.0
        alpha = 1 - np.exp(-2 * np.pi * (200 * 30 ** (t / t[-1])) / rate)
        for i in range(n):
            acc += alpha[i] * (x[i] - acc)
            y[i] = acc
        return y * (t / t[-1]) ** 2

    def shimmer(notes, dur):
        """La luce che si accende: parziali alti che tremolano piano."""
        t = ts(dur)
        x = np.zeros(len(t))
        for m in notes:
            trem = 1 + 0.35 * np.sin(2 * np.pi * mrng.uniform(5, 8) * t + mrng.uniform(0, 6))
            x += np.sin(2 * np.pi * hz(m) * t) * trem
        return x * np.clip(t / 0.08, 0, 1) * np.exp(-t / (dur * 0.35))

    # --- Armonia -------------------------------------------------------------------
    # Accordo: (basso, voci). Le voci stanno tra Re3 e Sol4, sotto la melodia.
    Dm9 = (50, (53, 57, 60, 64))
    Dm7 = (50, (53, 57, 60, 65))
    Bbmaj7 = (46, (53, 57, 58, 62))
    Bbmaj9 = (46, (53, 57, 60, 62))
    Gm9 = (43, (50, 53, 57, 58))
    Gm7 = (43, (50, 53, 55, 58))
    Am7 = (45, (52, 55, 57, 60))
    C6 = (48, (52, 55, 57, 60))
    Csus = (48, (53, 55, 60, 65))
    C = (48, (52, 55, 60, 64))
    Fmaj7 = (41, (53, 57, 60, 64))
    C_E = (52, (55, 60, 62, 67))
    # Un accordo per battuta; una coppia = sospensione che si risolve a metà battuta.
    A = [Dm9, Bbmaj7, Gm9, Am7, Dm9, Bbmaj7, Gm7, (Csus, C)]
    B = [Fmaj7, C_E, Dm7, Bbmaj9, Am7, Gm7, Bbmaj7, (Csus, C)]
    Cs = [Gm7, Am7, Bbmaj7, C6, Dm9, Bbmaj7, Gm9, (Csus, C)]
    chords = A + B + A + Cs

    # --- Melodia: (beat, nota, durata) per battuta ------------------------------------
    mel_A = [
        [(1.5, 74, .5), (2, 77, .5), (2.5, 81, 1.5)],
        [(0, 81, 1.5), (1.5, 79, .5), (2, 77, 1), (3, 74, 1)],
        [(1.5, 74, .5), (2, 77, .5), (2.5, 81, .5), (3, 84, 1)],
        [(0, 81, 1), (1, 79, 1), (2, 76, 2)],
        [(1.5, 74, .5), (2, 77, .5), (2.5, 81, 1.5)],
        [(0, 86, 1.5), (1.5, 84, .5), (2, 81, 1), (3, 77, 1)],
        [(0, 79, 1), (1, 82, 1), (2, 81, .5), (2.5, 79, .5), (3, 77, 1)],
        [(0, 77, 2), (2, 76, 2)],
    ]
    mel_B = [
        [(0, 81, 1.5), (1.5, 84, .5), (2, 88, 2)],
        [(0, 86, 1), (1, 84, 1), (2, 79, 2)],
        [(0, 81, 1), (1, 84, .5), (1.5, 86, .5), (2, 89, 1.5), (3.5, 88, .5)],
        [(0, 86, 2), (2, 84, 1), (3, 81, 1)],
        [(0, 84, 1.5), (1.5, 81, .5), (2, 79, 1), (3, 76, 1)],
        [(0, 77, 1), (1, 79, .5), (1.5, 82, .5), (2, 86, 2)],
        [(0, 84, 1), (1, 81, 1), (2, 82, .5), (2.5, 81, .5), (3, 79, 1)],
        [(0, 77, 2), (2, 79, 1), (3, 76, 1)],
    ]
    mel_C = [
        [(0, 74, .5), (.5, 77, .5), (1, 79, 1), (2, 82, 2)],
        [(0, 76, .5), (.5, 79, .5), (1, 81, 1), (2, 84, 2)],
        [(0, 77, .5), (.5, 81, .5), (1, 82, 1), (2, 86, 2)],
        [(0, 79, .5), (.5, 81, .5), (1, 84, 1), (2, 88, 1), (3, 86, 1)],
        [(0, 89, 2), (2, 88, 1), (3, 86, 1)],
        [(0, 86, 1.5), (1.5, 84, .5), (2, 81, 2)],
        [(0, 82, 1), (1, 81, 1), (2, 77, 1), (3, 74, 1)],
        [(0, 77, 2), (2, 76, 1.5)],
    ]
    melody = mel_A + mel_B + mel_A + mel_C
    # Controcanto di carillon nella seconda ombra: riempie i vuoti della melodia.
    counter = [
        [(0, 93), (.5, 89), (1, 88)], [(3.5, 93)],
        [(0, 94), (.5, 89), (1, 86)], [(2.5, 91), (3, 88), (3.5, 84)],
        [(0, 93), (.5, 89), (1, 88)], [(3.5, 89)],
        [(0, 94), (.5, 91), (1, 86)], [(2.5, 88), (3, 91), (3.5, 96)],
    ]

    # --- Arrangiamento ---------------------------------------------------------------
    for bar in range(bars):
        start = bar * 4
        sec = bar // 8  # 0 = A, 1 = B, 2 = A', 3 = C
        halves = chords[bar] if isinstance(chords[bar][0], tuple) else (chords[bar],)
        span = 4 / len(halves)
        for h, (root, voices) in enumerate(halves):
            at = start + h * span
            # Pad d'ombra pieno nelle sezioni scure, solo un velo nella luce.
            put(pad(voices, span), at, 0.022 if sec in (0, 2) else 0.012, verb=0.5)
            if sec in (1, 3) or (sec == 2 and bar % 2):
                put(epiano(voices, span * 0.6), at, 0.06, verb=0.35)
                if span == 4:
                    put(epiano(voices[1:], 1.2), at + 2.5, 0.04, verb=0.35)
            # Ostinato a crome: radice, poi le voci un'ottava sopra.
            r4 = root
            while r4 < 57:
                r4 += 12
            while r4 > 68:
                r4 -= 12
            tones = sorted({r4, *(v + 12 for v in voices)})
            accent = (1.0, .5, .75, .5, .85, .5, .7, .55)
            for k in range(int(span * 2)):
                step = (k + h * 4) % 8
                idx = (0, 2, 4, 2, 1, 2, 3, 2)[step]
                gain = 0.085 if sec != 1 else 0.065
                put(mallet(tones[min(idx, len(tones) - 1)]), at + k * 0.5,
                    gain * accent[step] * mrng.uniform(0.9, 1.05), verb=0.3)
            # Basso: lungo e calmo all'inizio, poi groove, poi la spinta della salita.
            octave = root + 12 if root < 46 else root - 12
            if bar < 4 or bar == 31:
                pattern = ((0, root, span - 0.5), (3.5, root + 7, .5)) if span == 4 else ((0, root, span),)
            elif sec == 3:
                pattern = ((0, root, .75), (1, root, .5), (1.5, octave, .5), (2, root + 7, .75),
                           (3, root, .5), (3.5, root + 7, .5))
            else:
                pattern = ((0, root, 1.5), (1.5, root, .5), (2, root + 7, 1), (3, octave, .5),
                           (3.5, root + 7, .5))
            for b, m, d in pattern:
                if b < span:
                    put(bass(m, d), at + b, 0.15 if b == 0 else 0.11, verb=0.08)

        # Melodia: celesta sempre, vibrafono nella luce e nella salita, carillon nella luce.
        for b, m, d in melody[bar]:
            put(celesta(m, d), start + b, 0.2, verb=0.4)
            if sec in (1, 3):
                put(vibes(m - 12, d), start + b, 0.05, verb=0.4)
            if sec == 1:
                put(music_box(m + 12), start + b, 0.03, verb=0.6)
        if sec == 2:
            for b, m in counter[bar % 8]:
                put(music_box(m), start + b, 0.045, verb=0.7)

        # Ritmo. Nell'ombra iniziale c'è solo l'orologio della stanza vuota.
        if sec == 0:
            for k in range(4):
                put(tick(1500 if k % 2 == 0 else 1250), start + k, 0.03 if bar < 4 else 0.04, verb=0.5)
            if bar >= 4:
                for k in range(4):
                    put(hat(), start + k + 0.5, 0.05, verb=0.2)
        else:
            last = bar == 31
            kicks = (0, 2.5) if sec != 3 else (0, 1.5, 2.5)
            if bar in (15, 23):
                kicks += (3.5,)
            for b in kicks:
                if not (last and b > 0):
                    put(kick(), start + b, 0.22, verb=0.05, humanize=0.0)
            for b in (1, 3):
                if not (last and b > 2):
                    put(tick(1500), start + b, 0.07, verb=0.35)
            for k in range(8):
                if not (last and k >= 4):
                    put(hat(0.03 if k % 4 == 3 else 0.016), start + k * 0.5,
                        0.065 if k % 2 else 0.04, verb=0.2)
        if bar in (3, 19, 23, 27):
            put(clank(), start + 3.5, 0.05, verb=1.2)

    # Effetti di racconto: il soffio che porta al flash e la luce che si accende.
    put(riser(3), 7 * 4 + 1, 0.035, verb=0.5, humanize=0)
    put(riser(3), 23 * 4 + 1, 0.025, verb=0.5, humanize=0)
    put(shimmer((89, 93, 96, 100, 101), 3.0), 8 * 4, 0.03, verb=0.8, humanize=0)
    put(shimmer((86, 89, 93, 98, 101), 2.5), 28 * 4, 0.02, verb=0.8, humanize=0)

    # --- Mix -----------------------------------------------------------------------
    # Loop senza stacchi: le code che escono dalla fine rientrano all'inizio.
    def fold(x):
        y = x[:length].copy()
        y[:tail] += x[length:]
        return y

    dry, send = fold(dry), fold(send)
    # Riverbero a convoluzione circolare: la coda della fine del loop suona sull'inizio.
    ir_t = ts(2.2)
    ir = np.random.default_rng(42).standard_normal(len(ir_t)) * np.exp(-6.9 * ir_t / 2.2)
    ir = spectral(np.concatenate([ir, np.zeros(len(ir))]), lo=200, hi=4500)[:len(ir_t)]
    ir *= np.clip(ir_t / 0.015, 0, 1)
    ir = np.concatenate([np.zeros(int(rate * 0.02)), ir]) / np.sqrt(np.sum(ir ** 2))
    wet = np.fft.irfft(np.fft.rfft(send) * np.fft.rfft(ir, length), length)
    mix = spectral(dry + wet * 0.5, lo=35, hi=9000)
    # Stessa intensità media della canzone precedente: i volumi del gioco restano tarati.
    mix = np.tanh(mix / np.max(np.abs(mix)) * 1.6)
    mix *= 10 ** (-18.3 / 20) / np.sqrt(np.mean(mix ** 2))
    data = (np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / "music.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)
    print("music.wav", f"{length / rate:.2f}s", f"picco {np.max(np.abs(mix)):.2f}")


def music_dark():
    """Tema dei livelli "dark": un carillon rotto che suona una ninna nanna in Re minore.

    Valzer lento (3/4), loop di 32 battute (~72 s). Re minore è la relativa del Fa
    maggiore della musica principale: flash, vittoria e checkpoint restano in tono.
    A  "la stanza vuota": solo il carillon, un po' stonato e tremolante come un nastro
       vecchio, sopra un bordone grave e il ronzio di un filamento. Ogni tanto un battito.
    B  "qualcosa respira": entrano il pad scuro, il basso pizzicato e il battito regolare;
       la melodia sale e la celesta grave le risponde con note al contrario (che si gonfiano).
    A' il carillon torna con un controcanto grave e un luccichio di vetro dissonante.
    C  "si scarica": armonia napoletana (Mib), note sempre più rade e più stonate, la
       corda che scricchiola; nell'ultima battuta l'ultima nota cala di tono e si sente
       la chiavetta che ricarica il carillon: il loop riparte da capo.
    """
    rate = 32000
    bpm = 80
    beat = 60 / bpm
    per_bar = 3
    bars = 32
    length = int(round(rate * beat * per_bar * bars))
    tail = int(rate * 5)
    dry = np.zeros(length + tail)
    send = np.zeros(length + tail)
    loop_sec = length / rate
    mrng = np.random.default_rng(1313)

    def hz(m):
        return 440 * 2 ** ((m - 69) / 12)

    def ts(sec):
        return np.arange(int(rate * sec)) / rate

    def put(x, at_beat, gain, verb=0.35, humanize=0.006):
        i = max(0, int(rate * (at_beat * beat + mrng.uniform(-humanize, humanize))))
        m = min(len(x), len(dry) - i)
        dry[i:i + m] += x[:m] * gain
        send[i:i + m] += x[:m] * gain * verb

    def spectral(x, lo=None, hi=None):
        f = np.fft.rfftfreq(len(x), 1 / rate)
        g = np.ones(len(f))
        if hi:
            g /= np.sqrt(1 + (f / hi) ** 4)
        if lo:
            g /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)
        return np.fft.irfft(np.fft.rfft(x) * g, len(x))

    def wobble_phase(f, t, depth, rate_hz):
        """Fase di una nota con il "wow" di un nastro vecchio: l'intonazione ondeggia."""
        ph = mrng.uniform(0, 2 * np.pi)
        return 2 * np.pi * f * (t - depth / (2 * np.pi * rate_hz) * np.cos(2 * np.pi * rate_hz * t + ph))

    # --- Strumenti -----------------------------------------------------------------
    def box(m, broken=0.0, fall=0.0):
        """Lamella di carillon: tono puro con un "tink" inarmonico in attacco.
        broken (0..1) la stona e la fa tremolare di più; fall la fa calare di tono
        (il carillon che si scarica)."""
        cents = mrng.uniform(-8, 8) + mrng.uniform(-30, 30) * broken
        f = hz(m) * 2 ** (cents / 1200)
        t = ts(2.4)
        if fall:
            ph = 2 * np.pi * np.cumsum(f * (1 - fall * np.clip(t / 1.6, 0, 1))) / rate
        else:
            ph = wobble_phase(f, t, 0.004 + 0.012 * broken, 0.6 + 0.8 * mrng.uniform())
        x = np.sin(ph) * np.exp(-t / 0.9)
        x += 0.22 * np.sin(3 * ph) * np.exp(-t / 0.18)
        x += 0.12 * np.sin(2 * np.pi * f * 5.43 * t) * np.exp(-t / 0.03)
        x += 0.15 * mrng.standard_normal(len(t)) * np.exp(-t / 0.0015)
        return x * np.clip(t / 0.0008, 0, 1)

    def celesta_low(m, beats, reverse=False):
        """Celesta grave e tonda; al contrario si gonfia verso il tempo forte."""
        f = hz(m)
        t = ts(beats * beat)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.9)
        x += 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.3)
        x *= np.clip(t / 0.003, 0, 1)
        if reverse:
            x = x[::-1] * np.clip((len(t) - np.arange(len(t))) / (rate * 0.02), 0, 1)
        return x

    def pad(notes, beats):
        """Pad scuro: dente di sega con poche armoniche, voci stonate, attacco lentissimo."""
        t = ts(beats * beat + 1.5)
        x = np.zeros(len(t))
        for m in notes:
            for det in (0.995, 1.0, 1.005):
                ph = mrng.uniform(0, 2 * np.pi)
                for k in range(1, 5):
                    x += np.sin(2 * np.pi * hz(m) * det * k * t + ph * k) / k ** 2.2
        env_ = np.clip(t / 1.2, 0, 1) * np.where(t < beats * beat, 1.0, np.exp(-(t - beats * beat) / 0.6))
        return spectral(x * env_, hi=1400)

    def pluck(m, beats):
        """Basso pizzicato, morbido e grave."""
        f = hz(m)
        t = ts(beats * beat + 0.4)
        x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.2)
        x *= np.exp(-t / 1.2) * np.clip(t / 0.008, 0, 1)
        return np.tanh(1.3 * x)

    def heartbeat():
        """Battito: "lub-dub", due tonfi gravi e ovattati."""
        out = np.zeros(int(rate * 0.8))
        for at, f0, g in ((0.0, 62, 1.0), (0.24, 54, 0.7)):
            t = ts(0.35)
            f = f0 + 30 * np.exp(-t / 0.02)
            x = np.sin(2 * np.pi * np.cumsum(f) / rate) * np.exp(-t / 0.09) * np.clip(t / 0.004, 0, 1)
            i = int(rate * at)
            out[i:i + len(x)] += x * g
        return spectral(out, hi=300)

    def tick(f0):
        t = ts(0.1)
        x = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.01)
        x += 0.4 * mrng.standard_normal(len(t)) * np.exp(-t / 0.002)
        return x

    def creak(dur):
        """Corda / trave che scricchiola: attrito a scatti (stick-slip) che fa risuonare il legno."""
        n = int(rate * dur)
        t = np.arange(n) / rate
        rate_curve = 25 + 45 * np.sin(np.pi * t / dur) ** 2 * mrng.uniform(0.7, 1.2)
        phase = np.cumsum(rate_curve) / rate
        clicks = np.zeros(n)
        idx = np.nonzero(np.diff(np.floor(phase)) > 0)[0]
        clicks[idx] = mrng.uniform(0.5, 1.0, len(idx))
        out = np.zeros(n)
        for f0, g in ((620, 1.0), (1180, 0.6), (1900, 0.3)):
            k = ts(0.03)
            ring = np.sin(2 * np.pi * f0 * k) * np.exp(-k / 0.006)
            out += np.convolve(clicks, ring)[:n] * g
        return out * np.sin(np.pi * t / dur) ** 0.5

    def clank():
        t = ts(1.8)
        x = np.zeros(len(t))
        for ratio, amp, d in ((1, 1.0, 0.6), (2.76, 0.6, 0.35), (5.40, 0.35, 0.15), (8.93, 0.2, 0.08)):
            x += amp * np.sin(2 * np.pi * 147 * ratio * t) * np.exp(-t / d)
        return spectral(x * np.clip(t / 0.002, 0, 1), hi=1800)

    def ratchet(dur):
        """La chiavetta del carillon che viene ricaricata: scatti metallici regolari."""
        out = np.zeros(int(rate * dur))
        k = 0.0
        while k < dur - 0.05:
            t = ts(0.03)
            c = mrng.standard_normal(len(t)) * np.exp(-t / 0.002)
            c += 0.6 * np.sin(2 * np.pi * 3100 * t) * np.exp(-t / 0.004)
            i = int(rate * k)
            out[i:i + len(c)] += c * mrng.uniform(0.6, 1.0)
            k += 0.075 + mrng.uniform(-0.006, 0.006)
        return spectral(out, lo=900, hi=7000)

    def shimmer(notes, dur):
        """Vetro che vibra: due note vicine (dissonanti) che tremolano piano."""
        t = ts(dur)
        x = np.zeros(len(t))
        for m in notes:
            trem = 1 + 0.4 * np.sin(2 * np.pi * mrng.uniform(4, 7) * t + mrng.uniform(0, 6))
            x += np.sin(2 * np.pi * hz(m) * t) * trem
        return x * np.sin(np.pi * t / dur) ** 2

    def breath(dur):
        """Soffio d'aria nel capannone, come un respiro lento."""
        n = int(rate * dur)
        t = np.arange(n) / rate
        x = spectral(mrng.standard_normal(n), lo=250, hi=900)
        return x * np.sin(np.pi * t / dur) ** 2

    # --- Bordone continuo: Re grave + La, ronzio del filamento. Le modulazioni hanno
    # periodi che dividono la durata del loop, così il bordone si richiude senza stacchi.
    t = np.arange(length) / rate

    def lfo(cycles, ph=0.0):
        return np.sin(2 * np.pi * cycles * t / loop_sec + ph)

    drone = np.zeros(length)
    for m, g in ((38, 1.0), (45, 0.45), (50, 0.25)):
        f = hz(m)
        # Frequenza arrotondata a un numero intero di cicli nel loop: niente click alla giunta.
        f = round(f * loop_sec) / loop_sec
        drone += g * np.sin(2 * np.pi * f * t) * (0.75 + 0.25 * lfo(3, m))
    hum_f = round(100 * loop_sec) / loop_sec
    hum = np.tanh(3 * np.sin(2 * np.pi * hum_f * t)) * (0.5 + 0.5 * lfo(5)) ** 2
    dry[:length] += spectral(drone, hi=500) * 0.05
    dry[:length] += spectral(hum, lo=80, hi=900) * 0.006

    # --- Armonia (basso, voci) -----------------------------------------------------
    Dm = (38, (57, 62, 65, 69))
    Bb = (34, (58, 62, 65, 70))
    Gm = (31, (55, 58, 62, 67))
    A = (33, (57, 61, 64, 67))
    Eb = (39, (58, 63, 67, 70))
    A_chords = [Dm, Bb, Gm, A, Dm, A, A, Dm]
    B_chords = [Bb, Dm, Gm, A, Bb, Gm, A, Dm]
    C_chords = [Dm, Eb, Dm, Eb, Gm, A, Dm, Dm]
    chords = A_chords + B_chords + A_chords + C_chords

    # --- Melodia (beat nella battuta da 3, nota, durata) -------------------------------
    mel_A = [
        [(0, 81, 1), (1, 77, 1), (2, 74, 1)],
        [(0, 76, 1.5), (1.5, 77, .5), (2, 79, 1)],
        [(0, 81, 2), (2, 82, 1)],
        [(0, 81, 3)],
        [(0, 81, 1), (1, 77, 1), (2, 74, 1)],
        [(0, 73, 1.5), (1.5, 74, .5), (2, 76, 1)],
        [(0, 77, 1), (1, 76, 1), (2, 73, 1)],
        [(0, 74, 3)],
    ]
    mel_B = [
        [(0, 86, 1), (1, 84, 1), (2, 82, 1)],
        [(0, 81, 2), (2, 77, 1)],
        [(0, 79, 1), (1, 82, 1), (2, 86, 1)],
        [(0, 85, 3)],
        [(0, 86, 1), (1, 84, 1), (2, 82, 1)],
        [(0, 81, 1), (1, 79, 1), (2, 77, 1)],
        [(0, 76, 1.5), (1.5, 77, .5), (2, 73, 1)],
        [(0, 74, 3)],
    ]
    mel_C = [
        [(0, 74, 1), (2, 77, 1)],
        [(0, 75, 2)],
        [(1, 81, 2)],
        [(0, 82, 1), (1, 79, 2)],
        [(0, 79, 1), (2, 82, 1)],
        [(0, 76, 1), (1, 73, 2)],
        [(0, 74, 3)],
        [],
    ]
    melody = mel_A + mel_B + mel_A + mel_C
    # Controcanto grave nella ripresa: risponde nelle pause della melodia.
    counter = [[(1, 62)], [(0, 58)], [(1, 55), (2, 58)], [(0, 57), (1.5, 61)],
               [(1, 62)], [(0, 57)], [(1, 61)], [(0, 50), (1, 57), (2, 62)]]

    # --- Arrangiamento ---------------------------------------------------------------
    for bar in range(bars):
        start = bar * per_bar
        sec = bar // 8  # 0 = A, 1 = B, 2 = A', 3 = C
        root, voices = chords[bar]
        if sec >= 1:
            put(pad(voices, per_bar), start, 0.016 if sec != 3 else 0.012, verb=0.6)
            put(pluck(root + 12, 2), start, 0.12, verb=0.15)
            if sec != 3 or bar < 30:
                put(pluck(root + 19, 1), start + 2, 0.06, verb=0.15)
        # Carillon: sempre; nella coda sempre più stonato, l'ultima nota cala di tono.
        broken = 0.0 if sec < 3 else 0.3 + 0.7 * (bar - 24) / 7
        for b, m, d in melody[bar]:
            fall = 0.07 if bar == 30 else 0.0
            put(box(m, broken, fall), start + b, 0.17, verb=0.5)
        if bar < 29:
            # "Um-pa-pa" del carillon sotto la melodia; nelle ultime battute si ferma.
            put(box(root + 24, broken * 0.5), start, 0.06, verb=0.5)
            for b in (1, 2):
                put(box(voices[1 + b], broken * 0.5), start + b, 0.035, verb=0.5)
        if sec == 1 and bar % 2 == 0:
            # La celesta grave risponde al contrario, gonfiandosi verso la battuta dopo.
            put(celesta_low(voices[0], 2, reverse=True), start + 1, 0.07, verb=0.5)
        if sec == 2:
            for b, m in counter[bar % 8]:
                put(celesta_low(m, 1.5), start + b, 0.08, verb=0.45)

        # Battito: radi all'inizio, regolari quando "qualcosa respira", poi rallentano.
        if (sec == 0 and bar % 4 == 3) or sec in (1, 2) or (sec == 3 and bar % 2 == 0 and bar < 30):
            put(heartbeat(), start, 0.32 if sec in (1, 2) else 0.22, verb=0.1, humanize=0)
        # Orologio della stanza vuota, solo nella prima parte.
        if sec == 0:
            for k in range(per_bar):
                put(tick(1400 if k == 0 else 1150), start + k, 0.018, verb=0.6)

        if bar in (6, 22):
            put(clank(), start + 2, 0.05, verb=1.3)
        if bar in (11, 19, 26):
            put(creak(1.6 + mrng.uniform(0, 0.8)), start + 1, 0.035, verb=0.7, humanize=0)
        if bar in (4, 14, 28):
            put(breath(4 * beat), start, 0.05, verb=0.8, humanize=0)
        if bar in (17, 21):
            put(shimmer((98, 99), 6 * beat), start, 0.012, verb=0.9, humanize=0)

    # Fine del loop: la chiavetta ricarica il carillon, che riparte dalla battuta 1.
    put(ratchet(1.4), 31 * per_bar + 1.0, 0.05, verb=0.4, humanize=0)

    # --- Mix (come music(): loop senza stacchi e stessa intensità media) ---------------
    def fold(x):
        y = x[:length].copy()
        y[:tail] += x[length:]
        return y

    dry, send = fold(dry), fold(send)
    ir_t = ts(3.0)
    ir = np.random.default_rng(42).standard_normal(len(ir_t)) * np.exp(-6.9 * ir_t / 3.0)
    ir = spectral(np.concatenate([ir, np.zeros(len(ir))]), lo=150, hi=3500)[:len(ir_t)]
    ir *= np.clip(ir_t / 0.02, 0, 1)
    ir = np.concatenate([np.zeros(int(rate * 0.03)), ir]) / np.sqrt(np.sum(ir ** 2))
    wet = np.fft.irfft(np.fft.rfft(send) * np.fft.rfft(ir, length), length)
    mix = spectral(dry + wet * 0.6, lo=30, hi=8000)
    mix = np.tanh(mix / np.max(np.abs(mix)) * 1.6)
    mix *= 10 ** (-18.3 / 20) / np.sqrt(np.mean(mix ** 2))
    data = (np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / "music_dark.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)
    print("music_dark.wav", f"{length / rate:.2f}s", f"picco {np.max(np.abs(mix)):.2f}")


def music_greenhouse():
    """Tema della serra: loop di 32 battute (~101 s) in Fa maggiore, acustico e umido.

    Stessa tonalità della musica principale (flash, vittoria e checkpoint in tono), con
    colori "lidi" (Sib maj7#11) che la fanno galleggiare come aria calda. Niente
    campanelli: qui suonano legno, corde e fiato, come in una serra piena di piante.
    A  "rugiada": il pianoforte col feltro spezza gli accordi piano, il clarinetto canta basso e caldo,
       le foglie frusciano (shaker). A metà entra il contrabbasso.
    B  "il lucernario si apre": l'aria si gonfia, il coro si apre, entra il flauto
       con spazzole, cassa morbida e conga.
    A' la rugiada torna, un corno lontano risponde sotto il clarinetto.
    C  "crescita": il flauto sale come un rampicante fino al Fa6 con il clarinetto
       un'ottava sotto e il corno che sale di grado, poi tutto ricade nel loop.
    """
    rate = 32000
    bpm = 76
    beat = 60 / bpm
    bars = 32
    length = int(round(rate * beat * 4 * bars))
    tail = int(rate * 4)
    dry = np.zeros(length + tail)
    send = np.zeros(length + tail)
    loop_sec = length / rate
    mrng = np.random.default_rng(808)

    def hz(m):
        return 440 * 2 ** ((m - 69) / 12)

    def ts(sec):
        return np.arange(int(rate * sec)) / rate

    def damp(t, beats, release):
        off = beats * beat
        return np.where(t < off, 1.0, np.exp(-(t - off) / release))

    def put(x, at_beat, gain, verb=0.3, humanize=0.005):
        # Crome in levare appena in ritardo: un dondolio pigro, da pomeriggio caldo.
        whole = np.floor(at_beat + 1e-9)
        frac = at_beat - whole
        if abs(frac - 0.5) < 1e-6:
            frac = 0.53
        i = max(0, int(rate * ((whole + frac) * beat + mrng.uniform(-humanize, humanize))))
        m = min(len(x), len(dry) - i)
        dry[i:i + m] += x[:m] * gain
        send[i:i + m] += x[:m] * gain * verb

    def spectral(x, lo=None, hi=None):
        f = np.fft.rfftfreq(len(x), 1 / rate)
        g = np.ones(len(f))
        if hi:
            g /= np.sqrt(1 + (f / hi) ** 4)
        if lo:
            g /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)
        return np.fft.irfft(np.fft.rfft(x) * g, len(x))

    # --- Strumenti -----------------------------------------------------------------
    def piano(m, dur=3.0):
        """Pianoforte "felt" (martelletti col feltro): due corde un filo stonate, parziali
        appena stirati che si spengono prima in alto, colpo sordo del martelletto."""
        f = hz(m)
        t = ts(dur)
        x = np.zeros(len(t))
        decay = 2.2 * (261.6 / f) ** 0.5
        for k in range(1, 9):
            fk = f * k * np.sqrt(1 + 0.0003 * k * k)
            amp = 1 / k ** 1.6
            for det in (0.9993, 1.0007):
                x += amp * np.sin(2 * np.pi * fk * det * t + mrng.uniform(0, 6)) * np.exp(-t * k / decay)
        x += 0.25 * spectral(mrng.standard_normal(len(t)), lo=80, hi=600) * np.exp(-t / 0.02)
        return spectral(x * np.clip(t / 0.004, 0, 1), hi=1800)

    def clarinet(m, beats):
        """Clarinetto: armoniche dispari, legno e fiato. Canta nella rugiada."""
        f = hz(m)
        dur = beats * beat
        t = ts(dur + 0.4)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 4.8 * t) * np.clip((t - 0.3) / 0.3, 0, 1)
        ph = 2 * np.pi * np.cumsum(f * vib) / rate
        x = np.sin(ph) + 0.08 * np.sin(2 * ph) + 0.4 * np.sin(3 * ph) + 0.2 * np.sin(5 * ph)
        x += 0.1 * np.sin(7 * ph)
        x += 0.05 * spectral(mrng.standard_normal(len(t)), lo=f, hi=f * 4)
        amp = np.clip(t / 0.06, 0, 1) * (0.9 + 0.1 * np.sin(np.pi * np.clip(t / max(dur, 0.1), 0, 1)))
        amp *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.09))
        return spectral(x * amp, hi=2800)

    def flute(m, beats):
        """Flauto con il fiato: l'aria che passa tra le foglie quando entra la luce."""
        f = hz(m)
        dur = beats * beat
        t = ts(dur + 0.4)
        vib = 1 + 0.005 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
        ph = 2 * np.pi * np.cumsum(f * vib) / rate
        x = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph) + 0.04 * np.sin(4 * ph)
        x += 0.12 * spectral(mrng.standard_normal(len(t)), lo=f * 0.9, hi=f * 3)
        amp = np.clip(t / 0.07, 0, 1) * (0.85 + 0.15 * np.clip(t / max(dur, 0.1), 0, 1))
        amp *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.1))
        return x * amp

    def horn(m, beats):
        """Corno lontano, ovattato: dente di sega chiuso dal filtro, si apre appena col fiato."""
        f = hz(m)
        dur = beats * beat
        t = ts(dur + 0.6)
        vib = 1 + 0.003 * np.sin(2 * np.pi * 4.8 * t + mrng.uniform(0, 6)) * np.clip((t - 0.3) / 0.4, 0, 1)
        ph = 2 * np.pi * np.cumsum(f * vib) / rate
        x = sum(np.sin(k * ph) / k for k in range(1, int(4000 / f)))
        amp = np.clip(t / 0.12, 0, 1) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.25))
        cutoff = 350 + 450 * amp * (0.8 + 0.2 * np.sin(np.pi * np.clip(t / max(dur, 0.1), 0, 1)))
        return svf_lowpass(x * amp, cutoff * RATE / rate, 0.7)

    def choir(notes, beats):
        """Coro lontano che canta "uuh": armoniche pesate dalle formanti della U (300 e
        800 Hz), voci un filo stonate con vibrato lento. L'umidità calda della serra."""
        t = ts(beats * beat + 1.2)
        x = np.zeros(len(t))
        for m in notes:
            for det in (0.996, 1.0, 1.004):
                f = hz(m) * det
                vib = 1 + 0.004 * np.sin(2 * np.pi * mrng.uniform(4.5, 5.5) * t + mrng.uniform(0, 6))
                ph = 2 * np.pi * np.cumsum(f * vib) / rate
                for k in range(1, int(2500 / f) + 1):
                    fk = f * k
                    amp = np.exp(-((fk - 300) / 160) ** 2) + 0.35 * np.exp(-((fk - 800) / 220) ** 2) + 0.05
                    x += amp * np.sin(k * ph)
        x += 0.02 * spectral(mrng.standard_normal(len(t)), lo=300, hi=2500)
        return spectral(x * np.clip(t / 1.0, 0, 1) * damp(t, beats, 0.7), hi=2000)

    def bass(m, beats):
        """Contrabbasso pizzicato, tondo e senza spigoli."""
        f = hz(m)
        t = ts(beats * beat + 0.3)
        x = np.sin(2 * np.pi * f * t)
        x += 0.45 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.25)
        x += 0.15 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.08)
        x *= np.exp(-t / 1.3) * damp(t, beats, 0.06) * np.clip(t / 0.008, 0, 1)
        return np.tanh(1.3 * x)

    def conga(f0, slap=False):
        """Conga suonata con la mano: pelle tesa, tonda; lo slap è più secco."""
        t = ts(0.4)
        fr = f0 * (1 + 0.15 * np.exp(-t / 0.015))
        x = np.sin(2 * np.pi * np.cumsum(fr) / rate) * np.exp(-t / (0.06 if slap else 0.14))
        x += (0.6 if slap else 0.25) * spectral(mrng.standard_normal(len(t)), lo=600, hi=3000) * np.exp(-t / 0.01)
        return x * np.clip(t / 0.001, 0, 1)

    def soft_kick():
        t = ts(0.4)
        f = 50 + 45 * np.exp(-t / 0.025)
        x = np.sin(2 * np.pi * np.cumsum(f) / rate) * np.exp(-t / 0.18)
        return spectral(x * np.clip(t / 0.003, 0, 1), hi=400)

    brush_noise = spectral(mrng.standard_normal(int(rate * 0.5)), lo=1500, hi=6000)

    def brush(long=False):
        """Spazzola sul rullante: "tsh" che striscia, più lungo sui battiti 2 e 4."""
        t = ts(0.5)
        a = 0.03 if long else 0.01
        x = brush_noise * np.clip(t / a, 0, 1) * np.exp(-t / (0.16 if long else 0.05))
        return x / 3

    leaf_noise = spectral(mrng.standard_normal(int(rate * 0.2)), lo=1800, hi=5500)

    def shaker(dur=0.05):
        """Foglie secche scosse (parenti di rustle.wav): soffio corto, scuro."""
        t = ts(0.2)
        return leaf_noise * np.clip(t / 0.008, 0, 1) * np.exp(-t / dur) / 3

    def plop():
        """Goccia grossa che cade nella vasca: "plop" grave e ovattato, senza suono di campana."""
        t = ts(0.3)
        fr = 140 * 2 ** (1.2 * (1 - np.exp(-t / 0.02)))
        x = np.sin(2 * np.pi * np.cumsum(fr) / rate) * np.exp(-t / 0.05)
        return spectral(x * np.clip(t / 0.003, 0, 1), hi=900)

    def gust(dur):
        """Aria tiepida dalle bocchette che si gonfia verso la luce."""
        n = int(rate * dur)
        t = np.arange(n) / rate
        x = spectral(mrng.standard_normal(n), lo=300, hi=1500)
        return x * np.sin(np.pi * t / dur) ** 2

    # --- Fondo continuo: aria umida della serra che respira piano (richiusa nel loop) ---
    t = np.arange(length) / rate
    air = spectral(mrng.standard_normal(length), lo=200, hi=900)
    air *= 0.6 + 0.4 * np.sin(2 * np.pi * 4 * t / loop_sec) * np.sin(2 * np.pi * 7 * t / loop_sec + 1)
    dry[:length] += air * 0.012

    # --- Armonia (basso, voci) -----------------------------------------------------
    Fmaj9 = (41, (57, 60, 64, 67))
    F_A = (45, (53, 57, 60, 64))
    Bb_lyd = (46, (53, 57, 62, 64))  # Sib maj7#11: il Mi della scala che "galleggia"
    Bbmaj9 = (46, (53, 57, 60, 62))
    Dm9 = (38, (53, 57, 60, 64))
    Am7 = (45, (52, 55, 57, 60))
    Gm9 = (43, (50, 53, 57, 58))
    Gm7 = (43, (50, 53, 55, 58))
    C6 = (48, (52, 55, 57, 60))
    Csus = (48, (53, 55, 60, 65))
    C = (48, (52, 55, 60, 64))
    A_ch = [Fmaj9, Fmaj9, Bb_lyd, Bb_lyd, Dm9, Am7, Gm9, (Csus, C)]
    B_ch = [Bbmaj9, C6, Am7, Dm9, Gm9, F_A, Bb_lyd, (Csus, C)]
    C_ch = [Gm7, F_A, Bbmaj9, C6, Dm9, Bb_lyd, Gm9, (Csus, C)]
    chords = A_ch + B_ch + A_ch + C_ch

    # --- Melodie (beat, nota, durata) ---------------------------------------------------
    # Rugiada: clarinetto nel registro medio, frasi lunghe che respirano.
    mel_A = [
        [(0, 69, 1.5), (1.5, 72, .5), (2, 76, 2)],
        [(0, 74, 1), (1, 72, 1), (2, 67, 2)],
        [(0, 69, 1.5), (1.5, 72, .5), (2, 77, 1.5), (3.5, 76, .5)],
        [(0, 74, 3), (3, 72, 1)],
        [(0, 69, 1), (1, 72, 1), (2, 76, 1.5), (3.5, 77, .5)],
        [(0, 79, 1.5), (1.5, 76, .5), (2, 72, 2)],
        [(0, 74, 1), (1, 77, 1), (2, 76, 1), (3, 74, 1)],
        [(0, 72, 2), (2, 72, 1), (3, 67, 1)],
    ]
    # Luce: il flauto si apre in alto.
    mel_B = [
        [(0, 81, 1.5), (1.5, 82, .5), (2, 86, 2)],
        [(0, 84, 1.5), (1.5, 81, .5), (2, 79, 1), (3, 81, 1)],
        [(0, 84, 1), (1, 88, 1), (2, 86, 1), (3, 84, 1)],
        [(0, 81, 3), (3, 77, 1)],
        [(0, 79, 1), (1, 82, 1), (2, 86, 1.5), (3.5, 84, .5)],
        [(0, 84, 2), (2, 81, 1), (3, 77, 1)],
        [(0, 79, 1), (1, 81, .5), (1.5, 84, .5), (2, 88, 2)],
        [(0, 86, 2), (2, 84, 2)],
    ]
    # Crescita: lo slancio si ripete sempre più in alto, come un rampicante.
    mel_C = [
        [(0, 74, .5), (.5, 77, .5), (1, 79, 1), (2, 82, 2)],
        [(0, 76, .5), (.5, 77, .5), (1, 81, 1), (2, 84, 2)],
        [(0, 77, .5), (.5, 81, .5), (1, 84, 1), (2, 86, 2)],
        [(0, 79, .5), (.5, 84, .5), (1, 86, 1), (2, 88, 1), (3, 91, 1)],
        [(0, 89, 2), (2, 88, 1), (3, 86, 1)],
        [(0, 84, 1.5), (1.5, 81, .5), (2, 88, 2)],
        [(0, 86, 1), (1, 82, 1), (2, 81, 1), (3, 77, 1)],
        [(0, 79, 2), (2, 76, 2)],
    ]
    melody = mel_A + mel_B + mel_A + mel_C
    # Corno: risponde sotto il clarinetto nella ripresa, sale di grado nella crescita.
    horn_A = [[(0, 57, 4)], [(0, 55, 2), (2, 52, 2)], [(0, 53, 4)], [(0, 50, 2), (2, 52, 2)],
               [(0, 53, 2), (2, 57, 2)], [(0, 55, 2), (2, 52, 2)], [(0, 50, 2), (2, 53, 2)],
               [(0, 53, 2), (2, 52, 2)]]
    horn_C = [[(0, 50, 4)], [(0, 48, 4)], [(0, 50, 4)], [(0, 52, 4)],
               [(0, 53, 4)], [(0, 52, 4)], [(0, 50, 4)], [(0, 48, 2), (2, 52, 2)]]

    # Pianoforte: accordo spezzato lento, una nota per battito: (beat, nota) dove 0 = basso,
    # 1 = quinta del basso, 2.. = voci dell'accordo dal basso in alto. Nella luce e
    # nella crescita si aggiunge una croma in levare.
    broken = ((0, 0), (1, 3), (2, 5), (3, 4))
    broken_lit = broken + ((2.5, 3),)
    piano_cache = {}

    def keys(m):
        if m not in piano_cache:
            piano_cache[m] = piano(m)
        return piano_cache[m]

    # --- Arrangiamento ---------------------------------------------------------------
    for bar in range(bars):
        start = bar * 4
        sec = bar // 8  # 0 = A, 1 = B, 2 = A', 3 = C
        halves = chords[bar] if isinstance(chords[bar][0], tuple) else (chords[bar],)
        span = 4 / len(halves)
        for h, (root, voices) in enumerate(halves):
            at = start + h * span
            put(choir(voices, span), at, 0.012 if sec in (0, 2) else 0.017, verb=0.7)
            p_root = root + 12 if root < 40 else root
            notes = (p_root, p_root + 7, *voices)
            for b, s in (broken_lit if sec in (1, 3) else broken):
                if h * span <= b < (h + 1) * span and not (bar == 31 and b >= 3):
                    gain = (0.11 if s < 2 else 0.075) * mrng.uniform(0.85, 1.05)
                    put(keys(notes[min(s, len(notes) - 1)]), start + b, gain, verb=0.45)
            # Basso: entra a metà della rugiada, poi cammina nella luce e nella crescita.
            if bar >= 4:
                octave = root + 12 if root < 44 else root - 12
                if sec in (1, 3) and bar != 31:
                    pattern = ((0, root, 1.5), (1.5, root + 7, .5), (2, octave, 1), (3, root + 7, 1))
                else:
                    pattern = ((0, root, span - 0.5), (span - 0.5, root + 7, .5))
                for b, m, d in pattern:
                    if b < span:
                        put(bass(m, d), at + b, 0.15 if b == 0 else 0.1, verb=0.1)

        # Melodia: clarinetto nella rugiada, flauto nella luce, tutti e due nella crescita.
        for b, m, d in melody[bar]:
            if sec in (0, 2):
                put(clarinet(m, d), start + b, 0.08, verb=0.4)
            else:
                put(flute(m, d), start + b, 0.07, verb=0.45)
                if sec == 3:
                    put(clarinet(m - 12, d), start + b, 0.035, verb=0.4)
        if sec in (2, 3):
            for b, m, d in (horn_A if sec == 2 else horn_C)[bar % 8]:
                put(horn(m, d), start + b, 0.06, verb=0.5)

        # Ritmo: foglie nella rugiada; spazzole, cassa morbida e conga nella luce.
        if sec in (1, 3):
            last = bar == 31
            for b in (0, 2.5):
                if not (last and b > 0):
                    put(soft_kick(), start + b, 0.2, verb=0.05, humanize=0)
            for k in range(8):
                if not (last and k >= 6):
                    long = k in (2, 6)
                    put(brush(long), start + k * 0.5, (0.07 if long else 0.03) * mrng.uniform(0.8, 1.1),
                        verb=0.25)
            for b, f0, slap in ((1.5, 196, False), (1.75, 196, False), (3, 262, True), (3.5, 196, False)):
                if not (last and b > 2):
                    put(conga(f0, slap), start + b, 0.06 if slap else 0.05, verb=0.3)
        elif bar >= 2:
            for k in range(8):
                put(shaker(0.06 if k % 2 else 0.03), start + k * 0.5,
                    (0.045 if k % 2 else 0.025) * mrng.uniform(0.8, 1.1), verb=0.25)
            if sec == 2 and bar % 2:
                put(conga(196), start + 3.5, 0.04, verb=0.3)
        if bar % 8 == 3:
            put(plop(), start + 3.5, 0.06, verb=0.5)

    # Racconto: l'aria della serra si gonfia prima che il lucernario si apra.
    put(gust(3 * beat), 7 * 4 + 1, 0.05, verb=0.6, humanize=0)
    put(gust(3 * beat), 23 * 4 + 1, 0.04, verb=0.6, humanize=0)

    # --- Mix (come music(): loop senza stacchi e stessa intensità media) ---------------
    def fold(x):
        y = x[:length].copy()
        y[:tail] += x[length:]
        return y

    dry, send = fold(dry), fold(send)
    # Serra di vetro: riverbero un po' più lungo e più chiaro della stanza della fabbrica.
    ir_t = ts(2.6)
    ir = np.random.default_rng(42).standard_normal(len(ir_t)) * np.exp(-6.9 * ir_t / 2.6)
    ir = spectral(np.concatenate([ir, np.zeros(len(ir))]), lo=180, hi=5000)[:len(ir_t)]
    ir *= np.clip(ir_t / 0.02, 0, 1)
    ir = np.concatenate([np.zeros(int(rate * 0.025)), ir]) / np.sqrt(np.sum(ir ** 2))
    wet = np.fft.irfft(np.fft.rfft(send) * np.fft.rfft(ir, length), length)
    mix = spectral(dry + wet * 0.55, lo=35, hi=9000)
    mix = np.tanh(mix / np.max(np.abs(mix)) * 1.6)
    mix *= 10 ** (-18.3 / 20) / np.sqrt(np.mean(mix ** 2))
    data = (np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / "music_greenhouse.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)
    print("music_greenhouse.wav", f"{length / rate:.2f}s", f"picco {np.max(np.abs(mix)):.2f}")


def modes(freq, dur, partials, decay):
    """Sintesi modale: parziali (rapporto, ampiezza, frazione di decay) che si spengono
    ciascuno per conto suo; i parziali alti muoiono prima, come negli oggetti veri."""
    t = t_of(dur)
    x = np.zeros(len(t))
    for ratio, amp, d in partials:
        phase = rng.uniform(0, 2 * np.pi)
        x += amp * np.sin(2 * np.pi * freq * ratio * t + phase) * np.exp(-t / (decay * d))
    return x * env(len(t), 0.0004, 10.0)


def loop_xfade(out, dur, xfade):
    """Taglia un loop di `dur` secondi sfumando la coda in eccesso dentro la testa."""
    n = int(RATE * dur)
    tail = out[n: n + int(RATE * xfade)]
    fade = np.linspace(0, 1, len(tail))
    loop = out[:n].copy()
    loop[:len(tail)] = loop[:len(tail)] * fade + tail * (1 - fade)
    return loop


def can():
    # Lattina di latta calciata: "tlonk" metallico e vuoto. La lamiera sottile ha parziali
    # inarmonici fitti (il "clang"), la cavità d'aria dà il corpo "tonk" grave, e il bordo
    # che rimbalza sul cemento aggiunge un paio di micro-scatti di latta che sferragliano.
    shell = ((1.0, 1.0, 1.0), (1.47, 0.7, 0.8), (2.09, 0.55, 0.6), (2.56, 0.45, 0.5),
             (3.31, 0.35, 0.35), (4.18, 0.25, 0.25), (5.43, 0.18, 0.18))
    for i, (f0, body_f) in enumerate(((820, 340), (760, 310), (900, 370)), 1):
        dur = 0.32
        out = np.zeros(int(RATE * dur))
        # Colpo: rumore brillante cortissimo (la latta che "schiocca").
        place(out, bandpass(click(0.015, 0.0015, 1500), 2500, 9000), 0.0, 0.7)
        # Lamiera: un leggero stiramento casuale dei rapporti rende ogni variante diversa.
        jitter = tuple((r * rng.uniform(0.98, 1.02), a, d) for r, a, d in shell)
        place(out, modes(f0, dur, jitter, 0.07), 0.0, 0.8)
        # Distorsione morbida: i parziali si "sporcano" a vicenda, più lamiera e meno campanella.
        out = np.tanh(out * 1.8) / 1.8
        # Cavità: tono vuoto e scuro che scende un po' mentre si smorza.
        place(out, thump(body_f, body_f * 0.85, 0.12, 0.035), 0.0, 0.5)
        # Sferragliata: il bordo tocca il pavimento ancora un paio di volte, sempre più piano.
        at = 0.0
        for k in range(rng.integers(2, 4)):
            at += rng.uniform(0.035, 0.06)
            tick = modes(f0 * rng.uniform(1.4, 1.8), 0.05, shell[:4], 0.012)
            tick += pad(bandpass(click(0.01, 0.001, 2000), 3000, 8000), 0.05) * 0.6
            place(out, tick, at, 0.3 * 0.55 ** k)
        save(f"can_{i}.wav", room(lowpass(out, 9000), 0.35, 0.12), peak=0.6)


def glass_hit():
    # Barattolo / bottiglia di vetro: "clink" spesso. Il "tok" sordo del fondo che batte, poi
    # il vetro che canta: parziali alti e puri (rapporti da coppa) che durano più della latta,
    # con un battimento leggero (due modi quasi uguali) che lo fa "vibrare". Stessa palette
    # FM dei campanelli della lampadina, per tenere vetro con vetro.
    cup = ((1.0, 1.0, 1.0), (1.004, 0.6, 1.0), (2.32, 0.5, 0.55), (4.25, 0.3, 0.3),
           (6.63, 0.15, 0.18))
    for i, f0 in enumerate((1480, 1390, 1570), 1):
        dur = 0.55
        out = np.zeros(int(RATE * dur))
        place(out, lowpass(click(0.012, 0.0012, 600), 3500), 0.0, 0.5)
        place(out, thump(420, 260, 0.05, 0.012), 0.0, 0.55)
        place(out, modes(f0, dur, cup, 0.16), 0.002, 0.55)
        place(out, glass(f0 * 2.0, 0.2, 0.05, index=1.4), 0.002, 0.2)
        # Un secondo contatto leggero ("cli-clink") subito dopo.
        at = rng.uniform(0.045, 0.07)
        place(out, modes(f0 * 1.02, 0.25, cup, 0.06), at, 0.18)
        save(f"glass_{i}.wav", room(lowpass(out, 10000), 0.5, 0.15), peak=0.55)


def resonate(x, modes_):
    """Banco di risonatori (filtri a due poli molto stretti): il rumore che li attraversa
    "suona" come l'oggetto che ha quei modi. modes_ = (frequenza, banda in Hz, guadagno)."""
    out = np.zeros(len(x))
    for freq, bw, gain in modes_:
        r = np.exp(-np.pi * bw / RATE)
        a1, a2 = -2 * r * np.cos(2 * np.pi * freq / RATE), r * r
        y = np.empty(len(x))
        y1 = y2 = 0.0
        for i, v in enumerate(x * (1 - r)):
            y0 = v - a1 * y1 - a2 * y2
            y[i] = y0
            y2, y1 = y1, y0
        out += y * gain
    return out


# Modi della lamiera della ventola (cornice e pale stampate): inarmonici e fitti.
FAN_METAL = ((540, 6, 1.0), (812, 7, 0.8), (1193, 9, 0.7), (1655, 11, 0.5),
             (2247, 14, 0.4), (3018, 18, 0.25), (3870, 24, 0.15))


def fan():
    # Ventola da muro arrugginita, due strati che lo script lega alla rotazione:
    # - fan_grind (loop): la lamiera della cornice che vibra mentre gira: ronzio metallico
    #   liscio e intonato; il pitch segue la velocità.
    # - fan_air (loop): spostamento d'aria leggero, morbido e scuro; lo script ne alza il
    #   volume quando passa una pala ("fff... fff").
    dur, xfade = 2.0, 0.3
    total = dur + xfade
    # Lamiera che "canta" piano mentre gira: niente grani (sembravano sabbia), un'eccitazione
    # liscia e scura che fa risuonare solo i modi bassi della cornice, molto stretti. Ne esce
    # un ronzio metallico intonato che ondeggia lento (periodo = loop).
    t = t_of(total)
    excite = bandpass(noise(total), 400, 1400)
    # Modi un po' più larghi e quelli alti attenuati: il metallo resta, senza fischiare.
    soft = ((540, 1.0), (812, 0.6), (1193, 0.3), (1655, 0.12))
    hum = resonate(excite, tuple((f, bw * 0.8, g * k) for (f, bw, g), (_, k) in zip(FAN_METAL, soft)))
    hum *= 1 + 0.25 * np.sin(2 * np.pi * t / dur)
    save("fan_grind.wav", loop_xfade(lowpass(hum, 1300), dur, xfade), peak=0.5, fade_out=False)
    # Aria: loop lungo (12 s) perché la ripetizione non si riconosca. Raffiche lente e
    # irregolari invece di un "respiro" fitto, e il colore che vira piano tra un soffio più
    # cupo e uno un po' più aperto; nessun dettaglio che spicca e fa da "segnaposto" al loop.
    dur, xfade = 12.0, 1.5
    total = dur + xfade
    t = t_of(total)

    def drift(step, lo, hi, cutoff):
        knots = np.arange(0, total + step, step)
        return lowpass(np.interp(t, knots, rng.uniform(lo, hi, len(knots))), cutoff)

    gust = drift(1.3, 0.55, 1.0, 0.6)
    color = drift(2.1, 0.0, 1.0, 0.4)
    dark = bandpass(noise(total), 150, 700)
    open_ = bandpass(noise(total), 300, 1300)
    air = (dark * (1 - 0.6 * color) + open_ * (0.4 + 0.6 * color)) * gust
    save("fan_air.wav", loop_xfade(lowpass(air, 1400), dur, xfade), peak=0.5, fade_out=False)


def rustle():
    # Fruscio di foglie quando la lampadina passa tra le piante: di sottofondo, mai in
    # primo piano. Un "fff" morbido che si gonfia e si spegne come una spazzolata, e
    # dentro tanti micro-scricchiolii di foglia (grani di rumore cortissimi) più fitti
    # dove la spazzolata è più forte. Niente acuti taglienti: tutto filtrato scuro come
    # il resto della serra. È il suono che si ripete di più, quindi sei varianti molto
    # diverse tra loro: lunghezza, colore del soffio, foglie più secche o più morbide,
    # spazzolata unica o doppia (due rami che si toccano uno dopo l'altro).
    for i in range(1, 7):
        dur = rng.uniform(0.3, 0.6)
        out = np.zeros(int(RATE * dur))
        n = len(out)
        t = t_of(dur)
        swell = np.zeros(n)
        bursts = 1 if i % 3 else 2
        for b in range(bursts):
            at = 0.0 if b == 0 else rng.uniform(0.12, 0.22)
            rise = rng.uniform(0.03, 0.12)
            fall = (dur - at) * rng.uniform(0.18, 0.35)
            s_ = np.clip((t - at) / rise, 0, 1) * np.exp(-np.maximum(t - at - rise, 0) / fall)
            swell = np.maximum(swell, s_ * (1.0 if b == 0 else rng.uniform(0.5, 0.8)))
        step = rng.uniform(0.025, 0.06)
        knots = np.arange(0, dur + step, step)
        swell *= lowpass(np.interp(t, knots, rng.uniform(0.5, 1.0, len(knots))), 30)
        # Soffio: a volte più cupo (foglie larghe), a volte più aperto (fronde sottili).
        lo, hi = rng.uniform(400, 900), rng.uniform(1800, 3200)
        place(out, bandpass(noise(dur), lo, hi) * swell, 0.0, rng.uniform(0.25, 0.45))
        # Foglie che si sfregano: secche (grani brillanti e fitti) o morbide (pochi e scuri).
        dry = rng.uniform(0, 1)
        g_lo = 1300 + 1000 * dry
        g_hi = 4200 + 1500 * dry
        for _ in range(int(25 + 30 * dry * rng.uniform(0.7, 1.3))):
            at = rng.uniform(0, dur * 0.85)
            k = int(RATE * at)
            g_dur = rng.uniform(0.003, 0.012)
            grain = bandpass(noise(g_dur), g_lo, g_hi) * env(int(RATE * g_dur), 0.0005, g_dur * 0.35)
            place(out, grain, at, rng.uniform(0.25, 1.0) * swell[min(k, n - 1)])
        save(f"rustle_{i}.wav", room(lowpass(out, rng.uniform(4000, 5800)), 0.3, 0.1), peak=0.4)


def spark():
    # Scintille dai fili scoperti (portalampada rotto, cavo strappato): uno schiocco secco di
    # contatto, uno sfrigolio che crepita e si spegne, e un colpo di ronzio di rete a 100 Hz
    # che muore subito. Stessa famiglia di flicker_off, ma più sporco e più lungo. Tre
    # varianti: lunghezza, fittezza dei crepitii e quanti schiocchi (uno o due ravvicinati).
    for i in range(1, 4):
        dur = rng.uniform(0.2, 0.34)
        out = np.zeros(int(RATE * dur))
        snaps = 1 if i != 2 else 2
        for k in range(snaps):
            at = 0.0 if k == 0 else rng.uniform(0.04, 0.07)
            place(out, bandpass(click(0.012, 0.0015, 2500), 1400, 6500), at, 0.75 if k == 0 else 0.45)
        place(out, sizzle(dur * 0.9, int(rng.uniform(20, 36))), 0.002, 0.6)
        t = t_of(0.07)
        hum = np.tanh(4 * np.sin(2 * np.pi * 100 * t)) * np.exp(-t / 0.018)
        place(out, lowpass(hum, 1500), 0.0, 0.3)
        save(f"spark_{i}.wav", room(out, 0.4, 0.12), peak=0.5)


SFX = (jump, land, flash, flash_ready, flash_dud, drip, death, tap, button,
       checkpoint, collect, mini_flash, victory, step, shadow_step, push,
       flicker_off, flicker_on, shadow_dissolve, shadow_puff, can, glass_hit, fan, rustle,
       spark)
ALL = {f.__name__: f for f in SFX + (music, music_dark, music_greenhouse, varianti)}

OUT.mkdir(parents=True, exist_ok=True)
for name in sys.argv[2:] or [f.__name__ for f in SFX]:
    ALL[name]()
