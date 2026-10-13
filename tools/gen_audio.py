"""สังเคราะห์เสียงทั้งหมดของเกม วังเวง (ไม่ใช้ไฟล์เสียงภายนอก)
รัน: python3 tools/gen_audio.py  -> assets/audio/*.wav
"""
import numpy as np
import wave
import os
from scipy import signal

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(1234)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(x, name, peak=0.9):
    x = norm(x, peak)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x)/SR:.2f}s")


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def env(n, a, d):
    """attack/decay envelope (วินาที)"""
    e = np.ones(n)
    na, nd = int(a * SR), int(d * SR)
    if na > 0:
        e[:na] = np.linspace(0, 1, na)
    if nd > 0:
        e[-nd:] *= np.linspace(1, 0, nd) ** 2
    return e


def loopify(x, fade=0.5):
    """ทำให้วนลูปได้เนียน: crossfade หางกับหัว"""
    n = int(fade * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    ramp = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * ramp + tail * (1 - ramp)
    return x


def reverb(x, decay=1.6, mix=0.35):
    n = int(decay * SR)
    ir = R.normal(0, 1, n) * np.exp(-np.linspace(0, 7, n))
    ir = lp(ir, 3500)
    wet = np.zeros(len(x) + n)
    c = signal.fftconvolve(x, ir)
    wet[: min(len(c), len(wet))] = c[: len(wet)]
    out = np.concatenate([x, np.zeros(n)]) * (1 - mix) + norm(wet, np.max(np.abs(x)) + 1e-9) * mix
    return out


# ---------------- บรรยากาศในบ้าน (drone) ----------------
L = 24.0
tt = t(L)
x = np.zeros_like(tt)
for f, a in ((41.2, 0.5), (55.0, 0.35), (58.3, 0.25), (82.4, 0.12), (116.5, 0.06)):
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * tt / L * R.integers(1, 4) + R.random() * 6)
    x += a * lfo * np.sin(2 * np.pi * f * tt + 0.8 * np.sin(2 * np.pi * 0.07 * tt))
wind = bp(R.normal(0, 1, len(tt)), 200, 900)
wind *= 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / L * 3 + 1)) ** 2
x += wind
# เสียงไม้ลั่นเป็นระยะ
for at in (4.3, 11.7, 19.2):
    i = int(at * SR)
    n = int(0.5 * SR)
    ct = np.arange(n) / SR
    creak = np.sign(np.sin(2 * np.pi * (180 + 60 * np.sin(ct * 9)) * ct)) * np.exp(-ct * 5)
    x[i:i + n] += 0.12 * bp(creak, 300, 2500)
save(loopify(x, 1.0), "amb_house.wav", 0.6)

# ---------------- กลางคืนในสวน: จิ้งหรีด + ตุ๊กแก ----------------
L = 20.0
tt = t(L)
x = bp(R.normal(0, 1, len(tt)), 300, 1200) * 0.15
for cf in (4200, 4700, 5300):
    chirp = (np.sin(2 * np.pi * cf * tt)) * ((np.sin(2 * np.pi * (R.uniform(2.5, 4)) * tt) > 0.3).astype(float))
    chirp *= (np.sin(2 * np.pi * 28 * tt) > 0).astype(float)
    x += 0.04 * lp(chirp, 7000)
# ตุ๊กแก "ตุ๊ก-แก" ×4
gi = int(9.0 * SR)
for k in range(4):
    for j, (f, dur) in enumerate(((620, 0.12), (430, 0.22))):
        n = int(dur * SR)
        ct = np.arange(n) / SR
        v = np.sin(2 * np.pi * f * ct + 3 * np.sin(2 * np.pi * 45 * ct)) * env(n, 0.01, dur * 0.7)
        v = bp(v + 0.3 * np.sign(v), 250, 2500)
        start = gi + int(k * 0.75 * SR) + int(j * 0.17 * SR)
        x[start:start + n] += 0.35 * v
save(loopify(x, 1.0), "amb_night.wav", 0.5)

