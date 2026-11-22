import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Palette.js" as Palette

BarWidget {
  id: root
  moduleName: "io.github.andershfranzen.waves"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // The wallpaper service and this menu share one settings file: the menu
  // writes it, the service follows it.
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/waves.json"
  property var conf: ({})
  readonly property var styles: Palette.styles
  readonly property var presets: [
    "#5aa9ff", "#7d86ff", "#b07cff", "#ff6fd0", "#ff6a6a", "#ff9a4d",
    "#ffd257", "#b6f25a", "#82fb9c", "#5ff0d8", "#62d8ff", "#c8ccd4"
  ]

  function value(key) { return Palette.value(conf, key) }
  function set(key, v) {
    var next = ({})
    for (var k in conf) next[k] = conf[k]
    next[key] = v
    conf = Palette.clean(next)
    writeTimer.start()
  }
  function hex(c) {
    function h(v) { var t = Math.round(v * 255).toString(16); return t.length < 2 ? "0" + t : t }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  // Saved looks: a preset carries the style, colours and motion, not the
  // rendering settings.
  function savePreset() {
    var list = value("presets").slice()
    if (list.length >= 8) list.shift()
    list.push(Palette.look(conf))
    set("presets", list)
  }
  function applyPreset(index) {
    var preset = value("presets")[index]
    if (!preset) return
    var next = ({})
    for (var k in conf) next[k] = conf[k]
    for (var i = 0; i < Palette.lookKeys.length; i++) {
      var key = Palette.lookKeys[i]
      if (preset[key] !== undefined) next[key] = preset[key]
    }
    conf = Palette.clean(next)
    writeTimer.start()
  }
  function removePreset(index) {
    var list = value("presets").slice()
    list.splice(index, 1)
    set("presets", list)
  }
  function presetColor(preset) {
    var c = preset ? preset.color : "theme"
    return Palette.isColor(c) ? c : Commons.Color.accent
  }
  // The extras that have to run commands (cloning the lock screen, updating
  // from git) live in bin/waves; it records each switch in the settings
  // file, which is how this menu sees the result.
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + moduleName + "/bin/waves"
  function runHelper(args) {
    if (bar && typeof bar.run === "function") bar.run("'" + helper + "' " + args)
  }

  // Back to the defaults, keeping saved presets and per-theme looks.
  function reset() {
    var next = ({})
    if (conf.presets) next.presets = conf.presets
    if (conf.themes) next.themes = conf.themes
    if (conf.lockScreen) next.lockScreen = conf.lockScreen
    if (conf.autoUpdate) next.autoUpdate = conf.autoUpdate
    conf = next
    writeTimer.start()
  }

  readonly property string choice: value("color")
  readonly property color fg: Commons.Color.popups.text
  readonly property color bg: Commons.Color.popups.background
  readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.22)
  readonly property color hover: Qt.rgba(fg.r, fg.g, fg.b, 0.08)

  property bool popupOpen: false
  function close() { popupOpen = false }

  FileView {
    id: settingsFile
    path: root.settingsPath
    atomicWrites: true
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      if (writeTimer.running) return
      var parsed = null
      try { parsed = JSON.parse(text()) } catch (e) { parsed = null }
      root.conf = Palette.clean(parsed)
    }
  }

  // Dragging a slider or the spectrum changes a value many times a second;
  // write the latest state at a steady pace.
  Timer {
    id: writeTimer
    interval: 40
    onTriggered: settingsFile.setText(JSON.stringify(root.conf, null, 2) + "\n")
  }

  // omarchy-shell waves-menu toggle
  IpcHandler {
    target: "waves-menu"
    function toggle(): void { root.popupOpen = !root.popupOpen }
  }

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // A label with a switch at the end of the row.
  component SwitchRow: Item {
    id: row
    property string label: ""
    property string hint: ""
    property bool checked: false
    signal toggled()
    width: parent ? parent.width : 0
    height: Math.max(labels.implicitHeight, toggle.implicitHeight)

    Column {
      id: labels
      anchors.left: parent.left
      anchors.right: toggle.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)
      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: row.label
        color: root.fg
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Text {
        textFormat: Text.PlainText
        visible: row.hint !== ""
        width: parent.width
        text: row.hint
        color: root.fg
        opacity: 0.55
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    ToggleSwitch {
      id: toggle
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: row.checked
      cursorRing: false
      foreground: root.fg
      onToggled: row.toggled()
    }
  }

  // A label, a slider, and the value it stands at.
  component SliderRow: Item {
    id: row
    property string label: ""
    property string readout: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    signal moved(real value)
    width: parent ? parent.width : 0
    height: Style.space(26)

    Text {
      id: name
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(84)
      text: row.label
      color: root.fg
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    PanelSlider {
      anchors.left: name.right
      anchors.right: number.left
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      minimum: row.minimum
      maximum: row.maximum
      step: row.step
      value: row.value
      trackColor: root.faint
      fillColor: root.fg
      knobColor: root.fg
      onMoved: function(v) { row.moved(v) }
      onReleased: function(v) { row.moved(v) }
    }
    Text {
      id: number
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
      horizontalAlignment: Text.AlignRight
      text: row.readout
      color: root.fg
      opacity: 0.7
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  // A label with a pick-one group at the end of the row.
  component ChoiceRow: Item {
    id: row
    property string label: ""
    property var options: []
    property string value: ""
    signal changed(string value)
    width: parent ? parent.width : 0
    height: group.implicitHeight

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      color: root.fg
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    ButtonGroup {
      id: group
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      options: row.options
      value: row.value
      focusable: false
      foreground: root.fg
      background: root.bg
      onChanged: function(v) { row.changed(v) }
    }
  }

  // A strip of every hue to drag along.
  component Spectrum: Rectangle {
    id: bar
    property bool marked: false
    property color current: "white"
    signal picked(string color)
    width: parent ? parent.width : 0
    height: Style.space(18)
    radius: height / 2
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.000; color: Qt.hsva(0.000, 0.6, 1, 1) }
      GradientStop { position: 0.167; color: Qt.hsva(0.167, 0.6, 1, 1) }
      GradientStop { position: 0.333; color: Qt.hsva(0.333, 0.6, 1, 1) }
      GradientStop { position: 0.500; color: Qt.hsva(0.500, 0.6, 1, 1) }
      GradientStop { position: 0.667; color: Qt.hsva(0.667, 0.6, 1, 1) }
      GradientStop { position: 0.833; color: Qt.hsva(0.833, 0.6, 1, 1) }
      GradientStop { position: 1.000; color: Qt.hsva(0.999, 0.6, 1, 1) }
    }
    function pickAt(x) {
      bar.picked(root.hex(Qt.hsva(Math.max(0, Math.min(0.999, x / width)), 0.6, 1, 1)))
    }
    // marks where the current colour sits
    Rectangle {
      visible: bar.marked
      width: Style.space(6)
      height: parent.height + Style.space(6)
      radius: width / 2
      y: -Style.space(3)
      x: Math.max(0, bar.current.hsvHue) * (parent.width - width)
      color: "white"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.5)
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) { bar.pickAt(mouse.x) }
      onPositionChanged: function(mouse) { if (pressed) bar.pickAt(mouse.x) }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏘"
    tooltipText: strings.t("tooltip")
    onPressed: function(mouseButton) { root.popupOpen = !root.popupOpen }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(364))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(10)

      // Live preview of the current settings
      Rectangle {
        id: preview
        width: parent.width
        height: Math.round(width * 0.30)
        color: "black"
        border.width: 1
        border.color: root.faint

        WaveScene {
          anchors.fill: parent
          anchors.margins: 1
          conf: root.conf
          accent: Commons.Color.accent
          base: Commons.Color.background
          fade: Style.duration(250)
          running: root.popupOpen && Style.duration(100) > 0
        }

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          text: strings.t("title")
          color: "white"
          opacity: 0.85
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }

      // Style
      PanelSectionHeader { text: strings.t("section.style"); foreground: root.fg }

      Row {
        id: styleRow
        width: parent.width
        spacing: Style.space(6)
        readonly property real cell: (width - spacing * (root.styles.length - 1)) / root.styles.length

        Repeater {
          model: root.styles
          Rectangle {
            required property string modelData
            readonly property bool current: root.value("style") === modelData
            width: styleRow.cell
            height: Style.space(30)
            radius: Style.space(6)
            color: current ? root.fg : (styleArea.containsMouse ? root.hover : "transparent")
            border.width: 1
            border.color: root.faint
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: strings.t("style." + modelData)
              color: current ? root.bg : root.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            MouseArea { id: styleArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.set("style", modelData) }
          }
        }
      }

      PanelSeparator { width: parent.width }

      // Colour
      PanelSectionHeader { text: strings.t("section.colour"); foreground: root.fg }

      Grid {
        id: grid
        columns: 7
        spacing: Style.space(8)
        readonly property real cell: (column.width - spacing * (columns - 1)) / columns

        // Follow the theme: its accent, marked with a ring
        Rectangle {
          width: grid.cell
          height: grid.cell
          radius: width / 2
          color: Commons.Color.accent
          border.width: root.choice === "theme" ? Math.max(2, Style.space(3)) : 0
          border.color: root.fg
          // a dot in the theme's background colour marks this as "the theme"
          Rectangle {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.36)
            height: width
            radius: width / 2
            color: Commons.Color.background
          }
          MouseArea {
            id: themeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.set("color", "theme")
          }
          PanelToolTip { visible: themeArea.containsMouse; text: strings.t("theme") }
        }

        Repeater {
          model: root.presets
          Rectangle {
            required property string modelData
            width: grid.cell
            height: grid.cell
            radius: Style.space(6)
            color: modelData
            scale: swatchArea.pressed ? 0.94 : 1
            border.width: root.choice.toLowerCase() === modelData ? Math.max(2, Style.space(3)) : 0
            border.color: root.fg
            Behavior on scale { NumberAnimation { duration: Style.duration(100); easing.type: Easing.OutCubic } }
            MouseArea { id: swatchArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.set("color", modelData) }
          }
        }
      }

      Spectrum {
        marked: root.choice !== "theme"
        current: root.choice === "theme" ? Commons.Color.accent : root.choice
        onPicked: function(c) { root.set("color", c) }
      }

      // Second colour: the background, and the planet's rings and moons
      Item {
        width: parent.width
        height: sameChip.height
        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: sameChip.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: strings.t(root.value("style") === "saturn" ? "color2.saturn" : "color2")
          color: root.fg
          elide: Text.ElideRight
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Rectangle {
          id: sameChip
          readonly property bool current: root.value("color2") === "auto"
          anchors.right: parent.right
          width: sameLabel.implicitWidth + Style.space(20)
          height: Style.space(26)
          radius: Style.space(6)
          color: current ? root.fg : (sameArea.containsMouse ? root.hover : "transparent")
          border.width: 1
          border.color: root.faint
          Text {
            id: sameLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: strings.t("color2.same")
            color: sameChip.current ? root.bg : root.fg
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          MouseArea { id: sameArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.set("color2", "auto") }
        }
      }
      Spectrum {
        marked: root.value("color2") !== "auto"
        current: root.value("color2") === "auto" ? "white" : root.value("color2")
        onPicked: function(c) { root.set("color2", c) }
      }

      SwitchRow {
        label: strings.t("black")
        checked: root.value("black")
        onToggled: root.set("black", !root.value("black"))
      }
      SwitchRow {
        label: strings.t("particles")
        checked: root.value("particles")
        onToggled: root.set("particles", !root.value("particles"))
      }

      PanelSeparator { width: parent.width }

      // Planet placement, for the saturn style only
      PanelSectionHeader { visible: root.value("style") === "saturn"; text: strings.t("section.planet"); foreground: root.fg }
      SliderRow {
        visible: root.value("style") === "saturn"
        label: strings.t("planet.x")
        minimum: 0.05
        maximum: 0.95
        value: root.value("planetX")
        readout: Commons.I18n.formatNumber(Math.round(root.value("planetX") * 100)) + "%"
        onMoved: function(v) { root.set("planetX", Math.round(v * 100) / 100) }
      }
      SliderRow {
        visible: root.value("style") === "saturn"
        label: strings.t("planet.y")
        minimum: 0.1
        maximum: 0.9
        value: root.value("planetY")
        readout: Commons.I18n.formatNumber(Math.round(root.value("planetY") * 100)) + "%"
        onMoved: function(v) { root.set("planetY", Math.round(v * 100) / 100) }
      }
      SliderRow {
        visible: root.value("style") === "saturn"
        label: strings.t("planet.size")
        minimum: 0.4
        maximum: 2
        value: root.value("planetSize")
        readout: Commons.I18n.formatNumber(Math.round(root.value("planetSize") * 100)) + "%"
        onMoved: function(v) { root.set("planetSize", Math.round(v * 20) / 20) }
      }
      PanelSeparator { visible: root.value("style") === "saturn"; width: parent.width }

      // Motion
      PanelSectionHeader { text: strings.t("section.motion"); foreground: root.fg }

      SliderRow {
        label: strings.t("speed")
        minimum: 0
        maximum: 2
        value: root.value("speed")
        readout: root.value("speed") < 0.025 ? strings.t("speed.paused")
          : Commons.I18n.formatNumber(root.value("speed"), 2) + "×"
        onMoved: function(v) { root.set("speed", Math.round(v * 20) / 20) }
      }
      SliderRow {
        label: strings.t("brightness")
        minimum: 0.3
        maximum: 2
        value: root.value("brightness")
        readout: Commons.I18n.formatNumber(Math.round(root.value("brightness") * 100)) + "%"
        onMoved: function(v) { root.set("brightness", Math.round(v * 20) / 20) }
      }

      PanelSeparator { width: parent.width }

      // Rendering
      PanelSectionHeader { text: strings.t("section.rendering"); foreground: root.fg }

      ChoiceRow {
        label: strings.t("fps")
        options: [
          { value: "0", label: strings.t("fps.native") },
          { value: "120", label: "120" },
          { value: "60", label: "60" },
          { value: "30", label: "30" }
        ]
        value: String(root.value("fps"))
        onChanged: function(v) { root.set("fps", Number(v)) }
      }
      ChoiceRow {
        label: strings.t("detail")
        options: [
          { value: "1", label: strings.t("detail.full") },
          { value: "0.5", label: strings.t("detail.half") }
        ]
        value: root.value("waveScale") < 0.75 ? "0.5" : "1"
        onChanged: function(v) { root.set("waveScale", Number(v)) }
      }
      ChoiceRow {
        label: strings.t("behind")
        options: [
          { value: "0", label: strings.t("behind.same") },
          { value: "60", label: "60" },
          { value: "30", label: "30" },
          { value: "-1", label: strings.t("behind.paused") }
        ]
        value: String(root.value("behindFps"))
        onChanged: function(v) { root.set("behindFps", Number(v)) }
      }

      PanelSeparator { width: parent.width }

      // Presets
      PanelSectionHeader { text: strings.t("section.presets"); foreground: root.fg }

      Flow {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: root.value("presets")
          Rectangle {
            required property var modelData
            required property int index
            width: presetRow.implicitWidth + Style.space(18)
            height: Style.space(28)
            radius: Style.space(6)
            color: presetArea.containsMouse ? root.hover : "transparent"
            border.width: 1
            border.color: root.faint
            Row {
              id: presetRow
              anchors.centerIn: parent
              spacing: Style.space(6)
              Rectangle {
                width: Style.space(10); height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.presetColor(modelData)
              }
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: strings.t("style." + (Palette.styles.indexOf(modelData.style) !== -1 ? modelData.style : "silk"))
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
            MouseArea {
              id: presetArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) root.removePreset(index)
                else root.applyPreset(index)
              }
            }
            PanelToolTip { visible: presetArea.containsMouse; text: strings.t("preset.hint") }
          }
        }

        Rectangle {
          width: saveLabel.implicitWidth + Style.space(18)
          height: Style.space(28)
          radius: Style.space(6)
          color: saveArea.containsMouse ? root.hover : "transparent"
          border.width: 1
          border.color: root.faint
          Text {
            id: saveLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: strings.t("preset.save")
            color: root.fg
            opacity: 0.8
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
          MouseArea { id: saveArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.savePreset() }
        }
      }

      SwitchRow {
        label: strings.t("perTheme")
        hint: strings.t("perTheme.hint")
        checked: root.value("perTheme")
        onToggled: root.set("perTheme", !root.value("perTheme"))
      }

      PanelSeparator { width: parent.width }

      // Extras
      PanelSectionHeader { text: strings.t("section.extras"); foreground: root.fg }

      SwitchRow {
        label: strings.t("lock")
        hint: strings.t("lock.hint")
        checked: root.value("lockScreen")
        onToggled: root.runHelper(root.value("lockScreen") ? "lock disable" : "lock enable")
      }
      SwitchRow {
        label: strings.t("autoUpdate")
        hint: strings.t("autoUpdate.hint")
        checked: root.value("autoUpdate")
        onToggled: root.runHelper(root.value("autoUpdate") ? "autoupdate off" : "autoupdate on")
      }

      PanelSeparator { width: parent.width }

      Button {
        text: strings.t("reset")
        foreground: root.fg
        bordered: true
        onClicked: root.reset()
      }
    }
  }
}
