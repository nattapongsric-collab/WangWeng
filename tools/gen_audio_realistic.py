"""เสียงชุดใหม่ (สมจริงขึ้น) — รันหลัง gen_audio.py จะเขียนทับไฟล์เดิมบางไฟล์
python3 tools/gen_audio_realistic.py

- ฝีเท้าเท้าเปล่าบนพื้นไม้สักเก่า: แรงกระแทกส้นเท้า+ปลายเท้า → resonator แบบ modal ของแผ่นไม้
  + เสียงเนื้อเท้าสัมผัสพื้น + ไม้ลั่น (stick-slip) แบบสุ่ม + เสียงสะท้อนห้อง
- ฝีเท้าบนหญ้า: granular (ใบหญ้าหัก) + ดินทุ้ม
- เสียงบรรยากาศ: drone beating, ลมหวีดผ่านช่องไม้, บ้านลั่น, string ตึงเครียด, กระซิบย้อนกลับ
- กลางคืน: จิ้งหรีดหลายตัว, กบ, ตุ๊กแก, หมาหอนไกล ๆ
- ผี: เสียงผู้หญิงฮัมเพลงกล่อมเด็ก (formant synthesis, ทำนองแต่งใหม่) / กล่องดนตรีหมุนช้าลง
- เหตุการณ์สุ่มรอบตัว: ไม้ลั่นชั้นบน, ฝีเท้าชั้นบน, ประตูเอี๊ยดไกล ๆ, กระดิ่งลม, น้ำหยด, ร้องไห้สะอื้น ฯลฯ
"""
import numpy as np
import wave
import os
from scipy import signal

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(2026)


def save(x, name, sr, peak=0.9):
    x = np.asarray(x, float)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(f"wrote {name:24s} {len(x)/sr:5.2f}s @{sr}")


