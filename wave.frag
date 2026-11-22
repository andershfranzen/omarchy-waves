#version 440
// Pass 1: gradient and the wave itself, in one of five styles.
// Rebuild after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o wave.frag.qsb wave.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float p1;      // three slow phases, each wrapped to 0..2pi on the CPU
  float p2;
  float p3;
  float aspect;  // width / height
  float px;      // one pixel of this pass in units of screen height
  vec4 cTop;
  vec4 cMid;
  vec4 cLow;
  vec4 cRibbon;
  float ambient; // soft light around the wave; 0 for a pure black background
  float style;   // 0 silk, 1 bands, 2 threads, 3 aurora, 4 saturn
  float gain;    // fades the wave out and in while the style changes
  vec4 cAccent;  // second colour: the planet's rings and moons
  vec4 planet;   // saturn: centre x, centre y (0..1 of the screen), size
};

// Silk: one sheet, brightest along its leading edge, fading out over a signed
// extent. Where the extent passes through zero the sheet flips over, which
// reads as a twist in the fabric.
float sheet(float y, float lead, float ext, float g) {
  float w = abs(ext) + 3.0 * px;
  float d = (y - lead) * sign(ext) / w;
  float aa = 0.9 * px / w;
  float enter = smoothstep(-aa, aa, d);
  float fade = clamp(1.0 - d, 0.0, 1.0);
  float body = enter * fade * fade * (0.30 + 0.70 * fade);
  float e = (y - lead) / (0.75 * px);
  float rim = exp(-e * e) * 0.48;
  float thin = 0.65 + 0.35 * clamp(0.05 / w, 0.0, 2.0);
  return g * thin * (body + rim);
}

// Bands: everything below a long slow curve is lit, fading with depth, under
// a crisp crest line.
float band(float y, float lead, float depth, float g) {
  float d = y - lead;
  float enter = smoothstep(-0.9 * px, 0.9 * px, d);
  float dd = max(d, 0.0);
  float fill = enter * (0.34 * exp(-dd / depth) + 0.09 * clamp(1.0 - dd / (depth * 3.5), 0.0, 1.0));
  float e = d / (0.75 * px);
  return g * (fill + 0.42 * exp(-e * e));
}

// Threads: a twisting ribbon drawn as fine parallel lines between two rims.
float threads(float y, float c, float h, float g) {
  h = abs(h) + 2.0 * px;
  float d = abs(y - c);
  float u = d / h;
  float inside = clamp((1.0 - u) * h / (1.2 * px), 0.0, 1.0);
  float body = inside * (0.06 + 0.40 * u * u * u);
  float e = (d - h) / (0.8 * px);
  float edge = exp(-e * e);
  float gl = (d - h) / (12.0 * px);
  float halo = exp(-gl * gl) * 0.14;
  float lines = inside * 0.34 * pow(0.5 + 0.5 * cos(u * 34.5575), 10.0);
  float thin = 0.55 + 0.45 * clamp(0.05 / h, 0.0, 1.6);
  return g * thin * (body + 0.80 * edge + halo + lines);
}

// Aurora: a soft curtain of light along a curve, with no hard edge at all.
float curtain(float y, float c, float w, float g) {
  float d = (y - c) / w;
  return g * exp(-d * d);
}

// Saturn: how much ring there is at a distance r from the planet's centre,
// in planet radii. fw is the width to soften edges over.
float ringDensity(float r, float fw) {
  float d = smoothstep(1.24 - fw, 1.24 + fw, r) * (1.0 - smoothstep(2.30 - fw, 2.30 + fw, r));
  d *= 0.50 + 0.50 * smoothstep(1.50 - fw, 1.52 + fw, r);                                          // faint inner ring
  d *= 1.0 - 0.94 * (smoothstep(1.95 - fw, 1.95 + fw, r) - smoothstep(2.03 - fw, 2.03 + fw, r));   // the wide gap
  d *= 1.0 - 0.60 * (smoothstep(2.20 - fw, 2.20 + fw, r) - smoothstep(2.215 - fw, 2.215 + fw, r)); // a narrow one
  return d;
}

