#!/usr/bin/env python3
"""Fill in build/web/sw.js with this build's version and file lists."""
import hashlib, json, os, sys

root = sys.argv[1] if len(sys.argv) > 1 else 'build/web'
files = []
for d, _, names in os.walk(root):
    for n in names:
        p = os.path.relpath(os.path.join(d, n), root).replace(os.sep, '/')
        if (p in ('sw.js', 'flutter_service_worker.js') or p.endswith(('.map', '.symbols'))
                or p.startswith(('splash/', 'canvaskit/skwasm', 'canvaskit/wimp'))):
            continue
        files.append(p)
files.sort()

h = hashlib.sha256()
for p in files:
    with open(os.path.join(root, p), 'rb') as f:
        h.update(p.encode()); h.update(hashlib.sha256(f.read()).digest())
version = h.hexdigest()[:16]

LAZY = ('assets/assets/art/', 'assets/assets/food/', 'assets/assets/badges/')

def core(p):
    # Big image folders are fetched in the background after first launch.
    if p.startswith(LAZY):
        return False
    if p.startswith('canvaskit/') and p not in ('canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm'):
        return False
    return True

core_list = ['./'] + [p for p in files if core(p)]
sw_path = os.path.join(root, 'sw.js')
with open(sw_path) as f:
    sw = f.read()
sw = (sw.replace("'__VERSION__'", json.dumps(version))
        .replace('__CORE__', json.dumps(core_list))
        .replace('__ALL__', json.dumps(files)))
with open(sw_path, 'w') as f:
    f.write(sw)
size = sum(os.path.getsize(os.path.join(root, p)) for p in core_list[1:])
print(f'sw.js version {version}: {len(core_list)} core files ({size/1e6:.1f} MB), {len(files)} total')