def bp(x, lo, hi, sr, order=2):
    b, a = signal.butter(order, [lo / (sr / 2), min(hi / (sr / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def lp(x, f, sr, order=2):
    b, a = signal.butter(order, min(f / (sr / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, f, sr, order=2):
    b, a = signal.butter(order, f / (sr / 2), "high")
    return signal.lfilter(b, a, x)


def resonator(x, f, t60, sr):
    """bandpass resonator แบบ 2-pole: ความถี่ f, เวลาลดลง 60dB = t60 วินาที"""
    r = 10 ** (-3.0 / (t60 * sr))
    w = 2 * np.pi * f / sr
    return signal.lfilter([1 - r], [1, -2 * r * np.cos(w), r * r], x)


def early_reflections(x, sr, taps=((0.009, 0.32), (0.017, 0.22), (0.026, 0.15), (0.041, 0.09)), tail=0.35, tail_amt=0.12):
    n = len(x)
    out = np.concatenate([x, np.zeros(int((tail + 0.06) * sr))])
    for d, g in taps:
        i = int(d * sr)
        out[i:i + n] += lp(x, 4000, sr) * g
    m = int(tail * sr)
    ir = R.normal(0, 1, m) * np.exp(-np.linspace(0, 6, m))
    ir = lp(ir, 2500, sr)
    wet = signal.fftconvolve(x, ir)[: len(out)]
    out[: len(wet)] += wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(x)) * tail_amt
    return out


def reverb(x, sr, decay=1.8, mix=0.4, damp=3000):
    n = int(decay * sr)
    ir = R.normal(0, 1, n) * np.exp(-np.linspace(0, 7, n))
    ir = lp(ir, damp, sr)
    wet = signal.fftconvolve(x, ir)
    out = np.zeros(len(x) + n)
    out[: len(x)] += x * (1 - mix)
    wet = wet[: len(out)]
    out[: len(wet)] += wet / (np.max(np.abs(wet)) + 1e-9) * (np.max(np.abs(x)) + 1e-9) * mix
    return out


def loopify(x, sr, fade=1.0):
    n = int(fade * sr)
    head, tail = x[:n].copy(), x[-n:].copy()
    ramp = np.sin(np.linspace(0, np.pi / 2, n)) ** 2
    y = x[:-n].copy()
    y[:n] = head * ramp + tail * (1 - ramp)
    return y


def creak(dur, sr, f0=110, f1=170, jitter=0.06, bright=1.0):
    """ไม้ลั่นแบบ stick-slip: แรงกระตุกเป็นจังหวะ → ผ่าน mode ของไม้"""
    n = int(dur * sr)
    x = np.zeros(n)
    t = 0.0
    while t < dur:
        frac = t / dur
        f = f0 + (f1 - f0) * (0.5 - 0.5 * np.cos(np.pi * frac)) + R.normal(0, 4)
        i = int(t * sr)
        if i < n:
            x[i] += R.uniform(0.6, 1.0) * np.sin(np.pi * frac) ** 0.5
        t += (1.0 / max(f, 30)) * (1 + R.normal(0, jitter))
    y = np.zeros(n)
    for fm, t60, g in ((420, 0.05, 1.0), (690, 0.04, 0.8), (1150, 0.03, 0.6 * bright), (1720, 0.025, 0.4 * bright), (2600, 0.02, 0.25 * bright)):
        y += resonator(x, fm * R.uniform(0.94, 1.06), t60, sr) * g
    y += lp(x, 300, sr) * 0.3
    env = np.minimum(1, np.linspace(0, 8, n)) * np.minimum(1, np.linspace(6, 0, n))
    return y * env


# =====================================================================
SR = 44100


def wood_step(sr, weight=1.0, creak_p=0.3, floor2=False):
    dur = 0.6
    n = int(dur * sr)
    exc = np.zeros(n)
    # ส้นเท้า: พัลส์ครึ่งโคไซน์ 4-7ms
    def pulse(at, width, amp):
        w = int(width * sr)
        i = int(at * sr)
        exc[i:i + w] += amp * np.sin(np.linspace(0, np.pi, w)) ** 2
    heel_w = R.uniform(0.004, 0.007) / max(weight, 0.6)
    pulse(0.0, heel_w, 1.0 * weight)
    toe_t = R.uniform(0.07, 0.11) / (1.0 + 0.3 * (weight - 1))
    pulse(toe_t, R.uniform(0.006, 0.01), R.uniform(0.35, 0.55) * weight)
    exc += R.normal(0, 0.02, n) * np.exp(-np.linspace(0, 40, n))
    # mode ของแผ่นไม้ (แต่ละก้าวต่างกันเล็กน้อย)
    modes = [(72, 0.16, 1.0), (128, 0.12, 0.8), (205, 0.09, 0.7), (318, 0.07, 0.55), (476, 0.05, 0.45),
             (705, 0.035, 0.35), (1040, 0.025, 0.25), (1580, 0.018, 0.15), (2350, 0.012, 0.08)]
    y = np.zeros(n)
    for f, t60, g in modes:
        y += resonator(exc, f * R.uniform(0.92, 1.08), t60 * R.uniform(0.8, 1.2), sr) * g
    if floor2:  # พื้นยกสูง (ชั้นบน) เสียงก้องโพรงใต้พื้น
        y += resonator(exc, R.uniform(55, 65), 0.22, sr) * 1.2
    # เนื้อเท้าสัมผัสพื้น (เบามาก) + เสียงเสียดสีตอนเหยียบหนัก
    skin = bp(R.normal(0, 1, n), 700, 3200, sr) * np.exp(-np.linspace(0, 60, n)) * 0.05
    y += skin * weight
    scuff_t = int(toe_t * sr)
    sc = bp(R.normal(0, 1, n), 1500, 6000, sr) * 0.03 * weight
    sc[:scuff_t] = 0
    sc[scuff_t:] *= np.exp(-np.linspace(0, 30, n - scuff_t))
    y += sc
    y = y / (np.max(np.abs(y)) + 1e-9)
    if R.random() < creak_p:
        cd = R.uniform(0.18, 0.4)
        c = creak(cd, sr, R.uniform(80, 120), R.uniform(130, 220))
        st = int(R.uniform(0.02, 0.09) * sr)
        y[st:st + len(c)] += c / (np.max(np.abs(c)) + 1e-9) * R.uniform(0.18, 0.35)
    y *= np.minimum(1.0, np.linspace(30, 0, n))  # ตัดหาง
    return early_reflections(y, sr)


for k in range(6):
    save(wood_step(SR, 1.0, 0.3, k % 2 == 1), f"step_wood_{k+1}.wav", SR, 0.85)
for k in range(4):
    save(wood_step(SR, 1.6, 0.5, k % 2 == 1), f"step_wood_run_{k+1}.wav", SR, 0.95)


def grass_step(sr, weight=1.0):
    dur = 0.4
    n = int(dur * sr)
    y = np.zeros(n)
    # ใบหญ้าหัก (grains)
    for _ in range(int(R.uniform(35, 60) * weight)):
        t = abs(R.normal(0.06, 0.06))
        i = int(t * sr)
        g = int(R.uniform(0.0008, 0.003) * sr)
        if i + g < n:
            y[i:i + g] += R.normal(0, 1, g) * np.hanning(g) * R.uniform(0.2, 1.0)
    y = bp(y, 1800, 9000, sr)
    rustle = bp(R.normal(0, 1, n), 2500, 8000, sr) * np.exp(-np.linspace(0, 7, n)) * 0.25
    toe = int(R.uniform(0.08, 0.12) * sr)
    rustle[toe:] += bp(R.normal(0, 1, n - toe), 3000, 9000, sr) * np.exp(-np.linspace(0, 10, n - toe)) * 0.18
    thud = resonator(np.r_[np.hanning(int(0.008 * sr)), np.zeros(n - int(0.008 * sr))], 85, 0.06, sr) * 0.5
    out = y + rustle + thud * weight
    return out * np.minimum(1.0, np.linspace(25, 0, n))


for k in range(5):
    save(grass_step(SR, 1.0), f"step_grass_{k+1}.wav", SR, 0.7)

# =====================================================================
SA = 22050  # บรรยากาศ

# ---------------- บรรยากาศในบ้าน (48 วินาที วนได้)
L = 48.0
n = int(L * SA)
t = np.arange(n) / SA
x = np.zeros(n)
for f, a in ((55.0, 0.5), (55.6, 0.5), (82.4, 0.25), (83.15, 0.25), (41.2, 0.35)):
    x += a * np.sin(2 * np.pi * f * t + R.random() * 6) * (0.75 + 0.25 * np.sin(2 * np.pi * t / L * R.integers(1, 4)))
x += lp(R.normal(0, 1, n), 45, SA) * 1.5  # rumble
x *= 0.5
# ลมหวีดผ่านช่องไม้: noise ผ่าน resonator ที่ความถี่กวาดช้า ๆ
wind = np.zeros(n)
noise = R.normal(0, 1, n)
seg = int(0.05 * SA)
fc = 450 + 250 * np.sin(2 * np.pi * t / L * 3) + 120 * np.sin(2 * np.pi * t / L * 7 + 1)
zi = None
w_out = np.zeros(n)
for i in range(0, n, seg):
    f = fc[i]
    r = 0.9985
    w = 2 * np.pi * f / SA
    b, a = [1 - r], [1, -2 * r * np.cos(w), r * r]
    if zi is None:
        zi = signal.lfilter_zi(b, a) * 0
    w_out[i:i + seg], zi = signal.lfilter(b, a, noise[i:i + seg], zi=zi)
gust = (0.5 + 0.5 * np.sin(2 * np.pi * t / L * 4 - 1)) ** 3
x += w_out / (np.max(np.abs(w_out)) + 1e-9) * 0.35 * gust
x += bp(R.normal(0, 1, n), 150, 600, SA) * 0.08 * gust
# string ตึงเครียด (ค่อย ๆ มา ค่อย ๆ ไป)
pad = np.zeros(n)
for f in (311.1, 329.6, 466.2):
    pad += signal.sawtooth(2 * np.pi * f * t * (1 + 0.002 * np.sin(2 * np.pi * 0.3 * t + f)))
pad = lp(pad, 1400, SA) * (np.clip(np.sin(2 * np.pi * t / L * 2 - 0.5), 0, 1) ** 3) * 0.05
x += pad
# บ้านลั่น
for at in (5.5, 13.0, 21.4, 29.8, 38.2, 44.0):
    c = creak(R.uniform(0.4, 1.1), SA, R.uniform(60, 100), R.uniform(110, 190), bright=0.6)
    c = lp(c, 1800, SA) / (np.max(np.abs(c)) + 1e-9) * R.uniform(0.12, 0.22)
    i = int(at * SA)
    x[i:i + len(c)] += c[: n - i]
# ตึงไกล ๆ
i = int(17.3 * SA)
m = int(0.6 * SA)
x[i:i + m] += lp(R.normal(0, 1, m), 90, SA) * np.exp(-np.linspace(0, 8, m)) * 0.8
# กระซิบย้อนกลับ (swell)
m = int(2.5 * SA)
wh = bp(R.normal(0, 1, m), 900, 3500, SA) * (np.abs(np.sin(np.linspace(0, 22, m))) ** 4)
wh = wh * np.linspace(0, 1, m) ** 2
i = int(33.0 * SA)
x[i:i + m] += wh * 0.12
x = reverb(x, SA, 2.2, 0.35, 2000)[:n]
save(loopify(x, SA, 2.0), "amb_house.wav", SA, 0.6)

# ---------------- กลางคืนในสวน (40 วินาที)
L = 40.0
n = int(L * SA)
t = np.arange(n) / SA
x = bp(R.normal(0, 1, n), 200, 1200, SA) * 0.06 * (0.6 + 0.4 * np.sin(2 * np.pi * t / L * 3))  # ลมผ่านใบไม้
leaves = hp(R.normal(0, 1, n), 3000, SA) * (lp(np.abs(R.normal(0, 1, n)), 2, SA) * 8) * 0.05
x += leaves
for k in range(5):  # จิ้งหรีด
    cf = R.uniform(4200, 5600)
    period = R.uniform(0.45, 0.8)
    amp = R.uniform(0.02, 0.06)
    start = R.uniform(0, period)
    pos = start
    while pos < L - 0.2:
        for pl in range(int(R.integers(2, 5))):
            i = int((pos + pl * 0.035) * SA)
            m = int(0.022 * SA)
            if i + m < n:
                x[i:i + m] += np.sin(2 * np.pi * cf * np.arange(m) / SA) * np.hanning(m) * amp
        pos += period * R.uniform(0.92, 1.08)
for k in range(3):  # กบ
    at = R.uniform(2, L - 3)
    for rep in range(int(R.integers(2, 5))):
        m = int(0.18 * SA)
        tt = np.arange(m) / SA
        pulses = (np.sin(2 * np.pi * 28 * tt) > 0.6).astype(float)
        cro = bp(pulses * signal.sawtooth(2 * np.pi * 180 * tt), 300, 1200, SA) * np.hanning(m)
        i = int((at + rep * 0.45) * SA)
        if i + m < n:
            x[i:i + m] += cro * 0.12
gi = int(14.0 * SA)  # ตุ๊กแก
for k in range(5):
    for j, (f, dur) in enumerate(((640, 0.11), (420, 0.24))):
        m = int(dur * SA)
        tt = np.arange(m) / SA
        v = signal.sawtooth(2 * np.pi * f * tt + 2 * np.sin(2 * np.pi * 40 * tt)) * np.sin(np.pi * tt / dur) ** 0.6
        v = bp(v, 300, 2500, SA)
        i = gi + int(k * 0.8 * SA) + int(j * 0.16 * SA)
        x[i:i + m] += 0.18 * v
# หมาหอนไกล ๆ
m = int(3.5 * SA)
tt = np.arange(m) / SA
f = 520 + 160 * np.sin(np.pi * tt / 3.5) - 80 * tt / 3.5
ph = 2 * np.pi * np.cumsum(f * (1 + 0.01 * np.sin(2 * np.pi * 5 * tt))) / SA
howl = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * np.sin(np.pi * tt / 3.5) ** 1.5
howl = lp(howl, 1500, SA)
howl = reverb(howl, SA, 2.5, 0.6, 1500)
i = int(27.0 * SA)
x[i:i + len(howl)] += howl[: n - i] * 0.07
save(loopify(x, SA, 1.5), "amb_night.wav", SA, 0.5)

# =====================================================================
# ผู้หญิงฮัมเพลงกล่อมเด็ก (ทำนองแต่งใหม่ บันไดเสียงไมเนอร์)
def hum_voice(notes, sr, base_amp=1.0, detune_cents=0.0):
    """notes = [(midi or None, beats)], beat = 0.62s"""
    beat = 0.62
    total = sum(b for _, b in notes) * beat + 0.5
    n = int(total * sr)
    f0 = np.zeros(n)
    amp = np.zeros(n)
    pos = 0
    prev = None
    for midi, beats in notes:
        m = int(beats * beat * sr)
        if midi is None:
            pos += m
            prev = None
            continue
        f = 440 * 2 ** ((midi - 69 + detune_cents / 100) / 12)
        seg = np.full(m, f)
        if prev:  # portamento
            g = min(int(0.09 * sr), m)
            seg[:g] = np.geomspace(prev, f, g)
        f0[pos:pos + m] = seg
        e = np.ones(m)
        a = int(0.06 * sr)
        d = int(0.12 * sr)
        e[:a] = np.linspace(0, 1, a)
        e[-d:] = np.linspace(1, 0.55, d)
        amp[pos:pos + m] = np.maximum(amp[pos:pos + m], e)
        pos += m
        prev = f
    tt = np.arange(n) / sr
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.2 * tt + 0.5 * np.sin(2 * np.pi * 0.3 * tt))
    jit = 1 + lp(R.normal(0, 0.004, n), 20, sr)
    f0s = np.where(f0 > 0, f0, 220) * vib * jit
    ph = np.cumsum(2 * np.pi * f0s / sr)
    src = signal.sawtooth(ph) * 0.7 + np.sin(ph) * 0.6
    src = lp(src, 1800, sr)
    v = resonator(src, 270, 0.03, sr) * 2.5 + resonator(src, 2100, 0.008, sr) * 0.4 + lp(src, 600, sr) * 0.6
    breath = bp(R.normal(0, 1, n), 1500, 5000, sr) * 0.05
    amp_s = lp(amp, 18, sr)
    return (v + breath) * amp_s * base_amp


MEL = [(64, 1.5), (62, 0.5), (60, 1), (57, 1), (None, 0.5), (60, 1), (62, 1), (64, 2), (None, 0.5),
       (67, 1), (64, 1), (62, 1.5), (60, 0.5), (62, 1), (57, 2.5), (None, 1.0)]
MEL2 = [(64, 1.5), (62, 0.5), (60, 1), (57, 1), (None, 0.5), (55, 1), (57, 1), (60, 1.5), (59, 0.5), (57, 3), (None, 1.0)]
SV = 22050
a = hum_voice(MEL, SV)
b = hum_voice(MEL2, SV, 0.9, -35)  # วรรคที่สองเพี้ยนต่ำลงนิดหนึ่ง
song = np.concatenate([a, b])
song = reverb(song, SV, 2.4, 0.45, 2500)
save(loopify(song, SV, 0.8), "ghost_lullaby.wav", SV, 0.8)

# กล่องดนตรีหมุนช้าลง
def music_box(notes, sr):
    out = np.zeros(int(14 * sr))
    pos = 0.3
    beat = 0.36
    for k, (midi, beats) in enumerate(notes * 2):
        slow = 1 + 0.06 * k  # ลานใกล้หมด
        if midi is not None:
            f = 440 * 2 ** ((midi + 12 - 69) / 12) * (1 - 0.0015 * k)
            m = int(1.6 * sr)
            tt = np.arange(m) / sr
            tone = (np.sin(2 * np.pi * f * tt) * np.exp(-tt * 2.5) + 0.35 * np.sin(2 * np.pi * f * 3.0 * tt) * np.exp(-tt * 6)
                    + 0.15 * np.sin(2 * np.pi * f * 5.4 * tt) * np.exp(-tt * 12))
            click = hp(R.normal(0, 1, int(0.004 * sr)), 3000, sr) * 0.3
            tone[: len(click)] += click
            i = int(pos * sr)
            if i + m < len(out):
                out[i:i + m] += tone
        pos += beats * beat * slow
        if pos > 13:
            break
    return reverb(out, sr, 2.0, 0.4, 5000)


save(music_box(MEL, SV), "music_box.wav", SV, 0.6)

# =====================================================================
# เหตุการณ์สุ่มรอบตัว
SE = 22050
for k in range(3):
    c = creak(R.uniform(0.7, 1.4), SE, R.uniform(55, 80), R.uniform(100, 170), 0.08, 0.7)
    save(reverb(lp(c, 2200, SE), SE, 1.2, 0.3), f"amb_creak_{k+1}.wav", SE, 0.8)

# ฝีเท้าบนชั้นบน (อู้อี้)
seq = np.zeros(int(3.6 * SE))
for i in range(5):
    s = wood_step(SE, 1.3, 0.4, True)
    s = lp(s, 500, SE)
    st = int((0.2 + i * R.uniform(0.55, 0.65)) * SE)
    seq[st:st + len(s)] += s[: len(seq) - st] * (1 - i * 0.08)
save(reverb(seq, SE, 1.0, 0.25), "amb_steps_upstairs.wav", SE, 0.8)

# ประตูเอี๊ยดไกล ๆ
c = creak(1.8, SE, 140, 320, 0.04, 1.2)
save(reverb(lp(c, 3000, SE), SE, 1.6, 0.45), "amb_door_creak.wav", SE, 0.7)

# กระดิ่งลม
n = int(5 * SE)
x = np.zeros(n)
for k in range(9):
    at = R.uniform(0, 3.2)
    f = R.choice([1480, 1660, 1864, 2217, 2489])
    m = int(1.8 * SE)
    tt = np.arange(m) / SE
    tone = sum(g * np.sin(2 * np.pi * f * r * tt) * np.exp(-tt * d) for r, g, d in ((1, 1, 2.5), (2.76, 0.4, 5), (5.4, 0.2, 9)))
    i = int(at * SE)
    x[i:i + m] += tone[: n - i] * R.uniform(0.3, 1.0)
save(reverb(x, SE, 1.5, 0.35, 6000), "amb_chime.wav", SE, 0.55)

# น้ำหยด
n = int(3.0 * SE)
x = np.zeros(n)
for k, at in enumerate((0.1, 0.9, 1.75, 2.5)):
    m = int(0.08 * SE)
    tt = np.arange(m) / SE
    f = np.linspace(900, 1900, m) * R.uniform(0.9, 1.1)
    d = np.sin(2 * np.pi * np.cumsum(f) / SE) * np.exp(-tt * 60)
    i = int(at * SE)
    x[i:i + m] += d
save(reverb(x, SE, 1.4, 0.5, 4000), "amb_drip.wav", SE, 0.6)

# ร้องไห้สะอื้น (เสียงผู้หญิง)
n = int(4.5 * SE)
x = np.zeros(n)
pos = 0.2
while pos < 3.8:
    dur = R.uniform(0.25, 0.6)
    m = int(dur * SE)
    tt = np.arange(m) / SE
    f = R.uniform(380, 480) * np.linspace(1.0, 0.82, m) * (1 + 0.03 * np.sin(2 * np.pi * 9 * tt))
    ph = np.cumsum(2 * np.pi * f / SE)
    v = signal.sawtooth(ph)
    v = resonator(v, 700, 0.02, SE) + resonator(v, 1200, 0.015, SE) * 0.6 + resonator(v, 2700, 0.008, SE) * 0.3
    v += bp(R.normal(0, 1, m), 1200, 5000, SE) * 0.5
    v *= np.sin(np.pi * tt / dur) ** 1.5
    i = int(pos * SE)
    x[i:i + m] += v
    pos += dur + R.uniform(0.1, 0.5)
    if R.random() < 0.35:  # สูดหายใจ
        m2 = int(0.35 * SE)
        i2 = int(pos * SE)
        if i2 + m2 < n:
            x[i2:i2 + m2] += bp(R.normal(0, 1, m2), 1500, 5000, SE) * np.hanning(m2) * 0.6
        pos += 0.4
save(reverb(x, SE, 2.0, 0.5, 3000), "amb_sob.wav", SE, 0.55)

# ตึงหนัก ๆ ไกล ๆ
n = int(2.5 * SE)
tt = np.arange(n) / SE
x = lp(R.normal(0, 1, n), 120, SE) * np.exp(-tt * 7) * 2 + np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 5)
save(reverb(x, SE, 1.8, 0.4, 1200), "amb_thud.wav", SE, 0.85)

# เสียงหายใจรดต้นคอ
n = int(2.2 * SE)
tt = np.arange(n) / SE
x = bp(R.normal(0, 1, n), 300, 2500, SE) * (np.sin(np.pi * tt / 2.2) ** 3) * (1 + 0.5 * lp(R.normal(0, 1, n), 6, SE))
save(x, "amb_breath_close.wav", SE, 0.6)
