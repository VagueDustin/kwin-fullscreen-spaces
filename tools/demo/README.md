# Demo media tooling

`record.sh` re-creates every GIF and screenshot in `docs/media/`:

```bash
tools/demo/record.sh
```

It runs everything inside a **headless, isolated Plasma session**, so nothing from your own desktop ends up in the images:

- `session.sh` starts `kwin_wayland --virtual` with its own D-Bus session, plus Plasma with fresh default settings and an empty home folder under `.work/`.
- The demo content is three local pages (`site/`, served on `127.0.0.1`) in a throwaway Chrome profile, and a stock KDE wallpaper in Gwenview.
- `install.sh` from this repo is run inside that session, so the recording also exercises the installer.
- Keys are pressed through KWin's global shortcut D-Bus API (`sc.sh`). The pointer is moved by `fake-input/fi.c`, a tiny `org_kde_kwin_fake_input` client.
- Frames are captured with KWin's `ScreenShot2` D-Bus API (`grab.py`) and turned into GIFs with ffmpeg (`mkgif.py`).
- Screenshots leave out the cursor because the headless session only captures it over some apps. `mkgif.py` draws an arrow at the position the input client logged, which is where the pointer really was.
- The key captions are added by `mkgif.py`. The three-finger swipe can't be performed headlessly, so the recording uses its keyboard equivalent (Ctrl+Meta+Left/Right), which plays the same animation.

Needs `kwin_wayland`, `plasmashell`, `google-chrome-stable`, `gwenview`, `ffmpeg`, `gcc`, `wayland-scanner`, and Python with `dbus-python` and Pillow.
