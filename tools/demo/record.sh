#!/bin/bash
# Records every GIF and screenshot in docs/media/ inside a headless, isolated Plasma session.
# Needs: kwin_wayland, plasmashell, google-chrome-stable, gwenview, ffmpeg, gcc, wayland-scanner,
# python3 with dbus-python and Pillow.
set -euo pipefail
D=$(dirname "$(readlink -f "$0")")
W=$D/.work
REPO=$(readlink -f "$D/../..")
OUT=$REPO/docs/media
mkdir -p $W $OUT

# Fake-input client: moves the demo session's pointer and presses its buttons.
(cd $W && wayland-scanner client-header $D/fake-input/fake-input.xml fake-input.h \
    && wayland-scanner private-code $D/fake-input/fake-input.xml fake-input.c \
    && gcc -O2 -I. -o fi $D/fake-input/fi.c fake-input.c $(pkg-config --cflags --libs wayland-client))
FI() { $D/in.sh $W/fi; }

cleanup() {
    [ -n "${SITE_PID:-}" ] && kill $SITE_PID 2>/dev/null || true
    $D/session.sh stop
}
trap cleanup EXIT
trap "exit 1" INT TERM

rm -rf "${W:?}"/home
$D/session.sh start
$D/in.sh $REPO/install.sh

# Demo content: local pages (so the address bar shows only 127.0.0.1) and a stock KDE wallpaper.
python3 -m http.server 8765 --bind 127.0.0.1 --directory $D/site >/dev/null 2>&1 &
SITE_PID=$!
chrome() {
    setsid $D/in.sh google-chrome-stable --user-data-dir=$W/home/chrome --no-first-run --no-default-browser-check \
        --disable-sync --password-store=basic --ozone-platform=wayland --window-size=1060,680 \
        http://127.0.0.1:8765/trail.html http://127.0.0.1:8765/packing.html http://127.0.0.1:8765/weather.html \
        >/dev/null 2>&1 < /dev/null &
    sleep 5
    $D/kjs.sh 'workspace.windowList().forEach(w => { if (w.resourceClass == "google-chrome") { w.frameGeometry = {x: 470, y: 190, width: 880, height: 600}; workspace.activeWindow = w; } });' >/dev/null
}
setsid $D/in.sh gwenview /usr/share/wallpapers/Next/contents/images_dark/5120x2880.png >/dev/null 2>&1 < /dev/null &
sleep 4
$D/kjs.sh 'workspace.windowList().forEach(w => { if (w.resourceClass == "org.kde.gwenview") w.frameGeometry = {x: 90, y: 70, width: 760, height: 560}; });' >/dev/null
chrome
activate() { $D/kjs.sh "workspace.windowList().forEach(w => { if (w.resourceClass == '$1') workspace.activeWindow = w; });" >/dev/null; sleep 0.5; }
record() { rm -rf "${W:?}/rec-$1" $W/captions.json $W/pointer.log; touch $W/pointer.log; $D/in.sh python3 $D/grab.py record $W/rec-$1 $2 30 & REC_PID=$!; }
gif() { wait $REC_PID; python3 $D/mkgif.py $W/rec-$1 $OUT/$1.gif 960 24 $W/captions.json $W/pointer.log; }
export FI_TRACE=$W/pointer.log

# 1. hero: a browser enters its own space and keeps its tabs; swipe away and back; leave.
activate google-chrome
record hero 11.5; sleep 1.3
$D/act.sh 2.0 "Meta + Ctrl + F" $D/sc.sh FullscreenSpacesToggle; sleep 2.6
$D/act.sh 1.6 "Three-finger swipe  ·  Ctrl + Meta + Left" $D/sc.sh "Switch One Desktop to the Left"; sleep 2.2
$D/act.sh 1.6 "Three-finger swipe  ·  Ctrl + Meta + Right" $D/sc.sh "Switch One Desktop to the Right"; sleep 2.2
$D/act.sh 2.0 "Meta + Ctrl + F again to leave" $D/sc.sh FullscreenSpacesToggle
gif hero

# 2. title bar: an app with a KDE title bar; push the pointer to the top; exit from the bar.
activate org.kde.gwenview
echo "abs 980 560" | FI
record titlebar 10; sleep 0.9
$D/act.sh 1.6 "Meta + Ctrl + F" $D/sc.sh FullscreenSpacesToggle; sleep 1.7
$D/act.sh 2.0 "Push the pointer against the top edge" bash -c "echo 'move 980 560 760 0 600' | $D/in.sh $W/fi"; sleep 1.5
echo "move 760 1 1387 17 800" | FI; sleep 0.7
$D/act.sh 1.6 "Exit Full Screen" bash -c "printf 'btn 272 1\nsleep 90\nbtn 272 0\n' | $D/in.sh $W/fi"; sleep 0.6
echo "move 1387 17 1060 470 700" | FI
gif titlebar

# 3. Overview: each full screen app is a named desktop next to the one it came from.
activate google-chrome; $D/sc.sh FullscreenSpacesToggle; sleep 1.2
$D/sc.sh "Switch One Desktop to the Left"; sleep 1
activate org.kde.gwenview; $D/sc.sh FullscreenSpacesToggle; sleep 1.2
echo "abs 1300 600" | FI
$D/sc.sh Overview; sleep 1.5
$D/in.sh python3 $D/grab.py shot $OUT/overview.png
$D/sc.sh Overview; sleep 0.8
$D/sc.sh FullscreenSpacesToggle; sleep 1.2 # Gwenview leaves its space

# 4. Window menu: right-click a title bar → Extensions → Enter Full Screen Space.
$D/sc.sh "Switch One Desktop to the Right"; sleep 1
activate google-chrome; $D/sc.sh FullscreenSpacesToggle; sleep 1.2 # Chrome leaves its space
activate org.kde.gwenview
: > $W/pointer.log
printf 'move 1100 600 520 84 400\nsleep 200\nbtn 273 1\nsleep 60\nbtn 273 0\nsleep 500\nmove 520 84 610 223 300\nsleep 800\n' | FI
$D/in.sh python3 $D/grab.py shot $W/menu.png
python3 - $W/menu.png $W/pointer.log $OUT/window-menu.png <<'PY'
import sys
from PIL import Image, ImageDraw
img = Image.open(sys.argv[1]).convert("RGB")
x, y = map(float, open(sys.argv[2]).read().split("\n")[-2].split()[1:])
arrow = [(0, 0), (0, 21), (5, 16), (9, 25), (13, 23), (9, 15), (16, 15)]
ImageDraw.Draw(img).polygon([(x + a * 1.15, y + b * 1.15) for a, b in arrow], fill="white", outline="black", width=2)
img.crop((60, 40, 1010, 660)).save(sys.argv[3])
PY
echo "key 1 1" | FI; echo "key 1 0" | FI; sleep 0.5 # Esc closes the menu

# 5. Closing a full screen app removes its desktop.
activate google-chrome; $D/sc.sh FullscreenSpacesToggle; sleep 1.5
echo "abs 1000 520" | FI
record close 6.5; sleep 0.8
$D/act.sh 1.8 "Close the app" bash -c "printf 'move 1000 520 1422 20 800\nsleep 350\nbtn 272 1\nsleep 70\nbtn 272 0\n' | $D/in.sh $W/fi"; sleep 0.5
$D/act.sh 2.2 "…and its desktop goes away" true; sleep 0.8
echo "move 1422 20 1180 470 700" | FI
gif close

ls -la $OUT
