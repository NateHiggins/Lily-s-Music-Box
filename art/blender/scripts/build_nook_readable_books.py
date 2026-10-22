"""Author the 61 lending copies from the shared native edition templates.

The existing copy-to-title programme remains the identity authority. Runtime
instances share the primary glTF buffers; this Blender file owns their fitted
composition, including the cushion reader and the three real shelf bearings.
"""
from pathlib import Path
import copy, hashlib, json, math, sys
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'DOCS.md').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from book_flex_math import left_translation

def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.py','.json'] else raw).hexdigest()

base=read('game/data/orison_v2/readable_library.json')
base_report=read('art/blender/readable_library_construction.json')
old=read('art/data/reading_nook/legacy_copy_poses.json')
programme_path=ROOT/'art/data/reading_nook/book_programme.json'
programme=json.loads(programme_path.read_text(encoding='utf-8'))['copies']
nook=read('art/blender/reading_nook_construction.json')
runtime=read('game/data/orison_v2/reading_nook.json')
assert set(programme)=={r['id'] for r in old['copies']}
assert not set(programme.values())&{'prospectus','minutes','hymns','onefinger'}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
draws=bpy.data.collections.new('AuthoredMetrePartitions');bpy.context.scene.collection.children.link(draws)
needed={part for title in set(programme.values()) for part in base['books'][title]['parts']}
needed.update(base['bookends']['pressed']['parts'])
with bpy.data.libraries.load(str(ROOT/'art/blender/readable_library.blend'),link=False) as (src,dst):dst.objects=sorted(needed)
templates={obj.name:obj for obj in dst.objects}
books={};parts={};stocks=[];lineage=[];copies=[]
for legacy in old['copies']:
    identity=legacy['id'];title=programme[identity]
    book=copy.deepcopy(base['books'][title]);book['native_title']=title
    book['parts']=[]
    for original in base['books'][title]['parts']:
        name=identity+original[len(title):]
        obj=templates[original].copy();obj.name=name;draws.objects.link(obj)
        obj.hide_render=not base['parts'][original].get('render_surface',True)
        parts[name]=dict(copy.deepcopy(base['parts'][original]),native_part=original)
        book['parts'].append(name)
        for record in base_report['closed_stocks']:
            if record['part']==original:stocks.append(dict(record,part=name))
    books[identity]=book
    p=legacy['position'];axes=Matrix(legacy['basis']).transposed();q=axes.to_quaternion()
    record=copy.deepcopy(legacy)
    record['legacy_pose']=p+[q.x,q.y,q.z,q.w]
    record['legacy_opening']=float(legacy['opening'])
    copies.append(record)
    lineage.append(dict(id=identity,title_id=title,source=legacy,
                        dimensions=[book['width'],book['height'],book['thickness']],format=book['format']))

G=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
point_cache={}
def native_points(names,opening=0.):
    result=[]
    for name in names:
        obj=draws.objects.get(name) or templates[name]
        spec=parts.get(name,base['parts'].get(name,{}))
        book=books.get(name.split('__')[0]+'__'+name.split('__')[1],{})
        # Shared edition vertices already contain the authored eight poses.
        mesh=obj.data;keys=mesh.shape_keys
        at=max(0.,min(8.,opening*8/math.pi));low=int(at);high=min(8,low+1);fraction=at-low
        for index,vertex in enumerate(mesh.vertices):
            p=vertex.co.copy()
            if keys and opening:
                neutral=keys.key_blocks[0].data[index].co
                p=keys.key_blocks[low].data[index].co.lerp(keys.key_blocks[high].data[index].co,fraction)
            point=G@(obj.matrix_world@p)
            if spec.get('role')=='left' and opening:
                owner=next(value for value in books.values() if name in value['parts'])
                point=Matrix.Rotation(-opening,3,'Y')@point+Vector(left_translation(owner['thickness'],opening,owner['opening_style']))
            result.append(point)
    return result

def bounds(record):
    identity=record['id'];angle=float(record['opening']);key=(identity,angle)
    if key not in point_cache:point_cache[key]=np.array([tuple(p) for p in native_points(books[identity]['parts'],angle)])
    points=point_cache[key]@np.array(record['basis'])+np.array(record['position'])
    return Vector(points.min(0)),Vector(points.max(0))

def align(record,left,top,front=-.13):
    lo,hi=bounds(record)
    record['position'][0]+=left-lo.x;record['position'][1]+=top-lo.y;record['position'][2]+=front-lo.z

upright=Matrix(((0,0,-1),(0,1,0),(1,0,0)))
flat=Matrix(((0,1,0),(0,0,1),(1,0,0)))
rack=[r for r in copies if r['assembly']=='nook_books']
assert len(rack)==57
for level,top in enumerate([.582,1.002,1.422]):
    residents=rack[level*19:(level+1)*19]
    cursor=-.56
    for index,record in enumerate(residents[:13]):
        basis=Matrix.Rotation(-.06 if index==12 else 0.,3,'Z')@upright
        record.update(position=[0.,0.,0.],basis=[list(basis.col[i]) for i in range(3)],opening=0.)
        align(record,cursor,top+.00035)
        lo,hi=bounds(record);cursor=hi.x+.003
    for group,anchor in enumerate([-.02,.30]):
        height=top+.00035
        for index,record in enumerate(residents[13+group*3:16+group*3]):
            record.update(position=[0.,0.,0.],basis=[list(flat.col[i]) for i in range(3)],opening=0.)
            align(record,anchor+index*.0015,height)
            height=bounds(record)[1].y+.00035
