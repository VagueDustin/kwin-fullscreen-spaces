#!/usr/bin/env bash
# Turns Fullscreen Spaces off and removes it. Leave full screen in any apps first,
# otherwise their extra desktops stay behind (remove them in the Overview).
set -euo pipefail

SCRIPTS="fullscreen-spaces fullscreen-spaces-menu"

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

for s in $SCRIPTS; do
    kwriteconfig6 --file kwinrc --group Plugins --key "${s}Enabled" --delete
    kwin_call /Scripting org.kde.kwin.Scripting unloadScript "$s" >/dev/null || true
    kpackagetool6 --type KWin/Script --remove "$s" >/dev/null 2>&1 || true
done

echo "Fullscreen Spaces has been removed."
