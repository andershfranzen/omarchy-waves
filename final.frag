#version 440
// Pass 2, at full resolution: upscaled waves, crisp sparkles, dither.
//   /usr/lib/qt6/bin/qsb --qt6 -o final.frag.qsb final.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float p1;
  float p2;
  float p3;
  float aspect;
  float px;
  vec4 cRibbon;
  float sparkle; // 0 hides the particles
  float style;   // 4 is the planet, which stars must not shine through
  vec4 planet;   // saturn: centre x, centre y (0..1 of the screen), size
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec3 col = texture(source, qt_TexCoord0).rgb;

  // sparkles: at most one per grid cell, kept clear of the cell's border so
  // only this pixel's own cell has to be looked at
  float y = qt_TexCoord0.y;
  vec2 gp = vec2(qt_TexCoord0.x * aspect, y) * 6.0;
  vec2 cell = floor(gp);
  float r = hash(cell);
  bool space = style > 3.5;
  vec2 fromPlanet = vec2((qt_TexCoord0.x - planet.x) * aspect, y - planet.y);
  bool hidden = space && length(fromPlanet) < 0.170 * planet.z;
  if (space && sparkle > 0.0 && !hidden) {
    // a still field of small stars over the whole sky, each twinkling a little
    vec2 sp = vec2(qt_TexCoord0.x * aspect, y) * 24.0;
    vec2 sc = floor(sp);
    float s1 = hash(sc + 3.0);
    if (s1 < 0.55) {
      float s2 = hash(sc + 29.0);
      float s3 = hash(sc + 71.0);
      vec2 spos = sc + vec2(0.15 + 0.7 * s2, 0.15 + 0.7 * s3);
      float sd = length(sp - spos) / (24.0 * px);
      float srad = 0.55 + 0.9 * s3 * s3;
      float sq = sd / srad;
      float bright = (0.10 + 0.90 * s2 * s2 * s2) * (0.72 + 0.28 * sin((2.0 + floor(s3 * 5.0)) * p3 + s1 * 80.0));
      col += sparkle * bright * exp(-sq * sq) * mix(cRibbon.rgb, vec3(1.0), 0.8);
    }
  } else if (sparkle > 0.0 && r < 0.5 && y > 0.25 && y < 0.97) {
    float r2 = hash(cell + 17.0);
    float r3 = hash(cell + 43.0);
    float k = 1.0 + floor(r3 * 3.0);
    vec2 pos = cell + vec2(0.3 + 0.4 * r2, 0.3 + 0.4 * r3)
             + 0.16 * vec2(cos(k * p1 + r * 40.0), sin(k * p2 + r2 * 40.0));
    float dist = length(gp - pos) / (6.0 * px);
    float rad = 1.0 + 1.6 * r2;
    float tw = pow(0.5 + 0.5 * sin((2.0 + floor(r2 * 4.0)) * p3 + r3 * 40.0), 3.0) * (0.25 + 0.6 * r3);
    float q = dist / rad;
    float band = smoothstep(0.25, 0.38, y) * (1.0 - smoothstep(0.88, 0.97, y));
    col += sparkle * tw * band * (exp(-q * q) + 0.22 * exp(-q * q / 9.0)) * mix(cRibbon.rgb, vec3(1.0), 0.6);
  }

  // dither only where there is light, so black stays exactly black
  float lit = smoothstep(0.0, 2.0 / 255.0, max(col.r, max(col.g, col.b)));
  col += lit * (hash(gl_FragCoord.xy * 0.731) - 0.5) / 255.0;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
