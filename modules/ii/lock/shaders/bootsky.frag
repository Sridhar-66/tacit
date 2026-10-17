#version 440
// Tacit's boot sky: a planet's limb in the person's own colours, their picture as its surface, lit from the edge
// when the sun comes up. The maths of the approved mockup (~/book4-edge/tacit-boot-mocks/ease7.py), per pixel:
// an atmosphere that falls off continuously from the limb (four exponentials, the tightest warm sunlight), all of it
// added as light in linear space, a soft shoulder above 0.55 that leaves the picture itself untouched, then film
// grain (overlay), a slight flicker, a vignette and a one-step dither so the dark gradients never band.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;           // px
    float domeTop;      // the dome's top, px from the top
    float radius;       // px
    float push;         // camera push about the dome's top (1 = none)
    float sun;          // 0..1 the sunrise gathering at the crest
    float day;          // 0..1 daylight on the surface, edge first
    float halo;         // 0..1 the atmosphere (0 once the dome has left the screen)
    float film;         // 0..1 grain, flicker and vignette
    float frame;        // for the grain and the flicker
    float fade;         // 1, down to 0 at the end of the dusk (black)
    vec4 sky;           // rgb, linear
    vec4 glow0;         // rgb linear, a = strength; widths in `widths`
    vec4 glow1;
    vec4 glow2;
    vec4 glow3;
    vec4 widths;        // px, glow0..3
};
layout(binding = 1) uniform sampler2D ground;   // the lock ground, sRGB

const vec3 HAIR = vec3(1.0, 0.905, 0.787);       // #fff4e6, linear
const vec3 CORE = vec3(1.0, 0.877, 0.716);       // #fff1dc, linear
const float NIGHT = 0.035;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 toLin(vec3 c) { return pow(c, vec3(2.2)); }
vec3 shoulder(vec3 x) {
    const float k = 0.55;
    vec3 over = max(x - k, 0.0);
    return mix(x, k + (1.0 - k) * over / (over + (1.0 - k)), step(k, x));
}
float layer(float d, float w) { return d >= 0.0 ? exp(-d / w) : 0.5 * exp(d / (0.5 * w)); }

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec2 q = vec2((p.x - res.x * 0.5) / push + res.x * 0.5, (p.y - domeTop) / push + domeTop);
    float d = length(q - vec2(res.x * 0.5, domeTop + radius)) - radius;     // + outside the dome
    d /= res.y / 1080.0;                 // the light's widths are drawn for 1080 lines: the same look on any panel
    float inn = max(-d, 0.0);

    vec3 glow = glow0.rgb * glow0.a * layer(d, widths.x) + glow1.rgb * glow1.a * layer(d, widths.y)
              + glow2.rgb * glow2.a * layer(d, widths.z) + glow3.rgb * glow3.a * layer(d, widths.w);
    glow *= 1.0 + 0.7 * sun;
    glow += HAIR * 1.4 * exp(-abs(d) / 1.1) * (1.0 + 0.5 * sun);
    float xn = (p.x - res.x * 0.5) / (0.26 * res.x);
    glow += CORE * 1.3 * sun * exp(-xn * xn) * exp(-abs(d) / 30.0);

    float L = NIGHT + (1.0 - NIGHT) * clamp(day * (1.0 + 0.7 * exp(-inn / 420.0)), 0.0, 1.0);
    vec3 body = toLin(texture(ground, q / res).rgb) * L;
    float cover = clamp(0.5 - d, 0.0, 1.0);
    vec3 img = sky.rgb * (1.0 - cover) + body * cover + glow * halo;

    // the shoulder fades out with the atmosphere, so the last frame is the lock ground itself
    img = mix(img, shoulder(max(img, 0.0)), halo);
    vec3 c = pow(clamp(img, 0.0, 1.0), vec3(1.0 / 2.2));

    if (film > 0.0) {
        vec2 cell = floor((p + vec2(hash(vec2(frame, 1.0)), hash(vec2(frame, 2.0))) * 128.0) / 2.0);
        float g = 0.5 + (hash(cell) + hash(cell + 17.3) + hash(cell + 41.7) - 1.5) * 0.59;
        vec3 ov = mix(2.0 * c * g, 1.0 - 2.0 * (1.0 - c) * (1.0 - g), step(0.5, c));
        c = mix(c, ov, 0.10 * film);
        c *= 1.0 + (hash(vec2(frame, 3.0)) - 0.5) * 0.02 * film;
        float v = clamp((length(p - res * 0.5) - res.y * 0.35) / (res.y * 0.70), 0.0, 1.0);
        c *= 1.0 - v * 0.25 * film;
    }
    c *= fade;
    c += (hash(p + frame) + hash(p.yx + frame * 1.7) - 1.0) / 255.0 * fade;
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
