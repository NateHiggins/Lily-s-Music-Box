"""Preflight the five complete foot areas and conservative Vantry cabinet envelopes."""
from pathlib import Path
import json, math
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

r = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
data = json.loads((r/'game/data/orison_v2/task_lamp_installations.json').read_text())
furniture = {x['id']: x for x in json.loads((r/'game/data/orison_v2/domestic_furniture.json').read_text())['furniture']}
nook = json.loads((r/'game/data/orison_v2/reading_nook.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/reading_nook.blend'))
table = next(x for x in nook['assemblies'] if x['id']=='nook_table')
def bp(p): return Vector((p[0], -p[2], p[1]))
def pose(p, yaw): return Matrix.Translation(bp(p)) @ Matrix.Rotation(yaw, 4, 'Z')
table_inverse = pose(table['position'], table['yaw']).inverted()
def tree(obj, transform=Matrix.Identity(4)):
    return BVHTree.FromPolygons([transform@obj.matrix_world@v.co for v in obj.data.vertices], [list(p.vertices) for p in obj.data.polygons])
bpy.context.view_layer.update()
table_trees = [tree(o, table_inverse) for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('nook_table__')]
nook_neighbours = [(o.name,tree(o,table_inverse)) for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render and not o.name.startswith(('nook_table__','nook_rug__'))]
with bpy.data.libraries.load(str(r/'art/blender/task_lamps.blend'), link=False) as (src,dst):
    dst.objects = [n for n in src.objects if n.startswith('TaskLamp_') and '__' in n]
lamps = dst.objects
for obj in lamps: bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.update()

def support_tree(row, transform=Matrix.Identity(4)):
    points=[];faces=[]
    for surface in row['surfaces']:
        vertices=surface['vertices']; normals=surface['normals']
        for i in range(0,len(vertices),9):
            tri=[bp(vertices[i+j:i+j+3]) for j in (0,3,6)]
            ids=list(range(len(points),len(points)+3))
            if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(bp(normals[i:i+3]))<0: ids.reverse()
            points.extend(transform@point for point in tri);faces.append(ids)
    return BVHTree.FromPolygons(points, faces)

radii={'emeralite':.095,'office_green':.078,'bench_friction':.110,'landlord_enamel':.082,'architect_counterweight':.112}
results=[]; neighbour_checks=[]
surface_props=json.loads((r/'game/data/orison_v2/domestic_surface_props.json').read_text())['props']
for row in data['lamps']:
    trees=table_trees if row['support']=='nook_table' else [support_tree(furniture[row['support']])]
    radius=radii[row['variant']]; center=bp(row['position'])
    points=[center]+[center+Vector((radius*f*math.cos(i*math.tau/64),radius*f*math.sin(i*math.tau/64),0)) for f in (.33,.67,1.) for i in range(64)]
    misses=[]
    for point in points:
        hits=[bvh.ray_cast(point+Vector((0,0,.004)),Vector((0,0,-1)),.008) for bvh in trees]
        if not any(at is not None and (at-point).length<.00003 and normal.z>.99 for at,normal,_,_ in hits): misses.append(list(point))
    assert not misses,(row['id'],misses)
    results.append({'id':row['id'],'support':row['support'],'radius':radius,'samples':len(points),'maximum_allowed_error_m':.00003})
    lamp_trees=[(o.name,tree(o,pose(row['position'],row['yaw']))) for o in lamps if o.name.startswith('TaskLamp_'+row['variant']+'__')]
    neighbours=nook_neighbours if row['support']=='nook_table' else [(p['id'],support_tree(p,pose(p['position'],p['yaw']))) for p in surface_props if p['support']==row['support']]
    for identity,bvh in neighbours:
        overlaps=[name for name,other in lamp_trees if bvh.overlap(other)]
        assert not overlaps,(row['id'],identity,overlaps)
        neighbour_checks.append({'lamp':row['id'],'neighbour':identity,'surface_crossings':0})

# Conservative envelopes for the original terminal's physical stock, in its
# actual production orientation (local +X faces the unchanged west stance).
# The native lamp must clear even these enclosing volumes before engine QA.
script=(r/'game/scripts/props/signal_terminal_prop.gd').read_text(encoding='utf-8')
assert 'Vector3(0.38, 0.27, 1.02), Vector3(0, 0.135, 0)' in script
assert 'Vector3(0.40, 0.035, 1.06), Vector3(-0.01, 0.018, 0)' in script
envelopes=[('cabinet',(.38,.27,1.02),(0,.135,0)),('foot',(.40,.035,1.06),(-.01,.018,0)),('bridge',(.25,.055,.62),(-.055,.315,0)),('valve_guard',(.28,.22,.62),(-.055,.385,0)),('handset',(.11,.13,.40),(-.02,.315,.43)),('front_skin',(.018,.225,.94),(.199,.142,0)),('scope_bezel',(.035,.245,.245),(.211,.165,-.255))]
for z, radius in [(-.405,.030),(-.035,.041),(.420,.030)]: envelopes.append(('knob_'+str(z),(.035,radius*2,radius*2),(.225,.078,z)))
for z in [.045,.265]: envelopes.append(('meter_'+str(z),(.031,.115,.175),(.216,.190,z)))
envelopes.append(('patch_field',(.038,.09,.385),(.222,.065,.215)))
terminal_at=Vector((.075,.75,0));terminal_pose=pose(terminal_at,math.pi)
row=next(x for x in data['lamps'] if x['id']=='F04_B_LAMP_01')
lamp_pose=pose(row['position'],row['yaw'])
lamp_trees=[(o.name,tree(o,lamp_pose)) for o in lamps if o.name.startswith('TaskLamp_landlord_enamel__')]
clear=[]
for name,size,at in envelopes:
    vertices=[terminal_pose@bp([at[i]+sign[i]*size[i]*.5 for i in range(3)]) for sign in [(-1,-1,-1),(1,-1,-1),(-1,1,-1),(1,1,-1),(-1,-1,1),(1,-1,1),(-1,1,1),(1,1,1)]]
    bvh=BVHTree.FromPolygons(vertices,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)])
    overlaps=[label for label,other in lamp_trees if bvh.overlap(other)]
    assert not overlaps,(name,overlaps)
    clear.append(name)
output={'evidence_class':'INERT','bearings':results,'neighbours':neighbour_checks,'terminal_clear_envelopes':clear,'scope':'Complete circular foot samples, actual tabletop neighbours and conservative native terminal clearance; engine rendering and physical input remain required.'}
path=r/'tmp/v2-finish-review/task-lamp-installations-native.json';path.write_text(json.dumps(output,indent=2)+'\n')
print('TASK LAMP INSTALLATIONS:',sum(x['samples'] for x in results),'foot samples;',len(clear),'terminal envelopes clear')
