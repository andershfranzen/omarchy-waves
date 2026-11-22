import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Palette.js" as Palette

// Live shader wallpaper. Sits on the bottom layer, above the shell's still
// background and below every window, and lets clicks through.
//
// Settings live in ~/.config/omarchy/waves.json (see Palette.js for the keys
// and their defaults); the bar menu writes the same file.
Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsPath: home + "/.config/omarchy/waves.json"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"
  // A still of the current look, for wherever a plain image is wanted.
  readonly property string stillPath: home + "/.local/share/omarchy-waves/still.png"

  property var conf: ({})
  property bool loaded: false
  property string theme: ""
  function value(key) { return Palette.value(conf, key) }

  function set(key, v) {
    var next = ({})
    for (var k in conf) next[k] = conf[k]
    next[key] = v
    conf = Palette.clean(next)
    rememberForTheme()
    saveTimer.restart()
  }

  // With "remember per theme" on, each theme keeps its own look: store the
  // current one under the current theme whenever it changes.
  function rememberForTheme() {
    if (!value("perTheme") || !theme) return false
    var current = Palette.look(conf)
    var themes = value("themes")
    if (JSON.stringify(themes[theme]) === JSON.stringify(current)) return false
    var nextThemes = ({})
    for (var name in themes) nextThemes[name] = themes[name]
    nextThemes[theme] = current
    var next = ({})
    for (var k in conf) next[k] = conf[k]
    next.themes = nextThemes
    conf = next
    return true
  }

  // A theme change brings back the look remembered for that theme, if any.
  function applyTheme(name) {
    var previous = theme
    theme = name
    if (!loaded || !value("perTheme") || !name) return
    var stored = value("themes")[name]
    if (previous && previous !== name && stored && typeof stored === "object") {
      var next = ({})
      for (var k in conf) next[k] = conf[k]
      for (var i = 0; i < Palette.lookKeys.length; i++) {
        var key = Palette.lookKeys[i]
        if (stored[key] !== undefined) next[key] = stored[key]
      }
      conf = Palette.clean(next)
      saveTimer.restart()
    } else if (rememberForTheme()) {
      saveTimer.restart()
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    atomicWrites: true
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var parsed = null
      try { parsed = JSON.parse(text()) } catch (e) { parsed = null }
      root.conf = Palette.clean(parsed)
      root.loaded = true
      if (root.rememberForTheme()) saveTimer.restart()
    }
    onLoadFailed: root.loaded = true
  }

  FileView {
    path: root.themeNamePath
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.applyTheme(String(text()).trim())
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: settingsFile.setText(JSON.stringify(root.conf, null, 2) + "\n")
  }

  // omarchy-shell waves setColor theme|#rrggbb, setColor2 auto|#rrggbb,
  // setStyle silk|bands|threads|aurora|saturn, setBlack true|false,
  // setParticles true|false, setSpeed <0..4>, setBrightness <0.2..2.5>
  IpcHandler {
    target: "waves"
    function setColor(color: string): void { if (color === "theme" || Palette.isColor(color)) root.set("color", color) }
    function setColor2(color: string): void { if (color === "auto" || Palette.isColor(color)) root.set("color2", color) }
    function setStyle(style: string): void { if (Palette.styles.indexOf(style) !== -1) root.set("style", style) }
    function setBlack(on: bool): void { root.set("black", on) }
    function setParticles(on: bool): void { root.set("particles", on) }
    function setSpeed(speed: real): void { root.set("speed", speed) }
    function setBrightness(value: real): void { root.set("brightness", value) }
  }

  // Keep the still in step with the look, a moment after it settles.
  property var stillSource: null
  readonly property string lookSignature: JSON.stringify(Palette.look(conf)) + theme
  onLookSignatureChanged: stillTimer.restart()
  Timer {
    id: stillTimer
    interval: 3000
    onTriggered: {
      if (!root.stillSource || root.stillSource.width < 2) return
      root.stillSource.grabToImage(function(result) { result.saveToFile(root.stillPath) })
    }
  }

  readonly property bool motion: Style.duration(100) > 0

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData

      screen: modelData
      color: "black"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      WlrLayershell.namespace: "omarchy-waves"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // What is on this screen's workspace decides how hard to work: nothing
      // is drawn behind a fullscreen window, and behind ordinary windows the
      // frame rate can drop, since little of the wallpaper is in view.
      readonly property var workspace: {
        var monitor = Hyprland.monitorFor(modelData)
        return monitor ? monitor.activeWorkspace : null
      }
      readonly property bool hidden: !!workspace && workspace.hasFullscreen
      readonly property bool covered: !!workspace && workspace.toplevels.values.length > 0
      readonly property real behind: root.value("behindFps")

      WaveScene {
        id: scene
        anchors.fill: parent
        conf: root.conf
        accent: Commons.Color.accent
        base: Commons.Color.background
        fade: Style.duration(250)
        running: root.motion && !window.hidden && !(window.covered && window.behind < 0)
        fpsCap: window.covered && window.behind > 0 ? window.behind : root.value("fps")
        Component.onCompleted: if (!root.stillSource) root.stillSource = scene.view
      }
    }
  }
}
