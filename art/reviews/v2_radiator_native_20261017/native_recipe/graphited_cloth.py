"""Author a small periodic graphited-fibre PBR prototype, not runtime stock."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image
P = output_directory() / 'graphited_cloth'
P.mkdir(exist_ok=True)
size = 256
tile = 0.008
threads = 16
y, x = np.mgrid[:size, :size] / size
warp = np.cos(x * threads * 2 * np.pi)
weft = np.cos(y * threads * 2 * np.pi)
cross = np.cos(x * threads * np.pi) * np.cos(y * threads * np.pi)
height = (warp * (0.5 + 0.35 * cross) + weft * (0.5 - 0.35 * cross)) * 0.25 + 0.5
fibre = np.sin(2 * np.pi * (x * 64 + y * 32)) * 0.04
height = np.clip(height + fibre, 0, 1)
albedo = np.clip(np.array([43, 44, 43])[None, None, :] + (height - 0.5)[..., None] * 5, 0, 255)
rough = np.clip(0.83 + (height - 0.5) * 0.08, 0.76, 0.9)
relief = 6e-05
dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * relief * size * 0.5 / tile
dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * relief * size * 0.5 / tile
normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
normal /= np.linalg.norm(normal, axis=-1)[..., None]
for name, data in [('albedo', albedo), ('roughness', rough * 255), ('normal', (normal * 0.5 + 0.5) * 255), ('height', height * 255)]:
    Image.fromarray(np.rint(data).astype('uint8')).save(P / (name + '.png'))
report = dict(evidence_class='INERT', scope='Unregistered procedural graphited fibre preview; no runtime import or acceptance.', material='graphited_packing', generator=Path(__file__).name, source=__doc__, meters_per_tile=tile, relief_m=relief, normal_convention='OpenGL', metallic=0, roughness_range=[float(rough.min()), float(rough.max())], maps={n: n + '.png' for n in ['albedo', 'roughness', 'normal', 'height']}, map_sha256={n: hashlib.sha256((P / (n + '.png')).read_bytes()).hexdigest() for n in ['albedo', 'roughness', 'normal', 'height']})
(P / 'material.json').write_text(json.dumps(report, indent=2) + '\n')
print('PACKING MAPS', size, 'px', tile, 'm tile', flush=True)
