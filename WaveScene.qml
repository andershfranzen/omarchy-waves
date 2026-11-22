import QtQuick
import "Palette.js" as Palette

// The moving picture for one set of settings: colours, transitions and the
// clock that drives the shader. Used by the wallpaper, the lock screen and
// the preview in the bar menu.
Item {
  id: scene

  property var conf: ({})
  property color accent: "#82fb9c"       // the theme's accent
  property color base: "#0b0c16"         // the theme's background
  property bool running: true
  // Redraws per second; 0 follows the display.
  property real fpsCap: 0
  // 0 makes every transition instant (animations switched off).
  property real fade: 250
  readonly property alias view: view

  function v(key) { return Palette.value(conf, key) }

  readonly property string tintChoice: v("color")
  readonly property string tint2Choice: v("color2")
  readonly property color tintTarget: tintChoice === "theme" ? accent : tintChoice
  readonly property color tint2Target: tint2Choice === "auto" ? tintTarget : tint2Choice
  property color tint: tintTarget
  property color tint2: tint2Target
  Behavior on tint { ColorAnimation { duration: scene.fade; easing.type: Easing.OutCubic } }
  Behavior on tint2 { ColorAnimation { duration: scene.fade; easing.type: Easing.OutCubic } }

  property real blackMix: v("black") ? 1 : 0
  property real sparkle: v("particles") ? 1 : 0
  Behavior on blackMix { NumberAnimation { duration: scene.fade; easing.type: Easing.OutCubic } }
  Behavior on sparkle { NumberAnimation { duration: scene.fade; easing.type: Easing.OutCubic } }

  // The style on screen changes only while the picture is faded out.
  readonly property int styleIndex: Math.max(0, Palette.styles.indexOf(v("style")))
  property int shownStyle: styleIndex
  property real gain: 1
  onStyleIndexChanged: styleChange.restart()
  SequentialAnimation {
    id: styleChange
    NumberAnimation { target: scene; property: "gain"; to: 0; duration: scene.fade * 0.5; easing.type: Easing.OutCubic }
    ScriptAction { script: scene.shownStyle = scene.styleIndex }
    NumberAnimation { target: scene; property: "gain"; to: 1; duration: scene.fade * 0.7; easing.type: Easing.OutCubic }
  }

  readonly property var palette: Palette.make(tint, tint2, base, tintChoice === "theme" && tint2Choice === "auto", blackMix)

  // Three phases at unrelated rates, so the motion never visibly repeats.
  // Each is wrapped to one turn here, where there is double precision.
  property real p1: 2.4
  property real p2: 4.3
  property real p3: 0.9
  property real pending: 0
  readonly property real turn: 2 * Math.PI

  FrameAnimation {
    running: scene.running
    onTriggered: {
      scene.pending += Math.min(frameTime, 0.1)
      if (scene.fpsCap > 0 && scene.pending < 1 / scene.fpsCap - 0.0015) return
      var dt = scene.pending * scene.v("speed")
      scene.pending = 0
      scene.p1 = (scene.p1 + dt * scene.turn / 24) % scene.turn
      scene.p2 = (scene.p2 + dt * scene.turn / 31) % scene.turn
      scene.p3 = (scene.p3 + dt * scene.turn / 43) % scene.turn
    }
  }

  WaveView {
    id: view
    anchors.fill: parent
    p1: scene.p1
    p2: scene.p2
    p3: scene.p3
    cTop: scene.palette.top
    cMid: scene.palette.mid
    cLow: scene.palette.low
    cRibbon: scene.palette.ribbon
    cAccent: scene.palette.accent
    blackMix: scene.blackMix
    style: scene.shownStyle
    gain: scene.gain * scene.v("brightness")
    sparkle: scene.sparkle
    waveScale: scene.v("waveScale")
    planet: Qt.vector4d(scene.v("planetX"), scene.v("planetY"), scene.v("planetSize"), 0)
  }
}
