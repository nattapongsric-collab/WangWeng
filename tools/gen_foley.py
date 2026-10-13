"""สร้างเสียงเดิน/เปิด-ปิดประตูให้ธรรมชาติขึ้น (สังเคราะห์แบบ physical-ish: แรงกระแทก + เรโซแนนซ์ของไม้)
ใช้: python gen_foley.py <โฟลเดอร์ assets/audio>"""
import sys, os, wave
import numpy as np
from scipy.signal import butter, sosfilt, lfilter

OUT = sys.argv[1]


def save(name, x, sr, peak):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    # เฟดท้ายสั้น ๆ กันคลิก
    k = min(len(x) // 10, int(0.01 * sr))
    x[-k:] *= np.linspace(1, 0, k)
    w = wave.open(os.path.join(OUT, name + '.wav'), 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    w.close()
    print('%-18s %.2fs peak %.2f rms %.3f' % (name, len(x) / sr, np.max(np.abs(x)), np.sqrt(np.mean(x ** 2))))


def band(x, lo, hi, sr, order=2):
    sos = butter(order, [lo, hi], btype='band', fs=sr, output='sos')
    return sosfilt(sos, x)


def lowp(x, hi, sr, order=2):
    return sosfilt(butter(order, hi, btype='low', fs=sr, output='sos'), x)


def mode(x, f, T, sr):
    """เรโซเนเตอร์ 2 โพล ความถี่ f เวลาสลาย T วินาที (ไม้ที่ถูกกระแทก)"""
    r = np.exp(-1.0 / (T * sr))
    w = 2 * np.pi * f / sr
    return lfilter([1.0 - r], [1.0, -2 * r * np.cos(w), r * r], x)


def impulse(n, at, width, rng, sr, lo=250, hi=3500, amp=1.0):
    """แรงกระแทกสั้น ๆ (ฮาร์ดเนส = แบนด์วิดท์)"""
    x = np.zeros(n)
    k = max(int(width * sr), 8)
    burst = band(rng.standard_normal(k + 64), lo, hi, sr)[32:32 + k] * np.hanning(k)
    i = int(at * sr)
    x[i:i + k] += burst * amp
    return x


def wood_hit(n, at, rng, sr, amp=1.0, f_scale=1.0, hard=1.0):
    imp = impulse(n, at, 0.006 / hard, rng, sr, 200, 2600 * hard + 400, amp)
    fs = [rng.uniform(92, 125), rng.uniform(180, 235), rng.uniform(330, 430), rng.uniform(640, 840), rng.uniform(1000, 1250), rng.uniform(1700, 2200)]
    Ts = [0.07, 0.05, 0.034, 0.022, 0.014, 0.01]
    As = [0.5, 0.7, 0.85, 0.8, 0.6, 0.4]
    y = np.zeros(n)
    for f, T, a in zip(fs, Ts, As):
        y += mode(imp, f * f_scale, T, sr) * a * 8
    # แรงกระแทกต่ำ (ส้นเท้ากระแทกคานพื้น)
    t = np.arange(n) / sr - at
    thump = np.where(t >= 0, np.sin(2 * np.pi * (58 + 40 * np.exp(-t * 90)) * t) * np.exp(-np.maximum(t, 0) / 0.028), 0) * 0.3 * amp
    return y + thump


def step_wood(seed, run=False, sr=44100):
    rng = np.random.default_rng(seed)
    n = int(0.5 * sr)
    heel = wood_hit(n, 0.012, rng, sr, 1.0, rng.uniform(0.92, 1.1), 1.0 if not run else 1.25)
    gap = (0.032 if run else 0.05) + rng.uniform(-0.006, 0.008)
    toe = wood_hit(n, 0.012 + gap, rng, sr, 0.3 if not run else 0.45, rng.uniform(1.05, 1.25), 1.15)
    x = heel + toe
    # เสียงเสียดสีของรองเท้า/เสื้อผ้า
    t = np.arange(n) / sr
    scuff = band(rng.standard_normal(n), 900, 4200, sr) * np.sin(np.clip(t / 0.16, 0, 1) * np.pi) ** 2 * (0.07 if not run else 0.11)
    x = x + scuff
    # ไม้กระดานลั่นแผ่ว ๆ บางก้าว
    if not run and rng.random() < 0.3:
        f0 = rng.uniform(170, 230)
        ct = np.clip((t - 0.05) / 0.22, 0, 1)
        ph = np.cumsum(2 * np.pi * (f0 + 70 * ct) / sr)
        cr = band(np.sign(np.sin(ph)) * 0.5 + rng.standard_normal(n) * 0.2, 300, 1400, sr) * np.sin(ct * np.pi) ** 1.5 * 0.1
        x = x + cr
    x = lowp(x, 9000, sr)
    x *= np.exp(-t / 0.22)  # ท้ายเสียงจางเร็ว ไม่ลากยาว
    return x


def step_grass(seed, sr=44100):
    rng = np.random.default_rng(seed)
    n = int(0.42 * sr)
    t = np.arange(n) / sr
    x = np.zeros(n)
    for at, amp in [(0.01, 1.0), (0.085 + rng.uniform(-0.01, 0.015), 0.55)]:
        e = np.where(t >= at, (1 - np.exp(-(t - at) / 0.012)) * np.exp(-(t - at) / 0.075), 0)
        x += band(rng.standard_normal(n), 700, 5200, sr) * e * amp
    # เสียงใบหญ้าหักเป็นแกรก ๆ
    clicks = np.zeros(n)
    for _ in range(rng.integers(10, 18)):
        at = rng.uniform(0.01, 0.2)
        i = int(at * sr)
        k = int(0.004 * sr)
        clicks[i:i + k] += rng.standard_normal(k) * np.hanning(k) * rng.uniform(0.2, 0.6)
    x += lowp(clicks, 3800, sr) * 0.35
    # แรงกดบนดินนุ่ม ๆ
    x += np.sin(2 * np.pi * 75 * t) * np.exp(-t / 0.04) * 0.2
    return lowp(x, 8500, sr)


def hinge_creak(n, start, dur, rng, sr, f_lo=85, f_hi=135, amp=1.0, slip_rate=22.0):
    """ประตูลั่น: ฟันเลื่อย (stick-slip) ผ่านเรโซแนนซ์ของบานพับ"""
    t = np.arange(n) / sr
    u = np.clip((t - start) / dur, 0, 1)
    f0 = f_lo + (f_hi - f_lo) * np.sin(u * np.pi * 0.9) + 6 * np.sin(2 * np.pi * 3.1 * t)
    ph = np.cumsum(2 * np.pi * f0 / sr)
    saw = (ph / (2 * np.pi)) % 1.0 * 2 - 1
    # จังหวะติดๆ ขัดๆ ไม่สม่ำเสมอ
    rate = slip_rate * (1 + 0.35 * np.sin(2 * np.pi * 1.7 * t + rng.uniform(0, 6))) * (0.6 + 0.8 * u)
    slip = (0.5 + 0.5 * np.sin(np.cumsum(2 * np.pi * rate / sr))) ** 2
    env = np.sin(u * np.pi) ** 0.8 * ((t >= start) & (t <= start + dur))
    src = saw * slip + rng.standard_normal(n) * 0.12
    y = np.zeros(n)
    for f, T, a in [(rng.uniform(480, 560), 0.02, 1.0), (rng.uniform(930, 1050), 0.014, 0.7), (rng.uniform(1550, 1750), 0.01, 0.4)]:
        y += mode(src, f, T, sr) * a * 6
    return y * env * amp


def latch(n, at, rng, sr, amp=1.0):
    x = impulse(n, at, 0.0015, rng, sr, 1500, 6000, amp)
    y = mode(x, 2100, 0.006, sr) * 5 + mode(x, 3300, 0.004, sr) * 3
    return y


def door_open(seed, sr=22050, long=False):
    rng = np.random.default_rng(seed)
    dur = 2.6 if long else 1.9
    n = int(dur * sr)
    x = latch(n, 0.03, rng, sr, 1.0) + latch(n, 0.075, rng, sr, 0.6)
    x += wood_hit(n, 0.085, rng, sr, 0.35, 1.0, 0.8)
    cdur = (1.7 if long else 1.15)
    x += hinge_creak(n, 0.16, cdur, rng, sr, 80, 130, 0.9, 20.0 if not long else 14.0)
    # บานประตูหยุดชนวงกบเบา ๆ
    x += wood_hit(n, 0.16 + cdur + 0.03, rng, sr, 0.3, 0.9, 0.7)
    return lowp(x, 7500, sr)


def door_close(seed, sr=22050):
    rng = np.random.default_rng(seed)
    n = int(1.3 * sr)
    t = np.arange(n) / sr
    whoosh = lowp(rng.standard_normal(n), 900, sr) * np.sin(np.clip(t / 0.5, 0, 1) * np.pi) ** 2 * 0.22
    x = whoosh + hinge_creak(n, 0.05, 0.5, rng, sr, 95, 120, 0.45, 24.0)
    hit = 0.58
    x += wood_hit(n, hit, rng, sr, 1.0, 0.85, 0.8)
    x += latch(n, hit + 0.012, rng, sr, 0.8) + latch(n, hit + 0.085, rng, sr, 0.45)
    x += wood_hit(n, hit + 0.16, rng, sr, 0.18, 1.0, 0.8)  # บานกระเด้งเบา ๆ
    return lowp(x, 7500, sr)


def door_locked(seed, sr=22050):
    rng = np.random.default_rng(seed)
    n = int(0.9 * sr)
    x = np.zeros(n)
    for at, a in [(0.02, 1.0), (0.17, 0.85), (0.3, 0.6)]:
        h = impulse(n, at, 0.004, rng, sr, 400, 5000, a)
        x += mode(h, 1400 + rng.uniform(-80, 80), 0.03, sr) * 4 + mode(h, 2600, 0.02, sr) * 3 + mode(h, 190, 0.05, sr) * 5
    x += hinge_creak(n, 0.35, 0.25, rng, sr, 100, 120, 0.12, 30.0)
    return lowp(x, 7000, sr)


for i in range(6):
    save('step_wood_%d' % (i + 1), step_wood(100 + i), 44100, 0.8)
for i in range(4):
    save('step_wood_run_%d' % (i + 1), step_wood(200 + i, True), 44100, 0.9)
for i in range(5):
    save('step_grass_%d' % (i + 1), step_grass(300 + i), 44100, 0.65)
save('door_open', door_open(7), 22050, 0.7)
save('door_close', door_close(9), 22050, 0.8)
save('door_locked', door_locked(11), 22050, 0.7)
if os.path.exists(os.path.join(OUT, 'amb_door_creak.wav')):
    save('amb_door_creak', door_open(21, long=True), 22050, 0.55)
