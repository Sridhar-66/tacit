# Setup's ground, second pass: the trailer's rim at the trailer's strength. The edge keeps its full light on
# every screen (the first pass dimmed it to 45 % early on, which read as weak); the progress is the air above it,
# which thickens step by step. Framed like the trailer, only lower: the apex at about 78 % of the height.
import sys, os, time, numpy as np, moderngl
sys.path.insert(0, os.path.expanduser("~/book4-edge/demo"))
import horizon_gl as hz
out = sys.argv[1]; spp = int(sys.argv[2]) if len(sys.argv) > 2 else 160
only = sys.argv[3:]
os.makedirs(out, exist_ok=True)
ctx = moderngl.create_standalone_context(backend="egl", require=330)
prog = ctx.program(vertex_shader="#version 330 core\nin vec2 p; void main(){ gl_Position = vec4(p, 0, 1); }",
                   fragment_shader=open(os.path.join(hz.HERE, "horizons.glsl")).read())
vao = ctx.vertex_array(prog, [(ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], "f4").tobytes()), "2f", "p")])
cam = hz.camera(apex=-0.56)
base = hz.mats(cam)["rim"]
# (edge light, air) per screen: welcome .. ready
steps = [(1.0, 0.70), (1.0, 0.80), (1.05, 0.90), (1.1, 1.0), (1.15, 1.12), (1.2, 1.26), (1.3, 1.45)]
for i, (edge, air) in enumerate(steps):
    name = f"rim2-{i + 1}"
    if only and name not in only:
        continue
    m = dict(base, cam=cam, stars=0.3)
    m["sunC"] = (base["sunC"][0], base["sunC"][1] * edge)
    m["haze"] = (base["haze"][0], base["haze"][1], base["haze"][2] * air)
    m["haze2"] = (base["haze2"][0], base["haze2"][1], base["haze2"][2] * air)
    t0 = time.time()
    hz.save(hz.finish(hz.render(ctx, prog, vao, cam, m, spp)), f"{out}/{name}.png")
    print(name, f"{time.time() - t0:.1f}s", flush=True)
