#!/bin/bash
# sc.sh 'Shortcut Name' — presses a KWin global shortcut in the demo session.
D=$(dirname "$(readlink -f "$0")")
$D/in.sh dbus-send --session --print-reply --dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "string:$1" >/dev/null
