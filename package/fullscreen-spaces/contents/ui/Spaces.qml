// Fullscreen Spaces — macOS-style fullscreen for KWin 6.
//
// Two ways into a space, both giving the window its own virtual desktop right
// after the one it came from, removed again when the window leaves or closes:
//  * "macOS mode" (Meta+Ctrl+F or the window menu): the window is maximized over
//    the whole screen with KDE's title bar hidden. The app isn't told it's
//    fullscreen, so it keeps its own UI (browser tabs, toolbars).
//  * App fullscreen (F11, videos, games): real fullscreen.
// Holding the pointer at the top edge slides down a title bar with minimize /
// exit / close, standing in for the hidden KDE title bar.

import QtQuick
import org.kde.kwin

Item {
    id: root

    readonly property string mark: "\u200B" // zero-width suffix that identifies desktops we own
    readonly property int exitDelay: 350 // ms; absorbs games/videos that flicker in and out of fullscreen

    function flag(key, dflt) {
        const v = KWin.readConfig(key, dflt);
        return v === true || v === "true";
    }

    readonly property bool moveNewWindows: flag("MoveNewWindows", true)
    readonly property bool showTitleBar: flag("ShowTitleBar", true)
    readonly property bool titleBarInGames: flag("TitleBarInGames", false)
    readonly property var excluded: String(KWin.readConfig("ExcludedClasses",
        "spectacle,org.kde.spectacle,plasmashell,org.kde.plasmashell,krunner,org.kde.krunner,"
        + "xwaylandvideobridge,org.kde.polkit-kde-authentication-agent-1,polkit-kde-authentication-agent-1"))
        .split(",").map(s => s.trim().toLowerCase()).filter(s => s.length)

    // internalId -> { window, desktop, origin, timer, mac, saved }
    property var spaces: ({})
    property bool busy: false // true while we change windows ourselves
    property var hooks: [] // [window, signal, handler], disconnected when the script is unloaded
    property var loweredPanels: [] // panels we put below windows while a macOS-mode space is showing
    readonly property var bar: barLoader.item

    function log(msg) { console.log("fullscreen-spaces: " + msg); }

    function sameDesktop(a, b) { return !!a && !!b && a.id === b.id; }
    function desktopExists(d) { return !!d && Workspace.desktops.some(x => x.id === d.id); }
    function isOurDesktop(d) { return !!d && d.name.endsWith(mark); }
    function key(w) { return w.internalId.toString(); }
    function allWindows() { return Array.from(Workspace.stackingOrder); }
    function rect(g) { return { x: g.x, y: g.y, width: g.width, height: g.height }; }

    function coversOutput(w) {
        const f = w.frameGeometry, g = w.output.geometry;
        return Math.abs(f.x - g.x) < 1 && Math.abs(f.y - g.y) < 1
            && Math.abs(f.width - g.width) < 1 && Math.abs(f.height - g.height) < 1;
    }

    // True when KDE draws the title bar (as opposed to apps like Chromium that draw their own).
    function hasServerTitleBar(w) {
        return !w.noBorder && w.frameGeometry.height - w.clientGeometry.height > 1;
    }

    function spaceForDesktop(d) {
        for (const id in spaces) {
            if (sameDesktop(spaces[id].desktop, d)) return spaces[id];
        }
        return null;
    }

    function isExcluded(w) {
        const cls = String(w.resourceClass).toLowerCase();
        const name = String(w.resourceName).toLowerCase();
        return excluded.indexOf(cls) !== -1 || excluded.indexOf(name) !== -1;
    }

    function isGame(w) { return String(w.resourceClass).startsWith("steam_app_"); }

    function eligible(w) {
        return w && w.normalWindow && !w.transient && !w.specialWindow
            && !w.onAllDesktops && !w.skipTaskbar && !isExcluded(w);
    }

    function spaceName(w) {
        let name = String(w.resourceClass);
        if (isGame(w) || name.length === 0) {
            name = String(w.caption);
        } else {
            name = name.split(".").pop().split(/[-_ ]+/)
                .map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
        }
        return name + mark;
    }

    // Nearest desktop to the left of `d` that isn't one of ours, else the first desktop.
    function fallbackFor(d) {
        const list = Workspace.desktops;
        let i = list.findIndex(x => x.id === d.id);
        for (i = i - 1; i >= 0; i--) {
            if (!isOurDesktop(list[i])) return list[i];
        }
        return list.find(x => !isOurDesktop(x)) || list[0];
    }

    function makeExitTimer(w) {
        const t = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", root);
        t.interval = exitDelay;
        t.triggered.connect(() => {
            const rec = spaces[key(w)];
            if (rec && !rec.mac && !w.fullScreen) exitSpace(w, false);
        });
        return t;
    }

    // Creates the desktop, moves `w` onto it and switches there.
    function createSpace(w, mac) {
        const from = w.desktops.length === 1 ? w.desktops[0] : Workspace.currentDesktop;
        let origin = from;
        // Going fullscreen from inside another app's space returns to that space's origin.
        const parent = spaceForDesktop(origin);
        if (parent) origin = parent.origin;

        const pos = Workspace.desktops.findIndex(x => x.id === from.id) + 1;
        Workspace.createDesktop(pos, spaceName(w));
        const desktop = Workspace.desktops[pos];
        if (!desktop || !isOurDesktop(desktop)) {
            log("could not create desktop for " + w.resourceClass);
            return null;
        }

        const rec = { window: w, desktop: desktop, origin: origin, timer: makeExitTimer(w), mac: mac, saved: null };
        spaces[key(w)] = rec;
        busy = true;
        w.desktops = [desktop];
        busy = false;
        Workspace.currentDesktop = desktop;
        Workspace.activeWindow = w;
        return rec;
    }

    function enterFullscreenSpace(w) {
        const existing = spaces[key(w)];
        if (existing) {
            // Came back into fullscreen before the exit timer fired: keep the space.
            existing.timer.stop();
            return;
        }
        if (eligible(w)) createSpace(w, false);
    }

    function enterMacSpace(w) {
        if (spaces[key(w)] || !eligible(w) || !w.maximizable) return;
        const saved = {
            noBorder: w.noBorder,
            keepAbove: w.keepAbove,
            maximizeMode: w.maximizeMode,
            geometry: rect(w.frameGeometry),
            titleBar: hasServerTitleBar(w),
        };
        const rec = createSpace(w, true);
        if (!rec) return;
        rec.saved = saved;

        busy = true;
        if (saved.titleBar) w.noBorder = true;
        w.keepAbove = true;
        w.setMaximize(true, true);
        if (!coversOutput(w)) w.frameGeometry = rect(w.output.geometry);
        busy = false;
        updatePanels();
    }

    function restoreMac(w, s) {
        busy = true;
        w.keepAbove = s.keepAbove;
        w.noBorder = s.noBorder;
        w.setMaximize((s.maximizeMode & 1) !== 0, (s.maximizeMode & 2) !== 0);
        if (s.maximizeMode === 0) w.frameGeometry = s.geometry;
        busy = false;
    }

    function exitSpace(w, closing) {
        const rec = spaces[key(w)];
        if (!rec) return;
        rec.timer.stop();
        rec.timer.destroy();
        delete spaces[key(w)];
        if (bar && bar.client === w) bar.dismiss();

        const desktop = rec.desktop;
        const origin = desktopExists(rec.origin) && !sameDesktop(rec.origin, desktop)
            ? rec.origin : fallbackFor(desktop);
        const wasCurrent = sameDesktop(Workspace.currentDesktop, desktop);

        if (!closing && rec.mac) {
            if (w.fullScreen) w.fullScreen = false;
            restoreMac(w, rec.saved);
        }

        busy = true;
        if (!closing && w.desktops.some(d => d.id === desktop.id)) w.desktops = [origin];
        // Anything else left behind (dialogs etc.) goes back with it.
        allWindows().forEach(o => {
            if (o === w || o.onAllDesktops || o.desktops.length !== 1) return;
            if (sameDesktop(o.desktops[0], desktop)) o.desktops = [origin];
        });
        busy = false;

        if (wasCurrent) {
            Workspace.currentDesktop = origin;
            if (!closing && !w.minimized) Workspace.activeWindow = w;
        }
        if (desktopExists(desktop)) Workspace.removeDesktop(desktop);
    }

    // Meta+Ctrl+F, the window menu entry and the title bar's exit button.
    function toggle(w) {
        if (!w) return;
        const rec = spaces[key(w)];
        if (w.fullScreen) {
            w.fullScreen = false; // inside a macOS-mode space this drops back to macOS mode
        } else if (rec && rec.mac) {
            exitSpace(w, false);
        } else if (w.fullScreenable || w.maximizable) {
            enterMacSpace(w);
        }
    }

    function update(w) {
        const rec = spaces[key(w)];
        if (w.minimized) {
            exitSpace(w, false); // minimizing leaves the space; restoring a fullscreen window re-enters it
        } else if (w.fullScreen) {
            enterFullscreenSpace(w);
            updatePanels();
        } else if (rec && !rec.mac) {
            if (bar && bar.client === w) bar.dismiss();
            rec.timer.restart();
        } else if (rec) {
            updatePanels();
        }
    }

    // Window signals outlive this script, so remember each connection to undo it on unload.
    function hook(w, sig, fn) {
        sig.connect(fn);
        hooks.push([w, sig, fn]);
    }

    function watch(w) {
        if (!w || !w.normalWindow) return;
        hook(w, w.fullScreenChanged, () => update(w));
        hook(w, w.minimizedChanged, () => update(w));
        hook(w, w.maximizedChanged, () => {
            if (busy) return;
            const rec = spaces[key(w)];
            // Un-maximized from the app's own button: leave macOS mode, like the green button.
            if (rec && rec.mac && w.maximizeMode !== 3) exitSpace(w, false);
        });
        hook(w, w.desktopsChanged, () => {
            if (busy) return;
            const rec = spaces[key(w)];
            // User dragged the window to another desktop: drop the now-empty space.
            if (rec && !w.desktops.some(d => d.id === rec.desktop.id)) {
                if (rec.mac) restoreMac(w, rec.saved);
                exitSpace(w, true);
            }
        });
    }

    function onAdded(w) {
        watch(w);
        if (!eligible(w)) return;
        if (w.fullScreen) { enterFullscreenSpace(w); return; }

        // Launching an app from a fullscreen desktop opens it on the normal desktop, like macOS.
        if (!moveNewWindows || w.desktops.length !== 1) return;
        const rec = spaceForDesktop(w.desktops[0]);
        if (!rec || rec.window === w) return;
        const origin = desktopExists(rec.origin) ? rec.origin : fallbackFor(rec.desktop);
        busy = true;
        w.desktops = [origin];
        busy = false;
        Workspace.currentDesktop = origin;
        Workspace.activeWindow = w;
    }

    // Recover after a KWin restart or re-login: re-adopt windows still sitting on one
    // of our desktops, and remove any of our desktops that are left over.
    function recover() {
        const windows = allWindows();
        Workspace.desktops.filter(isOurDesktop).forEach(d => {
            const on = windows.filter(w => eligible(w) && !w.minimized
                && w.desktops.length === 1 && sameDesktop(w.desktops[0], d));
            const fs = on.find(w => w.fullScreen);
            const mac = on.find(w => w.keepAbove && w.maximizeMode === 3);
            const owner = fs || mac;
            if (owner) {
                const rec = { window: owner, desktop: d, origin: fallbackFor(d), timer: makeExitTimer(owner), mac: !fs, saved: null };
                if (rec.mac) {
                    rec.saved = { noBorder: false, keepAbove: false, maximizeMode: 3, geometry: rect(owner.frameGeometry), titleBar: owner.noBorder };
                }
                spaces[key(owner)] = rec;
                return;
            }
            const target = fallbackFor(d);
            windows.forEach(o => {
                if (!o.onAllDesktops && o.desktops.length === 1 && sameDesktop(o.desktops[0], d)) o.desktops = [target];
            });
            if (sameDesktop(Workspace.currentDesktop, d)) Workspace.currentDesktop = target;
            Workspace.removeDesktop(d);
        });
    }

    // Panels share the "keep above" layer, so a macOS-mode window can't cover them. While
    // such a space is showing, drop its screen's panels below windows (what Plasma's own
    // "Windows can cover" panel setting does), and put them back when leaving it.
    function updatePanels() {
        const rec = spaceForDesktop(Workspace.currentDesktop);
        const cover = rec && rec.mac && !rec.window.fullScreen
            ? allWindows().filter(p => p.dock && p.output === rec.window.output) : [];
        loweredPanels = loweredPanels.filter(p => {
            if (cover.indexOf(p) !== -1) return true;
            try { p.keepBelow = false; } catch (e) { /* panel already gone */ }
            return false;
        });
        cover.forEach(p => {
            if (!p.keepBelow) {
                p.keepBelow = true;
                loweredPanels.push(p);
            }
        });
    }

    // ---- Title bar on hover --------------------------------------------------

    function barTarget() {
        const w = Workspace.activeWindow;
        if (!showTitleBar || !bar || !w) return null;
        const rec = spaces[key(w)];
        if (!rec) return null;
        if (w.fullScreen) return isGame(w) && !titleBarInGames ? null : w;
        // Apps that draw their own title bar (Chromium, Electron) keep showing their own buttons.
        return rec.mac && rec.saved.titleBar ? w : null;
    }

    function onCursorMoved() {
        if (!bar) return;
        const p = Workspace.cursorPos;
        if (bar.client) {
            const g = bar.client.output.geometry;
            const inside = p.x >= g.x && p.x < g.x + g.width && p.y < g.y + bar.height + Math.round(bar.height / 2);
            if (inside) hideTimer.stop(); else if (!hideTimer.running) hideTimer.start();
            return;
        }
        const w = barTarget();
        if (!w) { revealTimer.stop(); return; }
        const g = w.output.geometry;
        const atTop = p.y <= g.y + 1 && p.x >= g.x && p.x < g.x + g.width;
        if (atTop && !revealTimer.running) revealTimer.start();
        else if (!atTop) revealTimer.stop();
    }

    Timer {
        id: revealTimer
        interval: 150 // brief dwell at the edge, so flicking past the top doesn't trigger it
        onTriggered: {
            const w = root.barTarget();
            if (w && Workspace.cursorPos.y <= w.output.geometry.y + 1) root.bar.reveal(w);
        }
    }

    Timer {
        id: hideTimer
        interval: 400
        onTriggered: if (root.bar) root.bar.dismiss()
    }

    // Loaded with a unique URL so an edited copy takes effect without restarting KWin (see main.qml).
    Loader {
        id: barLoader
        source: Qt.resolvedUrl("TitleBar.qml") + "?" + Date.now()
    }

    Connections {
        target: root.bar
        function onExitRequested(w) { root.toggle(w); }
    }

    Connections {
        target: Workspace
        function onWindowAdded(w) { root.onAdded(w); }
        function onWindowRemoved(w) {
            if (root.bar && root.bar.client === w) root.bar.dismiss();
            if (root.spaces[root.key(w)]) root.exitSpace(w, true);
            root.hooks = root.hooks.filter(h => h[0] !== w);
        }
        function onCursorPosChanged() { root.onCursorMoved(); }
        function onWindowActivated(w) { if (root.bar && root.bar.client && root.bar.client !== w) root.bar.dismiss(); }
        function onCurrentDesktopChanged() {
            if (root.bar && root.bar.client) root.bar.dismiss();
            root.updatePanels();
        }
    }

    ShortcutHandler {
        name: "FullscreenSpacesToggle"
        text: "Fullscreen Spaces: Toggle macOS-style full screen"
        sequence: "Meta+Ctrl+F"
        onActivated: root.toggle(Workspace.activeWindow)
    }

    Component.onCompleted: {
        allWindows().forEach(watch);
        recover();
        updatePanels();
        log("started, " + Object.keys(spaces).length + " full screen space(s) in use");
    }

    Component.onDestruction: {
        hooks.forEach(([w, sig, fn]) => {
            try { sig.disconnect(fn); } catch (e) { /* window already gone */ }
        });
        loweredPanels.forEach(p => {
            try { p.keepBelow = false; } catch (e) { /* panel already gone */ }
        });
    }
}
