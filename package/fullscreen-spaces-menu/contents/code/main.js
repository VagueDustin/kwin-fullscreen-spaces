// Window menu entry for Fullscreen Spaces. QML scripts can't add window menu
// entries, so this presses the main script's Meta+Ctrl+F action for the window.

const MARK = "\u200B"; // suffix Fullscreen Spaces puts on the desktops it owns

registerUserActionsMenu(function (w) {
    if (!w.normalWindow || w.transient || !(w.maximizable || w.fullScreenable)) return null;
    const inSpace = w.desktops.length === 1 && w.desktops[0].name.endsWith(MARK);
    return {
        text: inSpace ? "Exit Full Screen Space" : "Enter Full Screen Space",
        icon: inSpace ? "view-restore" : "view-fullscreen",
        triggered: function () {
            workspace.activeWindow = w;
            callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component",
                     "invokeShortcut", "FullscreenSpacesToggle");
        }
    };
});
