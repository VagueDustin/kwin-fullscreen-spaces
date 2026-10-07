#!/usr/bin/env python3
"""mkgif.py REC_DIR OUT.gif WIDTH FPS [captions.json] [pointer.log]

captions.json: [[start_epoch, end_epoch, "text"], ...] drawn as a pill above the panel.
pointer.log:   "epoch x y" lines from the fake-input client. Screenshots are taken without the
               cursor (the headless session only captures it over some apps), so an arrow is
               drawn at the logged position the pointer really was at.
"""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

rec, out, width, fps = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
caps = json.load(open(sys.argv[5])) if len(sys.argv) > 5 and sys.argv[5] != "-" else []
trace = [tuple(map(float, l.split())) for l in open(sys.argv[6])] if len(sys.argv) > 6 else []

ARROW = [(0, 0), (0, 21), (5, 16), (9, 25), (13, 23), (9, 15), (16, 15)]

def pointer_at(now):
    if not trace or now < trace[0][0]:
        return None
    for (t0, x0, y0), (t1, x1, y1) in zip(trace, trace[1:]):
        if t0 <= now < t1:
            return (x0, y0) if t1 - t0 > 0.05 else (x0 + (x1 - x0) * (now - t0) / (t1 - t0), y0 + (y1 - y0) * (now - t0) / (t1 - t0))
    return trace[-1][1:]

def draw_pointer(img, pos):
    d = ImageDraw.Draw(img)
    pts = [(pos[0] + x * 1.15, pos[1] + y * 1.15) for x, y in ARROW]
    d.polygon(pts, fill=(255, 255, 255), outline=(0, 0, 0), width=2)
times = json.load(open(f"{rec}/times.json"))
start = float(open(f"{rec}/start.txt").read())
font = ImageFont.truetype("/usr/share/fonts/noto/NotoSans-Bold.ttf", 30)

tmp = tempfile.mkdtemp()
step, n, t = 1 / fps, 0, 0.0
last = times[-1]
i = 0
while t <= last:
    while i + 1 < len(times) and times[i + 1] <= t:
        i += 1
    img = Image.open(f"{rec}/{i:05d}.png").convert("RGB")
    now = start + t
    pos = pointer_at(now)
    if pos:
        draw_pointer(img, pos)
    for c0, c1, text in caps:
        if c0 <= now <= c1:
            d = ImageDraw.Draw(img, "RGBA")
            w = d.textlength(text, font=font)
            W, H = img.size
            x0, y0 = (W - w) / 2 - 28, H - 150
            # fade in/out over 0.2 s
            a = min(1, (now - c0) / 0.2, (c1 - now) / 0.2)
            d.rounded_rectangle((x0, y0, x0 + w + 56, y0 + 58), radius=29, fill=(20, 24, 33, int(215 * a)))
            d.text((x0 + 28, y0 + 9), text, font=font, fill=(255, 255, 255, int(255 * a)))
    img.resize((width, round(img.height * width / img.width)), Image.LANCZOS).save(f"{tmp}/{n:05d}.png")
    n += 1
    t += step

subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", f"{tmp}/%05d.png",
                "-vf", "split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle",
                "-loop", "0", out], check=True)
subprocess.run(["rm", "-rf", tmp])
print(f"{out}: {n} frames, {os.path.getsize(out) / 1e6:.1f} MB")
