#!/bin/bash
# Headless, isolated Plasma session for recording demo media.
#   session.sh start   start it (its own KWin, D-Bus, config and home under .work/)
#   session.sh stop    stop it and every app started in it
# Nothing from your real session is visible in it: fresh default settings, empty home.
set -euo pipefail
D=$(dirname "$(readlink -f "$0")")
W=$D/.work

case "${1:-}" in
start)
    mkdir -p $W/home/{config,data,cache,state,h} $W/home/data/dbus-1/services
    # The demo needs no phone pairing; don't let KDE Connect announce a second device on the network.
    printf '[D-BUS Service]\nName=org.kde.kdeconnect\nExec=/bin/false\n' > $W/home/data/dbus-1/services/org.kde.kdeconnect.service
    printf '[Default Applications]\nx-scheme-handler/http=google-chrome.desktop\nx-scheme-handler/https=google-chrome.desktop\ntext/html=google-chrome.desktop\n' > $W/home/config/mimeapps.list
    cat > $W/inner.sh <<'INNER'
#!/bin/bash
W=$(dirname "$(readlink -f "$0")")
echo "export DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS'" > $W/env.sh
plasmashell > $W/plasmashell.log 2>&1 &
sleep infinity
INNER
    chmod +x $W/inner.sh
    setsid env -i HOME=$W/home/h USER=$USER PATH=/usr/bin:/bin LANG=en_US.UTF-8 XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
        XDG_CONFIG_HOME=$W/home/config XDG_DATA_HOME=$W/home/data XDG_CACHE_HOME=$W/home/cache XDG_STATE_HOME=$W/home/state \
        XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 QT_QPA_PLATFORM=wayland \
        KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1 \
        dbus-run-session -- kwin_wayland --virtual --width 1440 --height 900 --no-lockscreen --socket wayland-demo \
        --exit-with-session $W/inner.sh > $W/kwin.log 2>&1 < /dev/null &
    for _ in $(seq 50); do [ -f $W/env.sh ] && break; sleep 0.2; done
    sleep 6 # let Plasma finish starting
    ;;
stop)
    for pid in $(pgrep -u "$USER"); do
        [ "$pid" = $$ ] && continue
        if grep -qzx "XDG_CONFIG_HOME=$W/home/config" /proc/$pid/environ 2>/dev/null; then kill $pid 2>/dev/null || true; fi
    done
    for pid in $(pgrep -x kwin_wayland); do
        tr '\0' ' ' < /proc/$pid/cmdline | grep -q -- '--socket wayland-demo' && kill $pid || true
    done
    rm -f $W/env.sh
    ;;
*)
    echo "usage: $0 start|stop" >&2; exit 1 ;;
esac