// Saturn: a banded planet with weather, lit from the upper left, inside
// rings that turn around it. Everything is traced per pixel: the rings pass
// behind and in front of the globe, and each casts its shadow on the other.
// One moon: a small lit sphere centred at C (in the rings' frame), rgb + cover.
vec4 moon(vec2 q, vec3 C, float rm, vec3 L, float R) {
  vec2 dm = q - C.xy;
  float dist = length(dm);
  float cover = 1.0 - smoothstep(rm - px, rm + px, dist);
  if (cover <= 0.0) return vec4(0.0);
  vec3 nm = vec3(dm, sqrt(max(rm * rm - dist * dist, 0.0))) / rm;
  float along = dot(C, L);
  float shadow = along > 0.0 ? 1.0 : smoothstep(R * 0.96, R * 1.04, length(C - along * L));
  vec3 c = mix(cAccent.rgb, vec3(1.0), 0.45) * (0.03 + 0.97 * max(dot(nm, L), 0.0)) * shadow * gain;
  return vec4(c, cover);
}

vec3 saturn(vec3 bg, float u, float y) {
  vec2 p = vec2((u - planet.x) * aspect, y - planet.y);
  float R = 0.165 * planet.z;
  float cr = cos(-0.30);
  float sr = sin(-0.30);
  vec2 q = vec2(cr * p.x + sr * p.y, -sr * p.x + cr * p.y);  // the rings' long axis runs along q.x

  float sT = 0.30 + 0.06 * sin(p3);          // how far the rings are opened toward us; it breathes
  float cT = sqrt(1.0 - sT * sT);
  vec3 N = vec3(0.0, -cT, sT);               // the planet's pole and the ring plane's normal
  vec3 e2 = vec3(0.0, sT, cT);               // in the ring plane, toward the viewer
  vec3 L = normalize(vec3(-0.62, -0.30, 0.72));
  float fade = smoothstep(0.0, 0.3, gain);

  // rings
  float b = q.y / sT;
  float r = length(vec2(q.x, b)) / R;
  float fw = fwidth(r);
  float th = atan(b, q.x);
  float fine = 1.0 - clamp(fw * 30.0, 0.0, 1.0);
  float ringlets = 0.80 + fine * (0.14 * sin(r * 88.0) + 0.08 * sin(r * 33.0 + 1.0));
  // lumps of material orbiting, the inner ones overtaking the outer
  float clumps = 1.0 + 0.26 * sin(5.0 * th - 3.0 * p1 + r * 9.0) + 0.18 * sin(3.0 * th - 2.0 * p2 - r * 14.0)
               + 0.14 * sin(9.0 * th - 4.0 * p1 - r * 22.0);
  // a few bright knots riding the outer ring
  float knots = pow(0.5 + 0.5 * sin(2.0 * th - p1 + 0.7), 24.0) * smoothstep(2.03, 2.10, r);
  clumps += 0.9 * knots;
  vec3 Q = vec3(q.x, 0.0, 0.0) + b * e2;
  float along = dot(Q, L);
  float shadow = along > 0.0 ? 1.0 : smoothstep(R * 0.96, R * 1.04, length(Q - along * L));
  vec3 ringCol = mix(cAccent.rgb, vec3(1.0), 0.22) * 0.66 * ringlets * clumps * (0.10 + 0.90 * shadow) * gain;
  float ringA = ringDensity(r, fw) * 0.90 * fade;

  // planet
  float d2 = dot(q, q);
  float disc = (1.0 - smoothstep(R - px, R + px, sqrt(d2))) * fade;
  vec3 globe = vec3(0.0);
  if (disc > 0.0) {
    vec3 n = vec3(q, sqrt(max(R * R - d2, 0.0))) / R;
    float lat = dot(n, N);
    float lon = atan(dot(n, e2), n.x);
    // cloud bands, sheared by winds that blow at different speeds
    float flow = lat * 13.0 + 0.55 * sin(3.0 * lon - 2.0 * p1 + lat * 5.0) + 0.30 * sin(5.0 * lon + 3.0 * p2 - lat * 9.0);
    float bands = 0.5 + 0.5 * sin(flow);
    float streaks = 0.5 + 0.5 * sin(lat * 41.0 + 0.8 * sin(4.0 * lon - 3.0 * p1));
    float sl = (lat + 0.32) / 0.07;
    float storm = exp(-(sl * sl + (1.0 - cos(lon - p2 + 1.0)) * 18.0));   // a pale storm drifting round
    float tone = 0.42 + 0.34 * bands + 0.12 * streaks + 0.50 * storm;
    vec3 base = mix(cRibbon.rgb, cRibbon.brg, 0.22 * bands);
    base = mix(base, vec3(1.0), 0.18 * bands + 0.50 * storm);
    float diff = max(dot(n, L), 0.0);
    float light = 0.035 + 0.965 * pow(diff, 0.85);
    // the rings' shadow across the globe
    float t = -dot(n, N) / dot(L, N);
    if (t > 0.0) light *= 1.0 - 0.62 * ringDensity(length(n + t * L), 0.02);
    float rim = pow(1.0 - n.z, 3.0) * diff;
    globe = (base * tone * light + cRibbon.rgb * 0.35 * rim) * gain;
  }

  // two moons orbiting outside the rings, in the same plane
  float a1 = p2 + 0.8;
  float a2 = p3 + 3.6;
  vec3 C1 = R * 2.75 * (cos(a1) * vec3(1.0, 0.0, 0.0) + sin(a1) * e2);
  vec3 C2 = R * 3.45 * (cos(a2) * vec3(1.0, 0.0, 0.0) + sin(a2) * e2);
  vec4 m1 = moon(q, C1, R * 0.075, L, R);
  vec4 m2 = moon(q, C2, R * 0.050, L, R);

  float d = sqrt(d2) / R;
  vec3 col = bg + cRibbon.rgb * 0.06 * ambient * fade * exp(-d * d / 7.0);
  if (C1.z < 0.0) col = mix(col, m1.rgb, m1.a * fade);   // moons on the far side
  if (C2.z < 0.0) col = mix(col, m2.rgb, m2.a * fade);
  col = mix(col, ringCol, b > 0.0 ? 0.0 : ringA);        // far half of the rings
  col = mix(col, globe, disc);
  col = mix(col, ringCol, b > 0.0 ? ringA : 0.0);        // near half, across the globe
  if (C1.z >= 0.0) col = mix(col, m1.rgb, m1.a * fade);  // moons on the near side
  if (C2.z >= 0.0) col = mix(col, m2.rgb, m2.a * fade);
  return col;
}

