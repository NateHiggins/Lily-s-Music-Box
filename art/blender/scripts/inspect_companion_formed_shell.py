"""Measure formed glazing clamps against retained native cartridge frames.

Native fit diagnostic only; reuses unchanged renders. No Godot invocation.
"""
from pathlib import Path
import argparse,json,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--source',required=True);parser.add_argument('--out',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
source=(ROOT/args.source).resolve();out=(ROOT/args.out).resolve()
assert source.is_relative_to((ROOT/'tmp').resolve()) and out.is_relative_to((ROOT/'tmp').resolve())
bpy.ops.wm.open_mainfile(filepath=str(source))
for image in bpy.data.images:
    if image.source=='FILE':assert Path(bpy.path.abspath(image.filepath)).is_file(),('missing native image',image.name)

def coords(p):return Vector((p[0],-p[2],p[1]))
def tree(objects):
    vertices=[];faces=[]
    for obj in objects:
        offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
    return BVHTree.FromPolygons(vertices,faces)
def ray(bvh,a,b,axis):
    start=coords(a);delta=coords(b)-start;point=bvh.ray_cast(start,delta.normalized(),delta.length)[0]
    assert point is not None,('missing physical bearing',a,b)
    return [point.x,point.z,-point.y][axis]

original=[o for o in bpy.data.collections['EditableIndividualStock'].objects if o.name.startswith('Stock__Cartridge side frame')]
assert len(original)==2,len(original)
old=tree(original)
frame=[o for o in bpy.data.collections['FormedShellStudy'].objects if o.name.startswith('Stock__Reading glass retaining frame')]
assert len(frame)==1,len(frame)
new=tree(frame);records=[]
formed=bpy.data.collections['FormedShellStudy']
def stock_tree(prefix):
    found=[obj for obj in formed.objects if obj.name.startswith('Stock__'+prefix)]
    assert len(found)==1,(prefix,len(found))
    return tree(found)
for side in [-1,1]:
    for y in [0.0,.076]:
        for dy in [-.002,.002]:
            # Offset from the screw bore to measure real bearing stock.
            for label,a,b,c,d in [
              ('outer',(.090,y+dy,.0528),(.079,y+dy,.0528),(.083,y+dy,.0528),(.090,y+dy,.0528)),
              ('inner',(.078,y+dy,.0528),(.087,y+dy,.0528),(.083,y+dy,.0528),(.078,y+dy,.0528))]:
                a,b,c,d=[(side*p[0],p[1],p[2]) for p in [a,b,c,d]]
                original_face=ray(old,a,b,0);clamp_face=ray(new,c,d,0)
                gap=abs(original_face-clamp_face)
                assert gap<.000005,('unseated reading clamp',side,y,label,gap)
                records.append(dict(side=side,y=y,face=label,gap_m=gap))
        a=(side*.083,y,.058);b=(side*.083,y,.052)
        c=(side*.083,y,.054);d=(side*.083,y,.057)
        gap=abs(ray(old,a,b,2)-ray(new,c,d,2))
        assert gap<.000005,('unseated clamp top',side,y,gap)
        records.append(dict(side=side,y=y,face='top',gap_m=gap))
bearing=stock_tree('Stepped bored reading shaft bearing')
shaft=tree([o for o in bpy.data.collections['EditableIndividualStock'].objects if o.name.startswith('Stock__Reading shaft')])
inner_radius=ray(bearing,(.109,.038,0),(.109,.048,0),1)-.038
shaft_radius=ray(shaft,(.109,.043,0),(.109,.038,0),1)-.038
assert abs(inner_radius-.00205)<.000005 and abs(shaft_radius-.0018)<.000005
assert inner_radius-shaft_radius>.0002
flange_back=ray(bearing,(.106,.0415,0),(.111,.0415,0),0)
leather_face=ray(stock_tree('One piece moulded leather jacket'),(.112,.0415,0),(.100,.0415,0),0)
assert abs(flange_back-leather_face)<.000005
records.append(dict(face='reading_bearing_flange',gap_m=abs(flange_back-leather_face)))
for name in ['Continuous pressed structural pan','One piece moulded leather jacket','Soft fitted liner return']:
    body=stock_tree(name);a=coords((.101,.038,0));b=coords((.111,.038,0));delta=b-a
    assert body.ray_cast(a,delta.normalized(),delta.length)[0] is None,('reading shaft crosses sealed stock',name)
pane=stock_tree('1.2 millimetre reading glass');rear_gasket=stock_tree('Glazing rear bearing flange')
glass_back=ray(pane,(.068,.038,.055),(.068,.038,.060),2)
gasket_front=ray(rear_gasket,(.068,.038,.058),(.068,.038,.055),2)
glass_front=ray(pane,(.068,.038,.061),(.068,.038,.055),2)
retainer_back=ray(new,(.068,.038,.0578),(.068,.038,.061),2)
for label,gap in [('glass_gasket',abs(glass_back-gasket_front)),('glass_retainer',abs(glass_front-retainer_back))]:
    assert gap<.000005,(label,gap)
    records.append(dict(face=label,gap_m=gap))
assert abs(glass_front-glass_back-.0012)<.000005
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(dict(evidence_class='INERT',scope='Native fit of four reading-window clamps, original cartridge frames, reading-shaft bearing and glass seats; no imported qualification',checks=len(records),maximum_gap_m=max(r['gap_m'] for r in records),reading_shaft_radial_clearance_m=inner_radius-shaft_radius,reading_shaft_clear_stock_layers=3,glass_thickness_m=glass_front-glass_back,records=records),indent=2)+'\n',newline='\n')
print('FORMED SHELL CLAMP CONTACTS',len(records),'PASS')
