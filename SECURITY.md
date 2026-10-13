# Security

## Reporting a vulnerability

Please report it privately through GitHub rather than in a public issue: on this repository's
**Security** tab, choose **Report a vulnerability** (private vulnerability reporting). The report is
visible only to the maintainer until a fix is published.

Include your Plasma version, Wayland or X11, what you found, and how to reproduce it.

## Supported versions

Only the [latest release](https://github.com/VagueDustin/kwin-fullscreen-spaces/releases/latest)
receives fixes.

## Scope

The scripts run inside KWin with the current user's privileges, and `install.sh` / `uninstall.sh`
only touch the current user's KWin scripts and `kwinrc`. Issues in KWin or Plasma themselves belong
with KDE.
