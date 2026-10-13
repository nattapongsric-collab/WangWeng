"""สร้าง texture แบบ procedural สำหรับเกม วังเวง (รันด้วย python3 tools/gen_textures.py)
ทุกภาพ tile ต่อกันได้ (seamless) ใช้กับ triplanar mapping ใน Godot
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
N = 512


def tile_noise(size, cells, seed):
    """value noise ที่ต่อขอบกันได้ (periodic)"""
    r = np.random.default_rng(seed)
    g = r.random((cells, cells))
    xs = np.linspace(0, cells, size, endpoint=False)
    x0 = np.floor(xs).astype(int)
    t = xs - x0
    t = t * t * (3 - 2 * t)
    x1 = (x0 + 1) % cells
    a = g[x0][:, x0]
    b = g[x0][:, x1]
    c = g[x1][:, x0]
    d = g[x1][:, x1]
    ty = t[:, None]
    tx = t[None, :]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(size, base=4, octaves=5, seed=0):
    out = np.zeros((size, size))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += tile_noise(size, base * 2 ** o, seed + o * 31) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def save(arr, name):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(OUT, name))
    print("wrote", name)


def colorize(v, c0, c1):
    c0 = np.array(c0, float)
    c1 = np.array(c1, float)
    return c0 + (c1 - c0) * v[..., None]


# ---------- พื้นไม้สัก (planks) ----------
def wood_planks(name, base_dark, base_light, plank_h=64, vertical=False, seed=1):
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:N, 0:N]
    grain_n = fbm(N, 2, 4, seed)
    img = np.zeros((N, N, 3))
    rows = N // plank_h
    for i in range(rows):
        y0 = i * plank_h
        shift = r.integers(0, N)
        tone = r.uniform(-0.12, 0.12)
        band = slice(y0, y0 + plank_h)
        x = (xx[band] + shift) % N
        y = yy[band] - y0
        # เสี้ยนไม้: sin ตามแกน x บิดด้วย noise
        g = np.sin((y * 0.35 + grain_n[band] * 18 + np.sin(x / N * 2 * np.pi * 2) * 3)) * 0.5 + 0.5
        g = g ** 2
        knots = fbm(N, 8, 3, seed + i)[band]
        v = 0.55 + 0.25 * g + 0.2 * (knots - 0.5) + tone
        col = colorize(np.clip(v, 0, 1), base_dark, base_light)
        # ร่องระหว่างแผ่น
        col[:2] *= 0.35
        col[-1:] *= 0.55
        # รอยต่อปลายไม้
        joint = (r.integers(0, N))
        col[:, max(0, joint - 1):joint + 1] *= 0.4
        img[band] = col
    dirt = fbm(N, 3, 5, seed + 99)
    img *= (0.75 + 0.35 * dirt)[..., None]
    if vertical:
        img = np.transpose(img, (1, 0, 2))
    save(img, name)


wood_planks("wood_floor.png", (52, 30, 18), (130, 82, 48), 64, False, 3)
wood_planks("wood_wall.png", (45, 28, 18), (112, 72, 44), 64, True, 11)
wood_planks("wood_dark.png", (30, 17, 10), (88, 52, 30), 128, False, 21)
wood_planks("ceiling.png", (70, 58, 45), (140, 120, 95), 128, False, 41)

# ---------- ผนังปูนเก่า ----------
n1 = fbm(N, 4, 6, 50)
n2 = fbm(N, 8, 4, 60)
base = colorize(n1, (120, 122, 105), (190, 186, 160))
# คราบน้ำไหลแนวตั้ง
drip = fbm(N, 16, 3, 70)
streak = np.repeat(drip[0:1, :], N, axis=0)
streak = (streak > 0.62).astype(float) * np.linspace(1, 0.2, N)[:, None]
streak = np.array(Image.fromarray((streak * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))) / 255.0
base *= (1 - 0.35 * streak)[..., None]
mold = np.clip((n2 - 0.6) * 4, 0, 1)
base = base * (1 - mold[..., None] * 0.5) + np.array([40, 55, 35]) * mold[..., None] * 0.5
# รอยร้าว
crack = Image.new("L", (N, N), 0)
d = ImageDraw.Draw(crack)
r = np.random.default_rng(5)
for _ in range(7):
    x, y = r.integers(0, N, 2)
    for _ in range(40):
        nx, ny = x + r.integers(-9, 10), y + r.integers(2, 12)
        if 0 <= nx < N and 0 <= ny < N:
            d.line([(x, y), (nx, ny)], fill=255, width=1)
        x, y = nx % N, ny % N
crack = np.array(crack) / 255.0
base *= (1 - 0.6 * crack)[..., None]
save(base, "plaster_wall.png")

# ---------- กระเบื้องครัว ----------
tile = 64
yy, xx = np.mgrid[0:N, 0:N]
checker = ((xx // tile + yy // tile) % 2).astype(float)
n = fbm(N, 8, 5, 80)
col = np.where(checker[..., None] > 0.5, np.array([150, 145, 130]), np.array([70, 75, 72])).astype(float)
col *= (0.75 + 0.4 * n)[..., None]
grout = ((xx % tile) < 2) | ((yy % tile) < 2)
col[grout] = [40, 38, 32]
dirt = fbm(N, 4, 5, 81)
col *= (0.7 + 0.4 * dirt)[..., None]
save(col, "tile_floor.png")

# ---------- ผ้า (โซฟา/ที่นอน) ----------
n = fbm(N, 16, 4, 90)
weave = (np.sin(xx * 0.9) * np.sin(yy * 0.9)) * 0.08
pattern = ((np.sin(xx / N * 2 * np.pi * 8) * np.sin(yy / N * 2 * np.pi * 8)) > 0.6).astype(float)
col = colorize(np.clip(0.5 + weave + 0.3 * (n - 0.5), 0, 1), (60, 30, 30), (130, 70, 60))
col = col * (1 - 0.25 * pattern[..., None]) + np.array([160, 130, 70]) * 0.25 * pattern[..., None]
save(col, "fabric.png")

# ผ้าขาว (ผ้าปูที่นอน/ผ้าคลุม)
col = colorize(np.clip(0.6 + weave + 0.4 * (n - 0.5), 0, 1), (120, 118, 110), (200, 196, 185))
save(col * (0.8 + 0.3 * fbm(N, 4, 4, 91))[..., None], "cloth_white.png")

# ---------- หญ้า / ดิน ----------
n = fbm(N, 8, 6, 100)
blades = fbm(N, 64, 2, 101)
col = colorize(np.clip(0.3 + 0.5 * n + 0.3 * (blades - 0.5), 0, 1), (18, 32, 14), (60, 85, 35))
save(col, "grass.png")
n = fbm(N, 6, 6, 110)
col = colorize(n, (38, 28, 20), (95, 75, 55))
pebbles = (fbm(N, 48, 2, 111) > 0.72)
col[pebbles] *= 1.3
save(col, "dirt.png")

# ---------- อิฐ (รั้ว/บ่อน้ำ) ----------
bh, bw = 32, 64
col = np.zeros((N, N, 3))
n = fbm(N, 16, 4, 120)
for row in range(N // bh):
    off = (bw // 2) * (row % 2)
    for c in range(-1, N // bw + 1):
        x0 = c * bw + off
        tone = rng.uniform(0.7, 1.1)
        xs = slice(max(0, x0), min(N, x0 + bw))
        col[row * bh:(row + 1) * bh, xs] = np.array([110, 60, 45]) * tone
col *= (0.7 + 0.5 * n)[..., None]
mort = ((yy % bh) < 3) | (((xx + (bw // 2) * ((yy // bh) % 2)) % bw) < 3)
col[mort] = [85, 82, 75]
moss = np.clip((fbm(N, 6, 5, 121) - 0.55) * 3, 0, 1)
col = col * (1 - moss[..., None] * 0.6) + np.array([35, 55, 25]) * moss[..., None] * 0.6
save(col, "brick.png")

# ---------- กระดาษเก่า (UI จดหมาย) ----------
n = fbm(N, 4, 6, 130)
col = colorize(n, (175, 150, 105), (230, 212, 170))
edge = np.minimum(np.minimum(xx, N - 1 - xx), np.minimum(yy, N - 1 - yy)) / 60.0
col *= np.clip(0.55 + edge, 0, 1)[..., None]
spots = np.clip((fbm(N, 12, 3, 131) - 0.68) * 5, 0, 1)
col *= (1 - 0.35 * spots)[..., None]
save(col, "paper.png")

# ---------- รูปถ่ายครอบครัวเก่า (ปริศนา) ----------
W, H = 512, 360
img = Image.new("RGB", (W, H), (120, 100, 70))
d = ImageDraw.Draw(img)
# พื้นหลัง = ตัวบ้าน
d.rectangle([0, 0, W, H], fill=(140, 118, 88))
d.polygon([(60, 140), (256, 30), (452, 140)], fill=(90, 72, 52))
d.rectangle([90, 140, 422, 300], fill=(110, 90, 65))
for wx in (130, 330):
    d.rectangle([wx, 170, wx + 50, 230], fill=(50, 40, 30))
# คน 4 คน: ยาย, แม่, เด็ก (ข้าวฟ่าง), และผู้หญิงชุดขาวด้านหลัง
people = [(150, 0.95, (60, 48, 38)), (240, 1.0, (70, 55, 42)), (320, 0.6, (75, 60, 45))]
for px, s, c in people:
    hh = int(150 * s)
    top = H - 30 - hh
    d.ellipse([px - 18 * s, top, px + 18 * s, top + 36 * s], fill=(170, 145, 115))
    d.rectangle([px - 28 * s, top + 34 * s, px + 28 * s, H - 30], fill=c)
# ผู้หญิงชุดขาวยืนหลังสุด ใบหน้าถูกขูด
gx = 400
d.rectangle([gx - 26, 120, gx + 26, H - 30], fill=(215, 210, 195))
d.ellipse([gx - 18, 80, gx + 18, 120], fill=(200, 195, 185))
d.rectangle([gx - 22, 70, gx + 22, 175], fill=(20, 18, 16))  # ผมยาว
for i in range(26):
    x = gx - 20 + rng.integers(0, 40)
    d.line([(x, 82 + rng.integers(0, 10)), (x + rng.integers(-8, 8), 118)], fill=(235, 230, 220), width=2)
arr = np.array(img).astype(float)
gray = arr.mean(axis=2, keepdims=True)
sep = np.concatenate([gray * 1.07, gray * 0.9, gray * 0.66], axis=2)
grain = np.random.default_rng(3).normal(0, 10, (H, W, 1))
yy2, xx2 = np.mgrid[0:H, 0:W]
vig = 1 - 0.55 * (((xx2 - W / 2) / (W / 2)) ** 2 + ((yy2 - H / 2) / (H / 2)) ** 2)
sep = (sep + grain) * np.clip(vig, 0.25, 1)[..., None]
Image.fromarray(np.clip(sep, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "family_photo.png"))
print("wrote family_photo.png")

# ---------- ยันต์ / สัญญา (ผ้ายันต์) ----------
img = Image.new("RGB", (256, 256), (180, 40, 30))
d = ImageDraw.Draw(img)
d.rectangle([12, 12, 244, 244], outline=(230, 200, 120), width=4)
d.rectangle([40, 40, 216, 216], outline=(230, 200, 120), width=2)
d.line([(40, 40), (216, 216)], fill=(230, 200, 120), width=2)
d.line([(216, 40), (40, 216)], fill=(230, 200, 120), width=2)
d.ellipse([98, 98, 158, 158], outline=(230, 200, 120), width=3)
arr = np.array(img).astype(float) * (0.7 + 0.4 * fbm(256, 4, 4, 140)[..., None])
Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "yant_cloth.png"))
print("wrote yant_cloth.png")

# ---------- ภาพวาดเด็ก ----------
img = Image.new("RGB", (256, 256), (225, 215, 190))
d = ImageDraw.Draw(img)
d.polygon([(40, 120), (128, 50), (216, 120)], outline=(120, 60, 30), width=3)
d.rectangle([60, 120, 196, 220], outline=(120, 60, 30), width=3)
for (x, c) in ((90, (40, 40, 160)), (130, (200, 60, 120))):
    d.ellipse([x - 10, 150, x + 10, 170], outline=c, width=2)
    d.line([(x, 170), (x, 205)], fill=c, width=2)
d.ellipse([168, 140, 188, 160], outline=(20, 20, 20), width=2)
d.line([(178, 160), (178, 215)], fill=(150, 150, 150), width=6)
d.line([(170, 145), (165, 200)], fill=(10, 10, 10), width=3)
d.line([(186, 145), (191, 200)], fill=(10, 10, 10), width=3)
img.save(os.path.join(OUT, "kid_drawing.png"))
print("wrote kid_drawing.png")