# ---------------- ฝีเท้า (ไม้ / หญ้า) ----------------
for k in range(4):
    n = int(0.22 * SR)
    ct = np.arange(n) / SR
    thump = lp(R.normal(0, 1, n), 320) * np.exp(-ct * 30)
    knock = bp(R.normal(0, 1, n), 700, 2200) * np.exp(-ct * 70) * 0.4
    s = thump + knock
    if k % 2 == 0:  # ไม้เอี๊ยด
        cn = int(0.18 * SR)
        cc = np.arange(cn) / SR
        cr = np.sign(np.sin(2 * np.pi * (230 + 90 * k) * cc + 4 * np.sin(cc * 30))) * np.exp(-cc * 12)
        s[:cn] += 0.12 * bp(cr, 500, 3000)
    save(s, f"step_wood_{k+1}.wav", 0.8)
for k in range(3):
    n = int(0.25 * SR)
    ct = np.arange(n) / SR
    s = hp(R.normal(0, 1, n), 1500) * np.exp(-ct * 18) * (1 + 0.5 * np.sin(ct * 300))
    s += lp(R.normal(0, 1, n), 200) * np.exp(-ct * 35) * 0.6
    save(s, f"step_grass_{k+1}.wav", 0.6)

# ---------------- หัวใจเต้น ----------------
n = int(0.9 * SR)
x = np.zeros(n)
for off, amp in ((0.0, 1.0), (0.22, 0.7)):
    m = int(0.15 * SR)
    ct = np.arange(m) / SR
    beat = np.sin(2 * np.pi * 55 * ct) * np.exp(-ct * 28) + np.sin(2 * np.pi * 38 * ct) * np.exp(-ct * 20)
    i = int(off * SR)
    x[i:i + m] += amp * beat
save(lp(x, 180), "heartbeat.wav", 0.95)

# ---------------- หายใจหอบ ----------------
L = 3.2
tt = t(L)
breath = bp(R.normal(0, 1, len(tt)), 400, 2600)
e = np.zeros_like(tt)
for s0, dur, a in ((0.0, 1.0, 0.8), (1.25, 1.4, 1.0)):
    i, m = int(s0 * SR), int(dur * SR)
    e[i:i + m] = np.sin(np.linspace(0, np.pi, m)) ** 1.5 * a
save(loopify(breath * e, 0.1), "breath.wav", 0.5)

# ---------------- เสียงกระซิบ ----------------
L = 7.0
tt = t(L)
x = np.zeros_like(tt)
pos = 0.2
while pos < L - 0.5:
    dur = R.uniform(0.08, 0.28)
    i, m = int(pos * SR), int(dur * SR)
    noise = R.normal(0, 1, m)
    f1, f2 = R.uniform(500, 900), R.uniform(1300, 2600)
    syl = bp(noise, f1 * 0.8, f1 * 1.3) + 0.7 * bp(noise, f2 * 0.85, f2 * 1.2) + 0.3 * hp(noise, 4000)
    if R.random() < 0.3:  # เสียงซ
        syl = hp(noise, 3500) * 1.4
    x[i:i + m] += syl * np.sin(np.linspace(0, np.pi, m)) ** 2
    pos += dur + (R.uniform(0.25, 0.8) if R.random() < 0.25 else R.uniform(0.01, 0.06))
x = reverb(x, 1.2, 0.4)[: len(tt)]
save(loopify(x, 0.3), "whisper.wav", 0.6)

# ---------------- เสียงครางของแม่หญิง (loop 3D) ----------------
L = 9.0
tt = t(L)
f0 = 330 * (1 + 0.08 * np.sin(2 * np.pi * 0.11 * tt) + 0.012 * np.sin(2 * np.pi * 5.5 * tt))
ph = 2 * np.cumsum(f0) * np.pi / SR
v = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
v = bp(v, 600, 1200) * 0.7 + bp(v, 2400, 3200) * 0.3  # formant "อู/อา"
amp = (0.5 + 0.5 * np.sin(2 * np.pi * tt / L * 2 - 1.5)) ** 2
x = v * amp + 0.15 * bp(R.normal(0, 1, len(tt)), 200, 600)
x = reverb(x, 2.0, 0.5)[: len(tt)]
save(loopify(x, 0.8), "ghost_hum.wav", 0.7)

