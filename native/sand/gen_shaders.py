#!/usr/bin/env python3
# Writes the sand component's GPU programs (shaders/*.comp, grain.vert/.frag) from one source (2026-10-15). They are
# the physics of ../pbd_shaders.py (tested in book4-edge/notch-before/sandpbd.py against the approved film), ported to Qt's RHI: all settings
# in one uniform block (one copy per small step, picked by a dynamic offset), the same storage buffers in every
# program so one set of bindings serves them all.
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "shaders")   # build.sh: outside the repo
os.makedirs(OUT, exist_ok=True)
HEAD = """#version 440
layout(local_size_x = 128) in;
layout(std140, binding = 0) uniform Sim {
    int n; int gx; int gy; int gz;
    int cap; int ncol; int nvent; int ksub;
    int trkN; int trkHead; int pad0; int pad1;
    float W; float H; float D; float CELL;
    float CORNER; float dt; float g; float t;
    float tv; float tau0; float lam; float nu;
    float VLIFE; float PUFF; float HPUFF; float LIFTL;
    float ELL; float CDEP; float THROB; float gscale;
    float muS; float muK; float relax; float sink;
    float low; float sway; float mid; float level;
    float shake; float TAPA; float TAPP; float e;
    float eFloor; float vrest; float spread; float trail;
};
layout(std430, binding = 1) buffer Pos { vec4 pos[]; };
layout(std430, binding = 2) buffer PosOut { vec4 posOut[]; };
layout(std430, binding = 3) buffer Vel { vec4 vel[]; };
layout(std430, binding = 4) buffer VelOut { vec4 velOut[]; };
layout(std430, binding = 5) buffer Prev { vec4 prev[]; };
layout(std430, binding = 6) buffer VPre { vec4 vpre[]; };
layout(std430, binding = 7) buffer Rest { float rest[]; };
layout(std430, binding = 8) buffer Spin { vec4 spin[]; };
layout(std430, binding = 9) buffer Ori { vec4 ori[]; };
layout(std430, binding = 10) buffer Cnt { int cnt[]; };
layout(std430, binding = 11) buffer Idx { int idx[]; };
layout(std430, binding = 12) buffer Surf { int surf[]; };
layout(std430, binding = 13) buffer Vents { vec4 vents[]; };
layout(std430, binding = 14) buffer Trk { float trk[]; };
layout(std430, binding = 15) buffer Inst { vec4 inst[]; };     // drawn grains: centre+radius, colour+glint, shade
const float SLEEP = 8.0, SLOP = 0.05, QUIET = 0.12;
int cellOf(vec3 p) {
    int cx = clamp(int(p.x / CELL), 0, gx - 1), cy = clamp(int(p.y / CELL), 0, gy - 1), cz = clamp(int(p.z / CELL), 0, gz - 1);
    return (cz * gy + cy) * gx + cx;
}
bool asleep(uint k) { return rest[k] > SLEEP && vpre[k].w < QUIET; }
float shapeAt(float x, float sw) { float edge = smoothstep(0.0, CORNER, min(x, W - x)); return edge * (0.55 + 0.45 * cos(6.2832 * (x - W * 0.5) / (W * 0.9) + sw)); }
float tapAt(float tt) { float a = mod(tt, TAPP); return (1.0 - exp(-a / 0.0015)) * exp(-a / 0.02); }
float floorY(float x, float tt) {
    float sh = shapeAt(x, sway);
    return H - 2.0 + sink - TAPA * mid * tapAt(tt) * (0.6 + 0.4 * sh) - level * g / (188.5 * 188.5) * sin(188.5 * tt);
}
vec3 walls(vec3 x, float r, vec3 moved) {
    float fy = floorY(x.x, t), pen = x.y + r - fy;
    if (pen > 0.0) {
        x.y -= pen;
        vec2 slip = moved.xz; float sl = length(slip);
        if (sl > 1e-6) x.xz -= slip * (sl < 0.6 * pen ? 1.0 : min(0.45 * pen / sl, 1.0));
    }
    x.z = clamp(x.z, r, D - r);
    x.x = clamp(x.x, r, W - r);
    x.y = max(x.y, r);
    for (int side = 0; side < 2; side++) {
        vec2 cc = vec2(side == 0 ? CORNER : W - CORNER, H - CORNER + sink);
        if (x.y > cc.y && (side == 0 ? x.x < CORNER : x.x > W - CORNER)) {
            vec2 d = x.xy - cc; float l = length(d), lim = CORNER - 2.0 - r;
            if (l > lim) x.xy = cc + d / l * lim;
        }
    }
    return x;
}
// the low band, tlag seconds ago (a ring of the last trkN values at 60 per second)
float lowAt(float tlag) {
    float back = max(0.0, (tv - tlag) * 60.0); int k = int(back);
    if (k >= trkN - 1) return 0.0;
    int i0 = (trkHead - k + trkN) % trkN, i1 = (i0 - 1 + trkN) % trkN;
    return mix(trk[i0], trk[i1], fract(back));
}
#define NEIGHBOURS(X) int cx_ = int(X.x / CELL), cy_ = int(X.y / CELL), cz_ = int(X.z / CELL); \\
    for (int oz = -1; oz <= 1; oz++) for (int oy = -1; oy <= 1; oy++) for (int ox = -1; ox <= 1; ox++) { \\
        int xx = cx_ + ox, yy = cy_ + oy, zz = cz_ + oz; \\
        if (xx < 0 || yy < 0 || zz < 0 || xx >= gx || yy >= gy || zz >= gz) continue; \\
        int cc = (zz * gy + yy) * gx + xx, nc = min(cnt[cc], cap); \\
        for (int s = 0; s < nc; s++) { int j = idx[cc * cap + s]; if (j == int(i)) continue;
#define END_NEIGHBOURS } }
"""
K = {}
K["clear"] = "void main() { uint i = gl_GlobalInvocationID.x; if (i < uint(gx * gy * gz)) cnt[i] = 0; }"
K["insert"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i]; if (p.w < 0.0) return;
    int c = cellOf(p.xyz); int s = atomicAdd(cnt[c], 1);
    if (s < cap) idx[c * cap + s] = int(i);
}"""
K["surfclear"] = "void main() { uint i = gl_GlobalInvocationID.x; if (i <= uint(ncol)) surf[i] = (i == uint(ncol)) ? 0 : int((H + 400.0) * 16.0); }"
K["surffill"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i]; if (p.w < 0.0) return;
    int c = clamp(int(p.x / 6.0), 0, ncol - 1);
    if (spin[i].w >= 2.0) atomicMin(surf[c], int(p.y * 16.0));
    else if (spin[i].w < 0.5) atomicAdd(surf[ncol], 1);
}"""
K["copy"] = "void main() { uint i = gl_GlobalInvocationID.x; if (i < uint(n)) pos[i] = posOut[i]; }"
K["stabilize"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i];
    if (p.w < 0.0 || asleep(i)) { posOut[i] = p; return; }
    vec3 x = p.xyz; float r = p.w, wi = 1.0 / (r * r * r);
    vec3 corr = vec3(0.0); float cntc = 0.0;
    NEIGHBOURS(x)
        vec4 q = pos[j]; vec3 d = x - q.xyz; float dist = length(d), rr = r + q.w;
        if (dist >= rr || dist < 1e-5) continue;
        float wj = asleep(uint(j)) ? 0.0 : 1.0 / (q.w * q.w * q.w);
        corr += wi / (wi + wj) * max(0.0, rr - dist - SLOP) * d / dist; cntc += 1.0;
    END_NEIGHBOURS
    x += corr / max(cntc, 1.0);
    posOut[i] = vec4(walls(x, r, vec3(0.0)), r);
}"""
K["predict"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i]; vec3 v = vel[i].xyz;
    prev[i] = p; vpre[i] = vec4(v, 0.0);
    if (p.w < 0.0) return;
    float r = p.w;
    float sy = float(surf[clamp(int(p.x / 6.0), 0, ncol - 1)]) / 16.0;
    float zc = sy - p.y, dz = max(0.0, -zc), tlag = tv - dz / CDEP;
    float lf = LIFTL * lowAt(tlag) * (0.65 + 0.35 * sin(6.2832 * THROB * tlag)) * exp(-dz / ELL);
    lf *= exp(-max(zc, 0.0) / (2.0 * r));
    vec3 air = vec3(0.0);
    for (int k = 0; k < nvent; k++) {
        vec4 vt = vents[k]; float age = tv - vt.y;
        if (age < 0.0 || age > VLIFE) continue;
        float dxv = (p.x - vt.x) / vt.z;
        bool hiss = vt.w < 0.0;
        float a = abs(vt.w) * exp(-dxv * dxv) * (1.0 - exp(-age / (hiss ? 0.002 : 0.004))) * exp(-age / (hiss ? 0.02 : 0.05))
                  * exp(-max(zc, 0.0) / (hiss ? 15.0 : 3.0 * vt.z));
        if (a < 0.002) continue;
        float gust = 0.45 + 1.1 * fract(sin(float(i) * 12.9898 + vt.y * 78.233 + vt.x * 0.137) * 43758.5453);
        air.y -= (hiss ? HPUFF : PUFF) * a * gust * exp(min(zc, 0.0) / lam) * step(-2.0 * r, zc);
    }
    // taps from below (sandwind.py's floor taps): the floor's own 1.5 ms kick is too quick for these 5.6 ms steps, so
    // each tap is a short upward shove through the bed instead, strongest near the surface (the top grains jump),
    // uneven grain to grain (they knock into each other); while it taps the bed stays awake
    float tap = shake * mid * tapAt(t);
    float tw = (0.35 + 0.65 * exp(-dz / 30.0)) * (0.55 + 0.9 * fract(sin(float(i) * 7.13 + floor(t / TAPP) * 3.71) * 43758.5453));
    float drive = max(max(lf, length(air) / 400.0), shake * mid * 0.5);
    vpre[i].w = drive;
    bool pressed = p.y + r > floorY(p.x, t) + SLOP;      // the floor came up into it: it wakes and is pushed up
    if (pressed) rest[i] = 0.0;
    if (rest[i] > SLEEP && drive < QUIET) { vel[i] = vec4(0.0, 0.0, 0.0, vel[i].w); return; }
    v.y += g * (1.0 - lf) * dt;
    if (zc < 2.0 * r) {                                 // in the bed or on it
        v.y -= g * tap * tw * dt;
        v.x += g * tap * tw * dt * 0.35 * (fract(sin(float(i) * 3.3 + floor(t / TAPP) * 1.9) * 9137.1) - 0.5);
    }
    float rs = r / gscale;
    float re = length(air - v) * 2.0 * rs / nu;
    float tp = tau0 * (rs / 2.5) * (rs / 2.5) / (1.0 + 0.15 * pow(re, 0.687));
    v = air + (v - air) * exp(-dt / tp);
    p.xyz += v * dt;
    pos[i] = p;
}"""
K["solve"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i];
    if (p.w < 0.0 || asleep(i)) { posOut[i] = p; return; }
    vec3 x = p.xyz; float r = p.w, wi = 1.0 / (r * r * r);
    vec3 moved = x - prev[i].xyz;
    vec3 corr = vec3(0.0), fric = vec3(0.0); float cntc = 0.0;
    NEIGHBOURS(x)
        vec4 q = pos[j]; vec3 d = x - q.xyz; float dist = length(d), rr = r + q.w;
        if (dist >= rr || dist < 1e-5) continue;
        vec3 nrm = d / dist; float pen = rr - dist;
        float wj = asleep(uint(j)) ? 0.0 : 1.0 / (q.w * q.w * q.w), share = wi / (wi + wj);
        corr += share * max(0.0, pen - SLOP) * nrm;
        vec3 rel = moved - (q.xyz - prev[j].xyz); vec3 rt = rel - dot(rel, nrm) * nrm; float lt = length(rt);
        if (lt > 1e-6) fric -= share * rt * (lt < muS * pen ? 1.0 : min(muK * pen / lt, 1.0));
        cntc += 1.0;
    END_NEIGHBOURS
    x += relax * (corr + fric * (cntc >= 2.0 ? 1.0 : 0.15)) / max(cntc, 1.0);
    posOut[i] = vec4(walls(x, r, moved), r);
}"""
K["vel"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i]; if (p.w < 0.0) return;
    velOut[i] = vec4((p.xyz - prev[i].xyz) / dt, 0.0);
}"""
K["finish"] = """void main() {
    uint i = gl_GlobalInvocationID.x; if (i >= uint(n)) return;
    vec4 p = pos[i];
    if (p.w < 0.0) { vel[i] = velOut[i]; return; }
    vec3 x = p.xyz; float r = p.w, wi = 1.0 / (r * r * r);
    vec3 v = velOut[i].xyz, v0 = vpre[i].xyz, dv = vec3(0.0), nav = vec3(0.0);
    float occ = 0.0, cntc = 0.0, below = 0.0, still = 2.0 * g * dt; bool hit = false;
    NEIGHBOURS(x)
        vec4 q = pos[j]; vec3 d = x - q.xyz; float dist = length(d), rr = r + q.w;
        if (q.y < x.y - 0.4 * r && dist < rr * 1.3) occ += 1.0;
        if (dist >= rr * 1.02 || dist < 1e-5) continue;
        vec3 nrm = d / dist; float wj = 1.0 / (q.w * q.w * q.w), share = wi / (wi + wj);
        float vnPre = dot(v0 - vpre[j].xyz, nrm), vnNow = dot(v - velOut[j].xyz, nrm);
        if (vnPre < -still) dv += share * nrm * (-e * vnPre - vnNow);
        if (length(velOut[j].xyz) > 2.0 * vrest) hit = true;
        if (nrm.y < -0.3) below += 1.0;
        nav += nrm; cntc += 1.0;
    END_NEIGHBOURS
    float fy = floorY(x.x, t);
    if (x.y + r > fy - 0.05) {
        if (v0.y > still) dv.y += -eFloor * v0.y - v.y;
        nav += vec3(0.0, -1.0, 0.0); cntc += 1.0; below += 2.0;
    }
    v += dv / max(1.0, cntc * 0.5);
    bool calm = below >= 2.0 && vpre[i].w < QUIET && level < 0.01 && length(v) < vrest && !hit;
    if (calm) v = vec3(0.0);
    rest[i] = calm ? rest[i] + 1.0 : 0.0;
    vel[i] = vec4(v, occ);
    vec3 w = spin[i].xyz;
    if (cntc > 0.0) w = mix(w, cross(normalize(nav), v) / r, 0.6); else w *= 0.995;
    vec4 qo = ori[i];
    qo = normalize(vec4(qo.xyz + 0.5 * dt * (qo.w * w + cross(w, qo.xyz)), qo.w - 0.5 * dt * dot(w, qo.xyz)));
    spin[i] = vec4(w, cntc); ori[i] = qo;
}"""
# the drawn grains: each simulated grain as ksub film-size grains inside its ball, turning with it, loosening into a
# short stream along its path in flight; three vec4 per drawn grain for the renderer's instances
K["pack"] = """float h1(float k) { return fract(sin(k * 12.9898) * 43758.5453); }
vec3 qrot(vec4 q, vec3 v) { return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v); }
void main() {
    uint m = gl_GlobalInvocationID.x; if (m >= uint(n * ksub)) return;
    uint i = m / uint(ksub); int k = int(m % uint(ksub));
    vec4 p = pos[i];
    if (p.w < 0.0) { inst[m * 3u] = vec4(0.0, 0.0, 0.0, -1.0); return; }
    float fk = float(int(i) * 16 + k) + 0.5;
    vec3 off = vec3(h1(fk * 1.37 + 0.11), h1(fk * 2.71 + 0.53), h1(fk * 0.97 + 0.29)) * 2.0 - 1.0;
    float rs = p.w / gscale * (0.85 + 0.3 * h1(fk * 5.3 + 0.2));
    off = normalize(off + vec3(1e-4)) * max(0.0, p.w - rs) * pow(h1(fk * 3.1 + 0.7), 0.33);
    vec3 c = p.xyz + qrot(ori[i], off);
    vec3 v = vel[i].xyz; float sp = length(v);
    float fly = (spin[i].w < 0.5 ? 1.0 : 0.0) * clamp((sp - 120.0) / 500.0, 0.0, 1.0);
    if (fly > 0.0) { c += off * (spread * fly); c -= v / max(sp, 1e-3) * (h1(fk * 7.7 + 0.4) * trail * fly * p.w * 2.0); }
    c.z = clamp(c.z, rs, D - rs);
    inst[m * 3u] = vec4(c, rs);
    inst[m * 3u + 2u] = vec4(clamp(1.0 - (vel[i].w * 0.7 + float(k) * 0.25) * 0.07, 0.3, 1.0), h1(fk * 9.1), 0.0, 0.0);
}"""
for name, body in K.items():
    open(os.path.join(OUT, name + ".comp"), "w").write(HEAD + "\n" + body + "\n")

