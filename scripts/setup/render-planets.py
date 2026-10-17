# Setup's profile pictures: planets from the trailer's renderer (horizon_gl.py), framed so the surface fills
# about three quarters of the circle, lit from the same side, then evened out to one exposure.
import sys, os, time, subprocess, numpy as np, moderngl
os.environ.setdefault("HZ_W", "640"); os.environ.setdefault("HZ_H", "640")
sys.path.insert(0, os.path.expanduser("~/book4-edge/demo"))
import horizon_gl as hz
out = sys.argv[1]; names = sys.argv[2:] or ["dune", "terracotta", "moss", "rust", "basalt", "marble", "copper", "glaze"]
os.makedirs(out, exist_ok=True)
ctx = moderngl.create_standalone_context(backend="egl", require=330)
prog = ctx.program(vertex_shader="#version 330 core\nin vec2 p; void main(){ gl_Position = vec4(p, 0, 1); }",
                   fragment_shader=open(os.path.join(hz.HERE, "horizons.glsl")).read())
vao = ctx.vertex_array(prog, [(ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], "f4").tobytes()), "2f", "p")])
cam = hz.camera(apex=0.55)            # the horizon high in the square: mostly surface
M = hz.mats(cam)
for n in names:
    m = dict(M[n])
    m["sunD"] = hz.sun(cam, -0.6, 0.7, 0.2)     # one light for all: from the upper left, a little behind
    t0 = time.time()
    img = hz.finish(hz.render(ctx, prog, vao, cam, m, 48))
    lum = float((img[..., 0] * .2126 + img[..., 1] * .7152 + img[..., 2] * .0722).mean())
    img = np.clip(img * (0.42 / max(lum, 1e-3)) ** 0.6, 0, 1)   # toward one exposure (mean ~0.42), not all the way
    hz.save(img, f"{out}/{n}.png")
    print(n, f"{time.time() - t0:.1f}s mean {lum:.2f}", flush=True)
