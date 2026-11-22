# Waves

A live wallpaper for [Omarchy](https://omarchy.org). Instead of playing a video, a
shader draws the picture on the GPU at your display's refresh rate, so it stays
sharp at any resolution, never loops, and follows your theme's colours.

![Four of the styles: silk, saturn, bands and threads](preview.png)

## Styles

- **Silk**: thin translucent sheets that twist as they flow, in the spirit of classic game-console menus.
- **Bands**: broad, slow waves stacked on each other, each with a crisp crest.
- **Threads**: a twisting ribbon drawn as fine parallel lines.
- **Aurora**: soft curtains of light with no hard edges.
- **Saturn**: a ringed planet with drifting cloud bands and a wandering storm. The rings pass behind and in front of the globe, planet and rings shadow each other, and two moons orbit outside them.

## The menu

A palette icon in the bar opens the settings, with a live preview at the top:

- **Colour**: follow the theme's accent, pick one of twelve presets, or drag along the spectrum. A second colour tints the background, and Saturn's rings and moons.
- **OLED black**: a pure black background with only the wave or planet lit.
- **Particles**: drifting sparkles, or a starfield behind the planet.
- **Planet**: where Saturn sits and how big it is.
- **Motion**: speed (down to paused) and brightness.
- **Rendering**: frame rate, a lower frame rate while windows cover the workspace, and full or half resolution.
- **Presets**: save up to eight looks. *Remember per theme* keeps a separate look for each theme.

## Install

```bash
omarchy plugin add https://github.com/andershfranzen/omarchy-waves.git --enable
```

The wallpaper appears at once and the palette icon is added to the right side of the bar.

## Remove

```bash
omarchy plugin remove io.github.andershfranzen.waves
```

This removes the plugin and its bar icon; your normal background shows again.
Two files the plugin wrote are left behind and can be deleted:

- `~/.config/omarchy/waves.json`, your settings
- `~/.local/share/omarchy-waves/still.png`, a still of the current look

## What it touches

- It draws on its own layer above your background and below every window. Your
  background setting is not changed.
- It writes only the two files listed above. The still is refreshed a few
  seconds after you change the look, in case you want a matching image
  elsewhere (set it yourself with `omarchy theme bg set`).
- It uses no network and runs no commands.

## Settings file and commands

Everything in the menu is stored in `~/.config/omarchy/waves.json` and applied
live when the file changes, so it can be scripted. `Palette.js` lists every key
with its default. A few settings also have commands:

```bash
omarchy-shell waves setStyle silk|bands|threads|aurora|saturn
omarchy-shell waves setColor theme|#rrggbb
omarchy-shell waves setColor2 auto|#rrggbb
omarchy-shell waves setBlack true|false
omarchy-shell waves setParticles true|false
omarchy-shell waves setSpeed 0.5          # 0 to 4
omarchy-shell waves setBrightness 1.0     # 0.2 to 2.5
omarchy-shell waves-menu toggle           # open or close the menu, e.g. from a keybinding
```

## Performance

The shaders are cheap, but a wallpaper that moves makes the compositor redraw
the screen every frame. On an RTX 4070 at 3440x1440 and 240 Hz it costs about
6 W over idle. It stops drawing behind a fullscreen window, drops to 60 fps
while a workspace has windows open (changeable under *Rendering*), and freezes
when animations are turned off with `omarchy toggle animations`.

## On the lock screen

The lock screen is a separate Omarchy plugin, so Waves cannot add itself to it.
To use it there, clone the lock screen and load the backdrop in the clone:

```bash
omarchy plugin clone omarchy.lock
```

Then, in `~/.config/omarchy/plugins/<you>.lock/LockView.qml`, add this after the
`MultiEffect` that blurs the wallpaper:

```qml
Loader {
  anchors.fill: parent
  active: root.loadBackground
  visible: status === Loader.Ready && item !== null && item.ready === true
  source: Qt.resolvedUrl("../io.github.andershfranzen.waves/WaveBackdrop.qml")
  onLoaded: {
    item.accent = Qt.binding(function() { return Commons.Color.accent })
    item.base = Qt.binding(function() { return Commons.Color.background })
    item.running = Qt.binding(function() { return root.loadBackground })
  }
}
```

Restart the shell (`omarchy restart shell`) and check it with
`omarchy-shell lock preview`. If Waves is ever removed the stock wallpaper shows
again. A cloned lock screen no longer follows Omarchy's own lock-screen updates;
`omarchy plugin remove <you>.lock` goes back to the stock one.

## Requirements

- Omarchy 4 (the Quickshell-based Omarchy shell) on Hyprland.
- A GPU. Nothing else needs installing: the compiled shaders are in the repository.

## Development

The shader sources are `wave.frag` and `final.frag`. After editing one, rebuild
it with the Qt shader tools (`qt6-shadertools`, already part of Omarchy):

```bash
/usr/lib/qt6/bin/qsb --qt6 -o wave.frag.qsb wave.frag
/usr/lib/qt6/bin/qsb --qt6 -o final.frag.qsb final.frag
```

`WaveScene.qml` is the whole picture as one component (settings in, animation
out); the wallpaper, the menu preview and the lock-screen backdrop all use it.

## License

MIT. See [LICENSE](LICENSE).