VERT = """#version 440
layout(location = 0) in vec2 corner;                 // the quad, -1..1
layout(location = 1) in vec4 ctr;                    // centre xyz, radius (< 0: none)
layout(location = 2) in vec4 tint;                   // colour, glint strength
layout(location = 3) in vec4 shade;                  // occlusion shade, random
layout(std140, binding = 0) uniform Draw { mat4 mvp; float W; float H; float D; float px; };
layout(location = 0) out vec2 uv;
layout(location = 1) out vec4 vtint;
layout(location = 2) out vec4 vshade;
layout(location = 3) out float back;
void main() {
    if (ctr.w <= 0.0) { gl_Position = vec4(9.0, 9.0, 9.0, 1.0); return; }
    float r = ctr.w + 0.5 * px;                        // half a pixel more, for the soft edge
    vec2 q = ctr.xy + corner * r;
    gl_Position = mvp * vec4(q.x / W * 2.0 - 1.0, 1.0 - q.y / H * 2.0, ctr.z / 100.0, 1.0);
    uv = corner * r / ctr.w; vtint = tint; vshade = vec4(shade.x, shade.y, px / ctr.w, 0.0); back = exp(-ctr.z / 22.0);
}
"""
FRAG = """#version 440
layout(location = 0) in vec2 uv;
layout(location = 1) in vec4 vtint;
layout(location = 2) in vec4 vshade;
layout(location = 3) in float back;
layout(location = 0) out vec4 frag;
layout(std140, binding = 0) uniform Draw { mat4 mvp; float W; float H; float D; float px; };
const vec3 L = normalize(vec3(-0.32, -0.86, -0.4));
const vec3 SUN = vec3(2.0, 1.82, 1.6), SKY = vec3(0.26, 0.24, 0.24), DEEP = vec3(0.0168, 0.0116, 0.0089);
vec3 aces(vec3 x) { return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }   // the film's tone curve
void main() {
    float aa = vshade.z, rr = length(uv); if (rr > 1.0 + 0.5 * aa) discard;
    float nz = sqrt(max(0.0, 1.0 - rr * rr));
    vec3 n = normalize(vec3(uv.x, uv.y, -nz - 1e-3) + (vec3(vshade.y, fract(vshade.y * 7.0), fract(vshade.y * 13.0)) - 0.5) * 0.4);
    float diff = max(0.0, dot(n, L) * 0.78 + 0.22);
    vec3 h = normalize(L + vec3(0.0, 0.0, -1.0)); float nh = max(0.0, dot(n, h));
    float spec = (pow(nh, 40.0) * 0.35 + pow(nh, 600.0) * 9.0) * vtint.a;
    vec3 c = vtint.rgb * (SKY * vshade.x * (0.55 + 0.45 * back) + SUN * diff * (0.45 + 0.55 * back)) + SUN * spec * 0.5;
    c = mix(DEEP, c, 0.35 + 0.65 * back) * (0.66 + 0.34 * nz);
    // as the film: ACES, highlights a touch warmer and shadows cooler, a little contrast, gamma
    c = aces(max(c, vec3(0.0)));
    float lum = (c.r + c.g + c.b) / 3.0;
    c = clamp((c + (lum - 0.35) * vec3(0.04, 0.014, -0.034) - 0.5) * 1.06 + 0.5, 0.0, 1.0);
    c = pow(c, vec3(1.0 / 2.2));
    float a = clamp((1.0 - rr) / max(aa, 1e-3) + 0.5, 0.0, 1.0);    // a pixel-wide soft edge
    frag = vec4(c * a, a);
}
"""
open(os.path.join(OUT, "grain.vert"), "w").write(VERT)
open(os.path.join(OUT, "grain.frag"), "w").write(FRAG)
print("shaders:", len(os.listdir(OUT)), "in", OUT)
