#!/bin/bash
# in.sh CMD... — runs a command inside the demo session (its Wayland display, D-Bus and config).
D=$(dirname "$(readlink -f "$0")")
W=$D/.work
. $W/env.sh
exec env -i FI_TRACE=${FI_TRACE:-} HOME=$W/home/h USER=$USER PATH=/usr/bin:/bin LANG=en_US.UTF-8 XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  XDG_CONFIG_HOME=$W/home/config XDG_DATA_HOME=$W/home/data XDG_CACHE_HOME=$W/home/cache XDG_STATE_HOME=$W/home/state \
  XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 QT_QPA_PLATFORM=wayland \
  DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" WAYLAND_DISPLAY=wayland-demo "$@"
