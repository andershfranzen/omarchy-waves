import QtQuick
import Quickshell
import Quickshell.Io
import "Palette.js" as Palette

// The wallpaper as a self-contained backdrop for another surface (the lock
// screen): it reads the shared settings file itself. The host passes in the
// theme's colours.
Item {
  id: backdrop

  property color accent: "#82fb9c"
  property color base: "#0b0c16"
  property bool running: true
  property real fade: 250
  // True once the settings are in and the picture can be shown.
  property bool ready: false
  property var conf: ({})

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/waves.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var parsed = null
      try { parsed = JSON.parse(text()) } catch (e) { parsed = null }
      backdrop.conf = Palette.clean(parsed)
      backdrop.ready = true
    }
    onLoadFailed: backdrop.ready = true
  }

  WaveScene {
    anchors.fill: parent
    visible: backdrop.ready
    conf: backdrop.conf
    accent: backdrop.accent
    base: backdrop.base
    running: backdrop.running && backdrop.visible
    fade: backdrop.fade
  }
}
