# AGENTS.md

Guidance for coding agents working in this repository. The README's Development section is the
source for most of this.

## What this is

Fullscreen Spaces is a pair of KWin scripts for KDE Plasma 6 that give full screen windows their own
virtual desktop, macOS style: a desktop created next to the one the app came from, a hover title bar,
and cleanup when the app leaves full screen, minimizes or closes. Tested on Plasma 6.7 (Wayland);
X11 is untested. No build system, no dependencies.

## Layout

```
package/fullscreen-spaces/          main script (declarative QML)
  metadata.json                     KPlugin metadata, including Version
  contents/ui/main.qml              stub that loads Spaces.qml under a fresh URL
  contents/ui/Spaces.qml            all the logic
  contents/ui/TitleBar.qml          the hover title bar
  contents/config/main.xml          settings schema
  contents/ui/config.ui             settings dialog
package/fullscreen-spaces-menu/     window-menu entry (JavaScript; QML scripts can't add one)
install.sh / uninstall.sh           per-user install/update/remove via kpackagetool6 + D-Bus
build.sh                            builds .kwinscript archives into dist/
tools/demo/                         records docs/media in a headless, isolated Plasma session
```

## Commands

```bash
./install.sh     # install or update both scripts for the current user and (re)load them in KWin
./uninstall.sh   # turn them off and remove them
./build.sh       # dist/fullscreen-spaces-<version>.kwinscript and dist/fullscreen-spaces-menu-<version>.kwinscript
journalctl --user -f | grep -i fullscreen-spaces   # watch the logs
tools/demo/record.sh   # re-record docs/media (needs kwin_wayland, plasmashell, Chrome, gwenview, ffmpeg, gcc, ...)
```

`install.sh` needs `kpackagetool6`, `kwriteconfig6` and `dbus-send` or `busctl`; `build.sh` needs
`python3`. There is no automated test suite: verify changes by running `./install.sh` in a Plasma 6
session and exercising full screen (Meta+Ctrl+F, F11, the window menu, closing and minimizing).
`install.sh` and `uninstall.sh` change the live KWin configuration, so don't run them on a machine
whose desktop you weren't asked to change.

## Things to know

- KWin caches compiled QML per file name for the whole session. That is why `main.qml` only loads
  `Spaces.qml` under a fresh URL; put logic in `Spaces.qml` / `TitleBar.qml`. Changes to `main.qml`
  itself need a logout to take effect.
- The script tags desktops it creates with an invisible character in their name and only ever
  removes desktops carrying that tag. Keep that invariant: never remove a user's own desktops.
- Anything the script changes (panel layering, window decoration, keep-above) must be restored when
  the window leaves full screen or the desktop is switched away from.
- Script object paths on KWin's D-Bus are reused, so don't rely on them; `install.sh` uses
  `Scripting.start` / `isScriptLoaded` by script name.
- The version lives in both `package/*/metadata.json` files and must match; `build.sh` reads it from
  the main package. Add user-visible changes to `CHANGELOG.md`. Don't bump the version unless asked.
- `tools/demo` recordings must contain demo content only, never anything from a real desktop.
- `dist/` and `tools/demo/.work/` are build and scratch output (gitignored); don't commit them.

## Commit style

Short imperative subjects ("Start freshly loaded scripts with Scripting.start").
