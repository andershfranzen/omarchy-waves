import QtQuick

// The wallpaper picture itself: two shader passes. The waves are drawn small
// and upscaled; sparkles and dither are added at full resolution.
Item {
  id: view

  property real p1: 0
  property real p2: 0
  property real p3: 0
  property color cTop: "#080911"
  property color cMid: "#083238"
  property color cLow: "#146c4e"
  property color cRibbon: "#9efcb2"
  property color cAccent: cRibbon
  // saturn: centre x, centre y (0..1 of the picture) and size
  property vector4d planet: Qt.vector4d(0.5, 0.5, 1, 0)
  // 1 for a pure black background: drops the soft light around the ribbon.
  property real blackMix: 0
  // 0 silk, 1 bands, 2 threads, 3 aurora, 4 saturn
  property real style: 0
  property real gain: 1
  // 0 hides the drifting particles.
  property real sparkle: 1
  // Fraction of full resolution the waves are drawn at.
  property real waveScale: 1.0

  ShaderEffect {
    id: waves
    width: Math.max(1, Math.round(view.width * view.waveScale))
    height: Math.max(1, Math.round(view.height * view.waveScale))
    fragmentShader: Qt.resolvedUrl("wave.frag.qsb")
    property real p1: view.p1
    property real p2: view.p2
    property real p3: view.p3
    property real aspect: view.width / Math.max(1, view.height)
    property real px: 1 / height
    property color cTop: view.cTop
    property color cMid: view.cMid
    property color cLow: view.cLow
    property color cRibbon: view.cRibbon
    property real ambient: 1 - view.blackMix
    property real style: view.style
    property real gain: view.gain
    property color cAccent: view.cAccent
    property vector4d planet: view.planet
  }

  ShaderEffectSource {
    id: waveTexture
    sourceItem: waves
    hideSource: true
    smooth: true
    format: ShaderEffectSource.RGBA16F
  }

  ShaderEffect {
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("final.frag.qsb")
    property var source: waveTexture
    property real p1: view.p1
    property real p2: view.p2
    property real p3: view.p3
    property real aspect: view.width / Math.max(1, view.height)
    property real px: 1 / Math.max(1, view.height)
    property color cRibbon: view.cRibbon
    property real sparkle: view.sparkle
    property real style: view.style
    property vector4d planet: view.planet
  }
}
