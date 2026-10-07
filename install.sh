#!/usr/bin/env bash
# Installs (or updates) Fullscreen Spaces for the current user and turns it on.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

SCRIPTS="fullscreen-spaces fullscreen-spaces-menu"
DIR=${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts

for tool in kpackagetool6 kwriteconfig6; do
    command -v "$tool" >/dev/null || { echo "error: $tool not found. Fullscreen Spaces needs KDE Plasma 6." >&2; exit 1; }
done
command -v dbus-send >/dev/null || command -v busctl >/dev/null \
    || { echo "error: needs dbus-send or busctl to talk to KWin." >&2; exit 1; }

# kwin_call PATH INTERFACE METHOD [STRING ARGS...]
kwin_call() {
    local path=$1 iface=$2 method=$3
    shift 3
    if command -v dbus-send >/dev/null; then
        dbus-send --session --print-reply --dest=org.kde.KWin "$path" "$iface.$method" "${@/#/string:}"
    else
        busctl --user call org.kde.KWin "$path" "$iface" "$method" ${1:+"$(printf 's%.0s' "$@")"} "$@"
    fi
}

loaded() { [[ $(kwin_call /Scripting org.kde.kwin.Scripting isScriptLoaded "$1") == *true* ]]; }
all_loaded() { for s in $SCRIPTS; do loaded "$s" || return 1; done; }
none_loaded() { for s in $SCRIPTS; do loaded "$s" && return 1; done; return 0; }

# KWin applies config changes on its own schedule, so nudge it until it reports the state we want.
wait_until() {
    for _ in 1 2 3; do
        kwin_call /KWin org.kde.KWin reconfigure >/dev/null
        sleep 1
        kwin_call /Scripting org.kde.kwin.Scripting start >/dev/null
        "$@" && return 0
    done
    return 1
}

# Right after a first install KWin may not have noticed the new packages yet; load them directly.
# From the next login on, KWin loads them by itself. (Scripting.start runs every loaded script
# that isn't running yet. Script object paths get reused, so they can't be relied on.)
load_now() {
    loaded fullscreen-spaces || kwin_call /Scripting org.kde.kwin.Scripting loadDeclarativeScript \
        "$DIR/fullscreen-spaces/contents/ui/main.qml" fullscreen-spaces >/dev/null
    loaded fullscreen-spaces-menu || kwin_call /Scripting org.kde.kwin.Scripting loadScript \
        "$DIR/fullscreen-spaces-menu/contents/code/main.js" fullscreen-spaces-menu >/dev/null
    kwin_call /Scripting org.kde.kwin.Scripting start >/dev/null
}

set_enabled() {
    for s in $SCRIPTS; do
        kwriteconfig6 --file kwinrc --group Plugins --key "${s}Enabled" "$1"
    done
}

for s in $SCRIPTS; do
    if kpackagetool6 --type KWin/Script --show "$s" >/dev/null 2>&1; then
        kpackagetool6 --type KWin/Script --upgrade "package/$s"
    else
        kpackagetool6 --type KWin/Script --install "package/$s"
    fi
done

# Turning the scripts off and on again makes a running KWin load the new version.
if ! none_loaded; then
    set_enabled false
    if ! wait_until none_loaded; then
        for s in $SCRIPTS; do kwin_call /Scripting org.kde.kwin.Scripting unloadScript "$s" >/dev/null; done
    fi
fi
set_enabled true
wait_until all_loaded || load_now

if ! all_loaded; then
    echo "Installed, but KWin didn't start it. Log out and back in to turn it on." >&2
    exit 1
fi

echo "Fullscreen Spaces is installed and on."
echo "  Meta+Ctrl+F, or right-click a title bar → Extensions → Enter Full Screen Space"
echo "  Settings: System Settings → Window Management → KWin Scripts"
