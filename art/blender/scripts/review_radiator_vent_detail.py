"""Sample the actual refined vent walls, needle seat and five air routes.

Reuses the native kit's mechanical assertions against the changed meshes;
does not execute its builder or write the reviewed native file.
"""
import argparse
import ast
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--native',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(args.native.resolve()))
body,cap,float_bell=[bpy.data.objects[name] for name in ('VentBody','VentCap','FloatAndNeedle')]
inserts={i:bpy.data.objects['VentOrificeInsert_%d'%i] for i in range(5)}
x=.043;seat=.0602;travel=.0055;weights=[.3,.48,.72,1.,1.32];checks=[]
source=ROOT/'art/reviews/v2_radiator_native_20261017/native_recipe/automatic_vent.py'
nodes=ast.parse(source.read_text()).body
definitions=[node for node in nodes if isinstance(node,ast.FunctionDef) and node.name in ('tree','check')]
start=next(i for i,node in enumerate(nodes) if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='body_tree' for t in node.targets))
end=next(i for i,node in enumerate(nodes) if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='native' for t in node.targets))
exec(compile(ast.Module(body=definitions+nodes[start:end],type_ignores=[]),str(source),'exec'))
for obj in [body,cap,float_bell,*inserts.values()]:
    bm=bmesh.new();bm.from_mesh(obj.data);bm.normal_update()
    check('refined stock retains closed walls',all(e.is_manifold for e in bm.edges),id=obj.name)
    check('refined stock retains positive material volume',bm.calc_volume(signed=True)>0,id=obj.name)
    pending=set(bm.faces);components=[]
    while pending:
        component={pending.pop()};queue=list(component)
        while queue:
            for edge in queue.pop().edges:
                for peer in edge.link_faces:
                    if peer in pending:pending.remove(peer);component.add(peer);queue.append(peer)
        components.append(component)
    check('refined stock retains intended shell count',len(components)==(2 if obj==float_bell else 1),id=obj.name)
    if obj==float_bell and len(components)==2:
        volumes=[sum(face.verts[0].co.dot(face.verts[1].co.cross(face.verts[2].co))/6 for face in component) for component in components]
        inner=components[volumes.index(min(volumes))]
        check('sealed float cavity normals face into its void',min(volumes)<0 and max(volumes)>0)
        check('sealed cavity retains its nested inner envelope',all(((v.co.x-x)/.0074)**2+(v.co.y/.0074)**2+((v.co.z-.022)/.0164)**2<=1.0001 for face in inner for v in face.verts))
    bm.free()
args.out.parent.mkdir(parents=True,exist_ok=True)
report=dict(evidence_class='INERT',scope='Native refined vent fit and routed-air samples only; no runtime or fluid simulation proof.',
            native_sha256=hashlib.sha256(args.native.read_bytes()).hexdigest(),
            assertion_source_lf_sha256=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
            checks=checks,failures=[row for row in checks if not row['passed']])
args.out.write_text(json.dumps(report,indent=2)+'\n')
print('REFINED VENT FIT:',len(checks),'checks;',len(report['failures']),'failures',flush=True)
if report['failures']:raise RuntimeError(report['failures'])
