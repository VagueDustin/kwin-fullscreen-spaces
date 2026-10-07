# Changelog

## 1.0.0 — 2026-10-06

First release.

- Full screen apps get their own virtual desktop, placed next to the one they came from and named after the app.
- macOS-style full screen (Meta+Ctrl+F or the window menu): the window fills the screen and covers the panel while the app keeps its own UI.
- Real full screen (F11, video, games) also gets its own desktop.
- Title bar slides down when the pointer touches the top edge.
- Desktops are removed when the app leaves full screen, is minimized or closes.
- Apps launched from a full screen desktop open on the normal desktop.
- Recovers open spaces and removes leftover desktops after a KWin restart.
