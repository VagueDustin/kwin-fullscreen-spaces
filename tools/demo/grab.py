#!/usr/bin/env python3
"""Captures the demo session through KWin's ScreenShot2 D-Bus API.

  grab.py shot OUT.png            one screenshot
  grab.py record DIR SECONDS [FPS] frames + timestamps into DIR (for gif making)
"""
import os, sys, time, json
import dbus
from PIL import Image

bus = dbus.SessionBus()
shot = dbus.Interface(bus.get_object("org.kde.KWin", "/org/kde/KWin/ScreenShot2"), "org.kde.KWin.ScreenShot2")

def capture():
    r, w = os.pipe()
    # Cursor left out: it is only captured over some apps; mkgif.py draws it from the input log.
    meta = shot.CaptureWorkspace({"include-cursor": False, "native-resolution": True}, dbus.types.UnixFd(w))
    os.close(w)
    chunks = []
    while True:
        b = os.read(r, 1 << 20)
        if not b:
            break
        chunks.append(b)
    os.close(r)
    data = b"".join(chunks)
    width, height, stride, fmt = int(meta["width"]), int(meta["height"]), int(meta["stride"]), int(meta["format"])
    mode = {4: "BGRX", 5: "BGRA", 6: "BGRA", 17: "RGBX", 18: "RGBA", 19: "RGBA"}.get(fmt, "BGRA")
    return Image.frombuffer("RGBA", (width, height), data, "raw", mode, stride, 1).convert("RGB")

if sys.argv[1] == "shot":
    capture().save(sys.argv[2])
elif sys.argv[1] == "record":
    import threading, queue
    out, secs = sys.argv[2], float(sys.argv[3])
    fps = float(sys.argv[4]) if len(sys.argv) > 4 else 30
    os.makedirs(out, exist_ok=True)
    q = queue.Queue()
    def writer():
        while (item := q.get()) is not None:
            i, img = item
            img.save(f"{out}/{i:05d}.png", compress_level=1)
    th = threading.Thread(target=writer); th.start()
    times, start = [], time.monotonic()
    open(f"{out}/start.txt", "w").write(repr(time.time()))
    while (t := time.monotonic() - start) < secs:
        q.put((len(times), capture()))
        times.append(t)
        nxt = start + len(times) / fps
        if nxt > time.monotonic():
            time.sleep(nxt - time.monotonic())
    q.put(None); th.join()
    json.dump(times, open(f"{out}/times.json", "w"))
    print(f"{len(times)} frames, {len(times)/secs:.1f} fps")
