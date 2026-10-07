"""Read-only native UV review queue. Run with Blender; findings are not acceptance."""
from pathlib import Path
import argparse, hashlib, json, sys
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--family', action='append')
parser.add_argument('--native-dir', help='Optional comparison natives with the same stock identities; reads only.')
parser.add_argument('--out', default='tmp/v2-finish-review/grain-audit.json')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
# These actual catalogue albedos were visually checked: sawn timber runs U,
# the locked walnut map runs V. Unknown maps are deliberately not inferred.
TEXTURE_AXES = {'T_ai_materials_timber_albedo.png': 0,
                'T_library_furniture_walnut_albedo.png': 1}
results = []
for report in sorted((ROOT/'art/blender').glob('*_construction.json')):
 family = report.stem.removesuffix('_construction')
 if args.family and family not in args.family: continue
 native = report.with_name(family+'.blend')
 if args.native_dir: native = Path(args.native_dir).resolve()/(family+'.blend')
 fixture = json.loads(report.read_text(encoding='utf-8'))
 if not native.is_file() or not isinstance(fixture,dict) or not all(isinstance(fixture.get(key),list) for key in ['closed_stocks','parts']): continue
 bpy.ops.wm.open_mainfile(filepath=str(native))
 draws = {}
 for part in fixture['parts']:
  if not all(key in part for key in ['name','assembly','key']): continue
  obj = bpy.data.objects.get(part['name'])
  if obj is None or obj.type != 'MESH' or obj.data.uv_layers.active is None: continue
  images = [Path(bpy.path.abspath(n.image.filepath)).name for mat in obj.data.materials
            if mat and mat.use_nodes for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]
  axis = next((TEXTURE_AXES[name] for name in images if name in TEXTURE_AXES), None)
  if axis is None: continue
  mesh = obj.data; mesh.calc_loop_triangles()
  points = np.asarray([tuple(obj.matrix_world@v.co) for v in mesh.vertices])
  indices = [tuple(t.vertices) for t in mesh.loop_triangles]
  uv = np.asarray([[tuple(mesh.uv_layers.active.data[i].uv) for i in t.loops] for t in mesh.loop_triangles])
  tree = BVHTree.FromPolygons([Vector(p) for p in points], indices, all_triangles=True)
  draws[(part['assembly'],part['key'])] = (points,np.asarray(indices),uv,tree,axis)
 checked = []; skipped = 0
 for stock in fixture['closed_stocks']:
  if not isinstance(stock,dict) or not all(key in stock for key in ['assembly','key','name']):
   skipped += 1; continue
  draw = draws.get((stock['assembly'],stock['key'])); obj = bpy.data.objects.get(stock['name'])
  if draw is None or obj is None: continue
  pts = np.asarray([tuple(obj.matrix_world@v.co) for v in obj.data.vertices])
  _, singular, basis = np.linalg.svd(pts-pts.mean(axis=0), full_matrices=False)
  if singular[1] <= 0 or singular[0]/singular[1] < 3: continue
  length = basis[0]; obj.data.calc_loop_triangles(); samples = []
  candidates = sorted(obj.data.loop_triangles,key=lambda t:t.area,reverse=True)[:16]
  points,indices,uv,tree,axis = draw
  for triangle in candidates:
   p = pts[list(triangle.vertices)]; cross = np.cross(p[1]-p[0],p[2]-p[0]); area = np.linalg.norm(cross)*.5
   if area < 1e-7: continue
   normal = cross/(2*area); projected = length-normal*np.dot(length,normal)
   if np.linalg.norm(projected) < .5: continue  # End grain is a different question.
   nearest = tree.find_nearest(Vector(p.mean(axis=0)))
   if nearest[0] is None or nearest[3] > .00004 or abs(np.dot(normal,nearest[1])) < .99: continue
   i = nearest[2]; q = points[indices[i]]; d = np.stack((uv[i,1]-uv[i,0],uv[i,2]-uv[i,0]),axis=1)
   if abs(np.linalg.det(d)) < 1e-12: continue
   derivative = np.stack((q[1]-q[0],q[2]-q[0]),axis=1)@np.linalg.inv(d)
   grain = derivative[:,axis]; alignment = abs(np.dot(grain/np.linalg.norm(grain),projected/np.linalg.norm(projected)))
   samples.append((alignment,area))
  if len(samples) < 2: skipped += 1; continue
  score = sum(dot*area for dot,area in samples)/sum(area for _,area in samples)
  checked.append({'stock':stock['name'],'key':stock['key'],'alignment':round(float(score),5),
                  'samples':len(samples),'review':bool(score < .90)})
 row = {'family':family,'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),
        'checked':len(checked),'unmeasured':skipped,'review':sum(x['review'] for x in checked),'stocks':checked}
 results.append(row)
 print('GRAIN REVIEW',family,'checked',row['checked'],'review',row['review'],flush=True)
out = ROOT/args.out; out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps({'evidence_class':'INERT','method':'Area-weighted UV grain versus principal length on slender stocks; end grain and unknown maps excluded. Findings require rendered review, not automatic rebuilding.','texture_axes':TEXTURE_AXES,'families':results},indent=2)+'\n',encoding='utf-8',newline='\n')