void main() {
  float u = qt_TexCoord0.x;
  float x = u * aspect;
  float y = qt_TexCoord0.y;

  // the line the wave follows, rising gently to the right
  float c = 0.615 - 0.050 * (u - 0.5)
          + 0.060 * sin(1.45 * x - p1 + 0.3)
          + 0.026 * sin(2.90 * x + p2 + 1.9);

  // background: dark above, colour below, lit softly around the wave
  float gr = clamp(y + 0.12 * (u - 0.5), 0.0, 1.0);
  float a = pow(clamp(gr / 0.60, 0.0, 1.0), 1.5);
  float b = pow(clamp((gr - 0.40) / 0.60, 0.0, 1.0), 1.6);
  vec3 col = cTop.rgb + (cMid.rgb - cTop.rgb) * a + (cLow.rgb - cMid.rgb) * b;
  float vx = u - 0.5;
  float vy = y - 0.55;
  col *= 1.0 - 0.38 * (vx * vx * 2.2 + vy * vy * 1.3);
  float near = (y - c) / 0.22;
  col += cRibbon.rgb * 0.055 * ambient * exp(-near * near) * step(style, 3.5);

  if (style > 3.5) {
    fragColor = vec4(saturn(col, u, y), 1.0) * qt_Opacity;
    return;
  }

  float glow = 0.0;
  if (style < 0.5) {
    glow += sheet(y, c - 0.050 + 0.030 * sin(2.1 * x - p2 + 0.7),
                   0.150 * sin(1.20 * x - p3 + 0.4) + 0.030, 0.190);
    glow += sheet(y, c - 0.012 + 0.024 * sin(2.6 * x + p3 + 2.9),
                  -0.120 * sin(1.55 * x + p1 + 1.7) - 0.020, 0.165);
    glow += sheet(y, c + 0.020 + 0.034 * sin(1.8 * x - p1 + 4.1),
                   0.170 * sin(1.05 * x + p2 + 3.3) + 0.015, 0.150);
    glow += sheet(y, c + 0.052 + 0.022 * sin(3.1 * x + p2 + 5.2),
                  -0.095 * sin(1.90 * x - p3 + 2.2) + 0.025, 0.140);
    glow += sheet(y, c - 0.030 + 0.040 * sin(1.3 * x - p3 + 1.2),
                   0.070 * sin(2.30 * x - p1 + 5.6) - 0.010, 0.125);
  } else if (style < 1.5) {
    glow += band(y, 0.50 + 0.100 * sin(0.90 * x - p1 + 0.5) + 0.030 * sin(2.1 * x + p2 + 0.8), 0.20, 0.36);
    glow += band(y, 0.58 + 0.115 * sin(0.72 * x + p2 + 2.0) + 0.025 * sin(1.9 * x - p3 + 1.0), 0.22, 0.32);
    glow += band(y, 0.66 + 0.090 * sin(1.10 * x - p3 + 4.0) + 0.030 * sin(2.4 * x + p1 + 3.0), 0.22, 0.30);
    glow += band(y, 0.75 + 0.080 * sin(0.82 * x + p1 + 5.2) + 0.020 * sin(2.0 * x - p2 + 4.4), 0.24, 0.26);
  } else if (style < 2.5) {
    glow += threads(y,
      0.60 + 0.085 * sin(1.9 * x - p1 + 0.3) + 0.040 * sin(3.7 * x + 2.0 * p2 + 1.9) + 0.018 * sin(7.1 * x - 3.0 * p3 + 4.0),
      0.085 + 0.055 * sin(2.3 * x - 2.0 * p2 + 2.2) + 0.025 * sin(5.2 * x + 3.0 * p1 + 0.7), 0.30);
    glow += threads(y,
      0.66 + 0.070 * sin(2.2 * x - p2 + 1.4) + 0.045 * sin(4.1 * x + 2.0 * p3 + 3.3) + 0.015 * sin(8.3 * x - 4.0 * p1 + 0.2),
      0.050 + 0.038 * sin(2.9 * x + 2.0 * p3 + 5.1) + 0.016 * sin(6.4 * x - 3.0 * p2 + 2.6), 0.38);
    glow += threads(y,
      0.55 + 0.095 * sin(1.6 * x - p3 + 2.6) + 0.035 * sin(3.3 * x + 3.0 * p1 + 0.9) + 0.012 * sin(9.0 * x - 4.0 * p2 + 5.2),
      0.030 + 0.024 * sin(3.4 * x - 2.0 * p1 + 1.1) + 0.010 * sin(7.7 * x + 4.0 * p3 + 3.9), 0.26);
  } else {
    glow += curtain(y, c - 0.060 + 0.050 * sin(1.7 * x - p2 + 0.7),
                    0.050 + 0.030 * sin(1.3 * x + p3 + 1.0), 0.20 + 0.10 * sin(2.3 * x - p1 + 0.4));
    glow += curtain(y, c + 0.010 + 0.060 * sin(1.2 * x + p3 + 2.9),
                    0.070 + 0.040 * sin(0.9 * x - p1 + 3.1), 0.17 + 0.09 * sin(1.9 * x + p2 + 2.0));
    glow += curtain(y, c + 0.070 + 0.045 * sin(2.0 * x - p1 + 4.1),
                    0.040 + 0.025 * sin(1.6 * x + p2 + 5.0), 0.19 + 0.10 * sin(2.7 * x - p3 + 4.2));
    glow += curtain(y, c - 0.010 + 0.035 * sin(2.6 * x + p1 + 5.3),
                    0.018 + 0.012 * sin(2.2 * x - p3 + 0.6), 0.16 + 0.10 * sin(3.1 * x + p2 + 1.1));
  }
  col += gain * glow * cRibbon.rgb;

  fragColor = vec4(col, 1.0) * qt_Opacity;
}
