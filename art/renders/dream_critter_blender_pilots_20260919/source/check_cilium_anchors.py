"""Source-only manifest-anchor/actual evaluated root-group correspondence."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

parser=argparse.ArgumentParser(allow_abbrev=False)
parser.add_argument('--blend',required=True,type=Path)
parser.add_argument('--manifest',required=True,type=Path)
parser.add_argument('--out',required=True,type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
spec=importlib.util.spec_from_file_location('checker','C:/ov/astra-main-acdb4be/art/blender/scripts/check_dream_critter_anatomy.py')
checker=importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
path,before,c,objects,rig=checker.load_source(args.blend)
manifest=json.loads(args.manifest.read_text())
anchors=manifest['cilium_anchors']
assert len(anchors)==19 and all(len(row)==12 for row in anchors)
skin=objects['Skin']
weights=[]
for index in range(12):
    group=skin.vertex_groups['cilium_%d_root'%index]
    values=[next((g.weight for g in v.groups if g.group==group.index),0.) for v in skin.data.vertices]
    assert sum(values)>0
    weights.append(values)
bindings={}
for loop in skin.data.loops:
    x,y=skin.data.uv_layers['AnatomyBinding'].data[loop.index].uv
    binding=(float(x),1.-float(y)) # Same V convention as glTF TEXCOORD_1.
    if loop.vertex_index in bindings: assert bindings[loop.vertex_index]==binding
    bindings[loop.vertex_index]=binding
invalid_zero=[index for index,(identifier,weight) in bindings.items() if weight<=1e-7 and abs(identifier+1)>1e-7]
invalid_positive=[index for index,(identifier,weight) in bindings.items() if weight>1e-7 and (abs(identifier-round(identifier))>1e-6 or not -13<=identifier<=-2)]
records=[]
for pose_index,pose in enumerate(c['poses']):
    checker.apply_pose(c,objects,rig,pose)
    geometry=checker.evaluated_geometry(skin,bpy.context.evaluated_depsgraph_get())
    for index,values in enumerate(weights):
        centroid=sum((p*w for p,w in zip(geometry['points'],values)),Vector())/sum(values)
        centroid=Vector((centroid.x,centroid.z,-centroid.y))
        claimed=Vector(anchors[pose_index][index])
        records.append({'pose':pose['name'],'index':index,'claimed_godot':list(claimed),
                        'root_weighted_centroid_godot':list(centroid),'deviation':(claimed-centroid).length})
maximum=max(records,key=lambda r:r['deviation'])
result={'schema':'dream_critter_cilium_anchor_audit.v1','evidence_class':'INERT',
    'blend_sha256':before,'manifest_sha256':checker.sha256(args.manifest),
    'checker_sha256':checker.sha256(checker.__file__),'script_sha256':checker.sha256(__file__),
    'max_deviation':maximum,'records':records,'checked_anchor_states':len(records),
    'uv1':{'vertices':len(bindings),'invalid_zero_weight_ids':invalid_zero,'invalid_positive_bindings':invalid_positive},
    'source_unchanged':checker.sha256(path)==before,
    'limitations':['Weighted semantic root-group centroid correspondence only; native10/11/12 collapsed branch fan and rendered surface remain separate checks.',
                   'Coordinates are normalized source-template units, not final controller dimensions.']}
checker.write_report(args.out,result)
print('[CILIUM ANCHORS]',len(records),'max_deviation',maximum['deviation'],'pose',maximum['pose'],'bundle',maximum['index'])
