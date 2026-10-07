// KWin keeps compiled QML cached by URL for the whole session, so an edited script
// would otherwise only take effect after logging out. Loading the real script with a
// unique URL each time makes reinstalling (or disable + enable) pick up changes.
import QtQuick

Loader {
    // Set once rather than bound, so the script is only ever created once.
    Component.onCompleted: source = Qt.resolvedUrl("Spaces.qml") + "?" + Date.now()
}
