.pragma library

// Settings and colours shared by the wallpaper, the lock screen and the
// preview in the bar menu.

var defaults = {
  color: "theme",        // "theme" or "#rrggbb": the wave, or the planet
  color2: "auto",        // "auto" (same as color) or "#rrggbb": background, rings and moons
  black: false,          // OLED: pure black background
  particles: true,
  style: "silk",
  brightness: 1,
  speed: 0.5,
  planetX: 0.5,          // saturn: where the planet sits, and how big
  planetY: 0.5,
  planetSize: 1,
  fps: 0,                // 0 follows the monitor
  behindFps: 60,         // while windows cover the workspace: 0 same, -1 paused
  waveScale: 1,
  perTheme: false,       // remember the look separately for each theme
  lockScreen: false,     // set by bin/waves: Waves is on the lock screen
  autoUpdate: false,     // set by bin/waves: update Waves with Omarchy
  presets: [],
  themes: {}
}

var styles = ["silk", "bands", "threads", "aurora", "saturn"]

// What a preset, or a theme's remembered look, carries.
var lookKeys = ["style", "color", "color2", "black", "particles", "brightness", "speed", "planetX", "planetY", "planetSize"]

function value(conf, key) {
  var v = conf ? conf[key] : undefined
  var d = defaults[key]
  if (v === undefined || v === null || typeof v !== typeof d) return d
  if (Array.isArray(d) !== Array.isArray(v)) return d
  return v
}

function look(conf) {
  var out = {}
  for (var i = 0; i < lookKeys.length; i++) out[lookKeys[i]] = value(conf, lookKeys[i])
  return out
}

function isColor(s) {
  return typeof s === "string" && /^#[0-9a-fA-F]{6}$/.test(s)
}

// Settings as read from disk, with anything malformed dropped.
function clean(parsed) {
  var out = {}
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return out
  for (var key in defaults) {
    var v = parsed[key]
    var d = defaults[key]
    if (v === undefined || typeof v !== typeof d || Array.isArray(d) !== Array.isArray(v)) continue
    out[key] = v
  }
  if (out.color !== undefined && out.color !== "theme" && !isColor(out.color)) delete out.color
  if (out.color2 !== undefined && out.color2 !== "auto" && !isColor(out.color2)) delete out.color2
  if (out.style !== undefined && styles.indexOf(out.style) === -1) delete out.style
  function clamp(key, lo, hi) { if (out[key] !== undefined) out[key] = Math.max(lo, Math.min(hi, out[key])) }
  clamp("brightness", 0.2, 2.5); clamp("speed", 0, 4); clamp("waveScale", 0.25, 1)
  clamp("planetX", 0, 1); clamp("planetY", 0, 1); clamp("planetSize", 0.3, 2.5)
  clamp("fps", 0, 1000); clamp("behindFps", -1, 1000)
  if (out.presets) out.presets = out.presets.filter(function(p) { return p && typeof p === "object" }).slice(0, 8)
  // settings from before "behindFps": the old switch meant paused
  if (parsed.pauseBehindWindows === true && parsed.behindFps === undefined) out.behindFps = -1
  return out
}

function shade(h, s, v) {
  return Qt.hsva(((h % 1) + 1) % 1, Math.max(0, Math.min(1, s)), v, 1)
}

// tint colours the wave (or planet); tint2 the background, rings and moons.
function make(tint, tint2, base, followTheme, blackMix) {
  var hue = Math.max(0, tint.hsvHue)
  var sat = Math.min(1, tint.hsvSaturation * 1.75)
  var hue2 = Math.max(0, tint2.hsvHue)
  var sat2 = Math.min(1, tint2.hsvSaturation * 1.75)
  var k = 1 - blackMix
  function dim(c) { return Qt.rgba(c.r * k, c.g * k, c.b * k, 1) }
  return {
    top: dim(followTheme ? Qt.rgba(base.r * 0.75, base.g * 0.75, base.b * 0.75, 1) : shade(hue2 + 0.10, sat2 * 0.6, 0.055)),
    mid: dim(shade(hue2 + 0.06, sat2, 0.21)),
    low: dim(shade(hue2 + 0.03, sat2 * 0.97, 0.43)),
    ribbon: shade(hue + 0.01, sat * 0.45, 1.0),
    accent: shade(hue2 + 0.01, sat2 * 0.45, 1.0)
  }
}