pile=[r for r in copies if r['assembly']=='nook_pile']
height=.36535
for index,record in enumerate(pile):
    record.update(position=[0.,0.,0.],basis=[list(flat.col[i]) for i in range(3)],opening=0.)
    align(record,-.11+index*.002,height,front=-.09)
    height=bounds(record)[1].y+.00035
# Keep the original pile owner's save frame fixed. Only its authored parked
# copies follow the repaired table; a loose saved copy retains world position.
frames={row['id']:row for row in runtime['assemblies']}
original_table=next(row for row in nook['original_records'] if row['id']=='nook_table')
old_position=Vector((-.96-original_table['at'][0],0.,2.10+original_table['at'][1]))
delta=Vector(frames['nook_table']['position'])-old_position
local_delta=Matrix.Rotation(frames['nook_pile']['yaw'],3,'Y').inverted()@delta
for record in pile:record['position']=list(Vector(record['position'])+local_delta)
reader=next(r for r in copies if r['assembly']=='nook_cush1')
width=books[reader['id']]['width'];theta=math.asin(.022/width)
reader['opening']=math.pi-2*theta
basis=Matrix(((math.cos(theta),0,-math.sin(theta)),(-math.sin(theta),0,-math.cos(theta)),(0,1,0)))
reader['basis']=[list(basis.col[i]) for i in range(3)];reader['position']=[.09,0.,-.12]
reader['position'][1]+=.55035-bounds(reader)[0].y

ends=[];end_spec=base['bookends']['pressed']
for level,top in enumerate([.582,1.002,1.422]):
    residents=rack[level*19:(level+1)*19];spans=[bounds(r) for r in residents]
    for side,x,angle in [('left',min(lo.x for lo,hi in spans)-.012,0.),('right',max(hi.x for lo,hi in spans)+.012,math.pi)]:
        basis=Matrix.Rotation(angle,3,'Y')
        heel=[basis@p for p in native_points(['bookend_pressed__FloorReturn'])]
        z=max(hi.z for lo,hi in spans)+.00155-min(p.z for p in heel) if side=='left' else min(lo.z for lo,hi in spans)-.00335-max(p.z for p in heel)
        origin=Vector((x,top-end_spec['support_y']+.00035,z))
        ends.append(dict(id=f'nook_books__End{level}_{side}',assembly='nook_books',style='pressed',position=list(origin),basis=[list(basis.col[i]) for i in range(3)]))
        foot=[origin+basis@p for p in native_points(['bookend_pressed__Foot'])]
        lo=Vector([min(p[i] for p in foot) for i in range(3)]);hi=Vector([max(p[i] for p in foot) for i in range(3)])
        for record in residents:
            low,high=bounds(record)
            if min(high.x,hi.x)-max(low.x,lo.x)>1e-6 and min(high.z,hi.z)-max(low.z,lo.z)>1e-6:record['position'][1]+=max(0.,hi.y+.00035-low.y)
    # Propagate any bearing lift through the authored flat piles.
    for _ in residents:
        changed=False
        for upper in residents:
            up_lo,up_hi=bounds(upper)
            if abs(upper['basis'][1][1])>.3:continue
            for lower in residents:
                if upper is lower:continue
                low_lo,low_hi=bounds(lower)
                if low_lo.y>=up_lo.y or low_hi.y<up_lo.y-.005:continue
                if up_lo.x<low_hi.x and up_hi.x>low_lo.x and up_lo.z<low_hi.z and up_hi.z>low_lo.z:
                    lift=low_hi.y+.00035-up_lo.y
                    if lift>1e-6:upper['position'][1]+=lift;up_lo.y+=lift;up_hi.y+=lift;changed=True
        if not changed:break

previous_ends={r['id']:r for r in old['ends']}
for record in ends:
    legacy=previous_ends[record['id']];q=Matrix(legacy['basis']).transposed().to_quaternion()
    record['legacy_pose']=legacy['position']+[q.x,q.y,q.z,q.w]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/nook_readable_books.blend'))
data=dict(schema_version=2,asset=base['asset'],books=books,parts=parts,copies=copies,ends=ends)
data_path=ROOT/'game/data/orison_v2/nook_readable_books.json'
data_path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[Path(__file__),programme_path,ROOT/'art/data/reading_nook/legacy_copy_poses.json',ROOT/'art/blender/reading_nook_construction.json',ROOT/'game/data/orison_v2/reading_nook.json',ROOT/'game/data/orison_v2/readable_library.json',ROOT/'art/blender/readable_library.blend',ROOT/'art/blender/readable_library_construction.json',ROOT/'game/assets/props/readable_library.glb',ROOT/'art/blender/scripts/book_flex_math.py',ROOT/'art/blender/scripts/review_nook_readable_books.py']
report=dict(evidence_class='INERT',lineage=lineage,parts=parts,closed_stocks=stocks,
            export=dict(status='PASS',kind='shared_native_templates',asset=base['asset'],source_sha256=digest(ROOT/'game/assets/props/readable_library.glb'),scope='Template geometry unchanged; this file authors copy placement, not a second exported mesh set.'),
            source_bindings={p.relative_to(ROOT).as_posix():digest(p) for p in bindings},
            outputs={p.relative_to(ROOT).as_posix():digest(p) for p in [data_path,ROOT/'art/blender/nook_readable_books.blend']})
(ROOT/'art/blender/nook_readable_books_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('NOOK EDITION TEMPLATES:',len(copies),'independent copies;',len(needed),'shared native templates;',len(ends),'real ends')