# ---------------- จั๊มสแกร์: กรีดร้อง ----------------
L = 1.8
tt = t(L)
x = np.zeros_like(tt)
for det in (1.0, 1.06, 1.13, 1.5, 0.97):
    f = 900 * det * (1 + 0.5 * np.exp(-tt * 3)) * (1 + 0.02 * np.sin(2 * np.pi * 9 * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x += signal.sawtooth(ph) * 0.4
x += R.normal(0, 1, len(tt)) * 0.8
x = bp(x, 500, 5000) * env(len(tt), 0.01, 1.0)
x += lp(R.normal(0, 1, len(tt)), 120) * np.exp(-tt * 3) * 2  # ตูม
save(np.tanh(x * 2), "scream.wav", 0.98)

# ---------------- ประตู ----------------
L = 1.3
tt = t(L)
f = 140 + 120 * np.sin(np.pi * tt / L) + 30 * np.sin(2 * np.pi * 3 * tt)
pulse = (np.sin(2 * np.pi * np.cumsum(f) / SR) > 0.9).astype(float)
x = bp(pulse, 400, 3000) * env(len(tt), 0.05, 0.3)
save(reverb(x, 0.8, 0.3), "door_open.wav", 0.7)
n = int(0.6 * SR)
ct = np.arange(n) / SR
x = lp(R.normal(0, 1, n), 250) * np.exp(-ct * 14) + bp(R.normal(0, 1, n), 800, 2500) * np.exp(-ct * 40) * 0.3
save(x, "door_close.wav", 0.8)
x = np.zeros(int(0.7 * SR))
for k, at in enumerate((0.0, 0.12, 0.27, 0.36)):
    m = int(0.08 * SR)
    ct = np.arange(m) / SR
    i = int(at * SR)
    x[i:i + m] += bp(R.normal(0, 1, m), 1500, 5000) * np.exp(-ct * 60) + np.sin(2 * np.pi * 2300 * ct) * np.exp(-ct * 50) * 0.5
save(x, "door_locked.wav", 0.7)
n = int(1.5 * SR)
ct = np.arange(n) / SR
x = lp(R.normal(0, 1, n), 180) * np.exp(-ct * 6) * 2 + bp(R.normal(0, 1, n), 600, 3000) * np.exp(-ct * 25)
save(reverb(np.tanh(x * 1.5), 1.5, 0.4), "door_slam.wav", 0.95)
# ปลดล็อก
x = np.zeros(int(0.5 * SR))
for at in (0.0, 0.18):
    m = int(0.06 * SR)
    ct = np.arange(m) / SR
    i = int(at * SR)
    x[i:i + m] += np.sin(2 * np.pi * 1800 * ct) * np.exp(-ct * 70) + bp(R.normal(0, 1, m), 2000, 6000) * np.exp(-ct * 90)
save(x, "unlock.wav", 0.7)

# ---------------- เก็บของ: กระดิ่ง/ระฆังเล็ก ----------------
n = int(1.6 * SR)
ct = np.arange(n) / SR
x = sum(a * np.sin(2 * np.pi * 1320 * r * ct) * np.exp(-ct * d) for r, a, d in ((1, 1, 3), (2.76, 0.5, 5), (5.4, 0.25, 8), (8.9, 0.1, 12)))
save(x, "pickup.wav", 0.5)
# ระฆังวัดใหญ่ (ฉากจบ)
n = int(6 * SR)
ct = np.arange(n) / SR
x = sum(a * np.sin(2 * np.pi * 196 * r * ct + 0.3 * np.sin(2 * np.pi * 1.5 * ct)) * np.exp(-ct * d) for r, a, d in ((1, 1, 0.5), (2.0, 0.6, 0.8), (2.92, 0.4, 1.2), (4.1, 0.25, 1.8), (0.5, 0.5, 0.4)))
save(x, "temple_bell.wav", 0.7)

# ---------------- ขีดไม้ขีด ----------------
n = int(1.0 * SR)
ct = np.arange(n) / SR
x = hp(R.normal(0, 1, n), 2000) * np.exp(-ct * 12) * (ct < 0.25)
x += bp(R.normal(0, 1, n), 300, 1500) * 0.3 * (ct > 0.15) * np.exp(-(ct - 0.15) * 3)
crack = (R.random(n) > 0.997).astype(float) * R.normal(0, 1, n) * 3
x += hp(crack, 1000)
save(x, "match.wav", 0.7)
n = int(0.6 * SR)
ct = np.arange(n) / SR
save(lp(R.normal(0, 1, n), 900) * np.sin(np.pi * ct / 0.6) ** 2, "candle_out.wav", 0.6)

# ---------------- ชนของ / ไฟฉาย / หน้ากระดาษ ----------------
n = int(0.8 * SR)
x = np.zeros(n)
for k in range(5):
    m = int(0.2 * SR)
    ct = np.arange(m) / SR
    i = int(R.uniform(0, 0.45) * SR)
    fr = R.uniform(400, 1800)
    x[i:i + m] += (np.sin(2 * np.pi * fr * ct) * 0.6 + bp(R.normal(0, 1, m), fr * 0.8, fr * 2)) * np.exp(-ct * R.uniform(20, 40))
x += lp(R.normal(0, 1, n), 250) * np.exp(-np.arange(n) / SR * 20)
save(x, "bump.wav", 0.9)
n = int(0.08 * SR)
ct = np.arange(n) / SR
save(bp(R.normal(0, 1, n), 1500, 6000) * np.exp(-ct * 120) + np.sin(2 * np.pi * 3000 * ct) * np.exp(-ct * 150), "click.wav", 0.6)
n = int(0.5 * SR)
ct = np.arange(n) / SR
save(bp(R.normal(0, 1, n), 1500, 7000) * np.sin(np.pi * ct / 0.5) ** 3 * (1 + 0.5 * np.sin(ct * 90)), "page.wav", 0.5)

# ---------------- สติง: ภาพหลอน / บ้านเปลี่ยน ----------------
L = 2.5
tt = t(L)
x = np.zeros_like(tt)
for f in (1046, 1108, 1174, 1244, 1318):
    x += np.sin(2 * np.pi * f * tt * (1 + 0.003 * np.sin(2 * np.pi * 6 * tt)))
x *= (tt / L) ** 2 * env(len(tt), 0.0, 0.15)
x += hp(R.normal(0, 1, len(tt)), 3000) * (tt / L) ** 3 * 0.8
save(reverb(x, 1.5, 0.3), "sting.wav", 0.6)
L = 5.0
tt = t(L)
x = lp(R.normal(0, 1, len(tt)), 90) * np.exp(-tt * 0.9) * 3
for f in (55, 58.27, 61.7, 82.4, 87.3):
    x += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 0.6) * 0.6
for f in (622, 659, 698):
    x += signal.sawtooth(2 * np.pi * f * tt) * 0.08 * np.exp(-tt * 0.8) * (1 - np.exp(-tt * 8))
save(reverb(np.tanh(x), 2.0, 0.35), "event_boom.wav", 0.95)

# ---------------- เคาะประตู (ภาพหลอนทางเสียง) ----------------
x = np.zeros(int(1.6 * SR))
for at in (0.0, 0.35, 0.7):
    m = int(0.25 * SR)
    ct = np.arange(m) / SR
    i = int(at * SR)
    x[i:i + m] += lp(R.normal(0, 1, m), 400) * np.exp(-ct * 30) + np.sin(2 * np.pi * 110 * ct) * np.exp(-ct * 25)
save(reverb(x, 1.0, 0.4), "knock.wav", 0.8)

# ---------------- เด็กหัวเราะ (เสียงเพี้ยน) ----------------
L = 1.4
tt = t(L)
x = np.zeros_like(tt)
for k in range(5):
    s0 = 0.05 + k * 0.22
    m = int(0.16 * SR)
    ct = np.arange(m) / SR
    f = 520 + 60 * np.sin(k) - 120 * ct / 0.16
    ph = 2 * np.pi * np.cumsum(f) / SR
    syl = (np.sin(ph) + 0.4 * np.sin(2 * ph)) * np.sin(np.pi * ct / 0.16)
    syl = bp(syl + 0.4 * R.normal(0, 1, m) * np.sin(np.pi * ct / 0.16), 400, 3500)
    i = int(s0 * SR)
    x[i:i + m] += syl * (1 - k * 0.12)
save(reverb(x, 1.6, 0.55), "giggle.wav", 0.6)
