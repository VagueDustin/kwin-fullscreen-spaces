#!/bin/bash
# kjs.sh 'js code' — runs a one-off KWin script inside the demo session and prints what it print()s.
D=$(dirname "$(readlink -f "$0")")
W=$D/.work
pid=$(for p in $(pgrep -x kwin_wayland); do tr '\0' ' ' < /proc/$p/cmdline | grep -q -- '--socket wayland-demo' && echo $p; done)
since=$(date +%s.%N)
n=kjs$RANDOM; f=$W/$n.js; echo "$1" > $f
id=$($D/in.sh dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript string:$f string:$n | grep -oE 'int32 [0-9]+' | awk '{print $2}')
$D/in.sh dbus-send --session --print-reply --dest=org.kde.KWin /Scripting/Script$id org.kde.kwin.Script.run >/dev/null 2>&1
sleep 0.4
$D/in.sh dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript string:$n >/dev/null
rm -f $f
journalctl --user _PID=$pid --since "@$since" -o cat | grep -v StackingOrder || true
