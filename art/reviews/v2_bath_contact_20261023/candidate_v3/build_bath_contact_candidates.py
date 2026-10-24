"""INERT collision LOD candidates from native owners; never rewrite visual GLBs.

Run once in Blender for both bathroom families. Bidirectional vertex and face
centroid distances bound sampled error; actual openings/contact remain a runtime
verification responsibility. Candidates are not installed by this script.
"""
import bpy
import json
import hashlib
from pathlib import Path
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
REVIEW=ROOT/'art/reviews/v2_bath_contact_20261023'
REVIEW.mkdir(parents=True,exist_ok=True)

def geometry(obj):
    mesh=obj.data
    mesh.calc_loop_triangles()
    verts=[obj.matrix_world@v.co for v in mesh.vertices]
    faces=[tuple(t.vertices) for t in mesh.loop_triangles]
    return verts,faces

def samples(verts,faces):
    return verts+[(verts[a]+verts[b]+verts[c])/3 for a,b,c in faces]

def deviation(points,tree):
    return max((tree.find_nearest(p)[3] for p in points),default=0.)

results=[]
for family,parent in [('bath_lavatory','CastAndPlumbing'),('bath_water_closet','WaterClosetCasting')]:
    source=ROOT/f'art/blender/{family}.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source))
    fixed=bpy.data.objects[parent]
    originals=[obj for obj in fixed.children_recursive if obj.type=='MESH' and obj.name not in {'WaterSeal','StoredWater'}]
    copies=[]
    rows=[]
    for original in originals:
        evaluated=original.evaluated_get(bpy.context.evaluated_depsgraph_get())
        data=bpy.data.meshes.new_from_object(evaluated)
        candidate=bpy.data.objects.new(original.name+'_Contact',data)
        bpy.context.collection.objects.link(candidate)
        candidate.matrix_world=original.matrix_world.copy()
        source_vertices,source_faces=geometry(candidate)
        tree=BVHTree.FromPolygons(source_vertices,source_faces,all_triangles=True)
        accepted=False
        # Two-millimetre guides border the independently selectable lift rod.
        # A millimetre surface budget is too coarse for that access corridor.
        ratios=[1.] if original.name.startswith('LiftGuide') else [.12,.25,.50,1.]
        for ratio in ratios:
            bpy.ops.object.select_all(action='DESELECT')
            candidate.select_set(True);bpy.context.view_layer.objects.active=candidate
            # Restore untouched evaluated native data for each candidate.
            candidate.data=data.copy()
            if ratio<1. and len(source_faces)>96:
                mod=candidate.modifiers.new('Contact surface reduction','DECIMATE')
                mod.ratio=ratio;mod.use_collapse_triangulate=True
                bpy.ops.object.modifier_apply(modifier=mod.name)
            vertices,faces=geometry(candidate)
            reverse=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
            forward_error=deviation(samples(source_vertices,source_faces),reverse)
            reverse_error=deviation(samples(vertices,faces),tree)
            if max(forward_error,reverse_error)<=.002:
                accepted=True;break
        assert accepted,original.name
        candidate.data.materials.clear()
        copies.append(candidate)
        rows.append({'name':original.name,'triangles_before':len(source_faces),'triangles_after':len(faces),'ratio':ratio,'source_to_candidate_m':forward_error,'candidate_to_source_m':reverse_error})
    for obj in list(bpy.context.scene.objects):
        if obj not in copies:bpy.data.objects.remove(obj,do_unlink=True)
    native=ROOT/f'art/blender/{family}_contact.blend'
    target=ROOT/f'game/assets/props/{family}_contact.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(native))
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_yup=True,export_animations=False,export_materials='NONE',export_apply=True)
    results.append({'family':family,'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'asset':target.relative_to(ROOT).as_posix(),'asset_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'parts':rows})
report={'evidence_class':'INERT','source_bindings':{'art/blender/scripts/build_bath_contact_candidates.py':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest()},'families':results,'limits':'Two-way sampled error <=2 mm; exact LiftGuide stock preserves lift-rod access. Runtime installation and actual contact/input checks are separate evidence.'}
(REVIEW/'native_candidates.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(report))
