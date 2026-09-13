"""Reference-inspired raised arcade ceiling, built without Blender or Godot.

The admitted passage is copied with external resources redirected, never
rewritten. Three batched opaque detail meshes preserve its glass/clock/lights.
"""
from pathlib import Path
import copy
import hashlib
import json
import math
import os
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'game/assets/building/floor_01_cells/passage.gltf'
OUT = ROOT/'game/assets/building/orison_v2/passage'
RECORD = ROOT/'game/data/orison_v2/arcade_ceiling_source.json'
REFS = ROOT/'art/references/arcade_ceiling'
PALETTE = {'teal': ('enamel_appliance', [.10, .56, .46, 1]),
           'brass': ('brass_dull', [.88, .67, .30, 1]),
           'ochre': ('plaster_stained', [.64, .40, .16, 1])}


def add(a, b): return tuple(x+y for x, y in zip(a, b))
def sub(a, b): return tuple(x-y for x, y in zip(a, b))
def mul(a, b): return tuple(x*b for x in a)
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a, 1/math.sqrt(dot(a, a)))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def geometry():
    parts = {k: [] for k in PALETTE}
    subjects = []

    def bar(key, a, b, width, depth, normal=(0, 1, 0), subject='panel'):
        along = unit(sub(b, a))
        across = mul(unit(cross(along, normal)), width*.5)
        thick = mul(unit(normal), depth*.5)
        vertices = [add(p, add(mul(across, s), mul(thick, t)))
                    for p in [a, b] for s, t in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
        center = mul(add(a, b), .5)
        for face in [(0,1,2,3), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)]:
            face = list(face)
            n = unit(cross(sub(vertices[face[1]], vertices[face[0]]), sub(vertices[face[2]], vertices[face[0]])))
            if dot(n, sub(vertices[face[0]], center)) < 0:
                face.reverse()
                n = mul(n, -1)
            for i in [0,1,2,0,2,3]: parts[key].append((vertices[face[i]], n))
        subjects.append(dict(kind=subject, material=key, vertices=vertices))

    def loop(key, points, width, depth, normal=(0,1,0), subject='panel'):
        for a,b in zip(points, points[1:]+points[:1]): bar(key,a,b,width,depth,normal,subject)

    # Ten original horizontal glass facets; the crossing/clock bay stays open.
    # Each panel hangs from its own glass-frame level, leaving the glass visible
    # through open diamonds. New ribs have actual thickness, never alpha cards.
    panels = 0
    for column in range(10):
        x = 11.3+.6*column
        roof = 7.2+2.7*math.sqrt(1-((x-14)/3)**2)
        for zone in [(39.0,48.32),(55.0,64.16)]:
            for row in range(5):
                low, high = zone[0]+2*row+.15, min(zone[0]+2*row+1.85, zone[1])
                z = (low+high)*.5
                half_z = (high-low)*.5
                y = roof-.145
                loop('brass',[(x-.255,y,z-half_z),(x+.255,y,z-half_z),(x+.255,y,z+half_z),(x-.255,y,z+half_z)],.028,.09)
                loop('teal',[(x,y-.018,z-half_z+.10),(x+.20,y-.018,z),(x,y-.018,z+half_z-.10),(x-.20,y-.018,z)],.044,.065)
                # Paired stepped chevrons echo the reference's woven grille.
                for sign in [-1,1]:
                    for offset in [-.23,.23]:
                        bar('teal',(x-.19,y-.038,z+offset+sign*.15),(x,y-.038,z+offset),.029,.04)
                        bar('teal',(x,y-.038,z+offset),(x+.19,y-.038,z+offset+sign*.15),.029,.04)
                for dz in [-half_z,half_z]:
                    # Ties meet the existing facet underside, preventing a
                    # decorative panel from appearing to float below the roof.
                    bar('brass',(x,roof-.10,z+dz),(x,roof,z+dz),.035,.035,(0,0,1),'tie')
                panels += 1
    # Deep stepped edge mouldings touch the existing springing entablature.
    for side in [-1,1]:
        edge = 14+side*2.90
        for step in range(3):
            x = edge-side*(.08+.075*step)
            y = 7.13-.08*step
            bar('ochre',(x,y,38.87),(x,y,64.33),.20,.10,subject='border')
            bar('brass',(x-side*.095,y-.045,38.87),(x-side*.095,y-.045,64.33),.018,.026,subject='border')
    # Compact stepped fan crowns sit on solid plaster above the south lunette
    # (top 8.00m); no glass, clock face or business signage is covered.
    for z in [38.87,64.33]:
        for i in range(-5,6):
            x = 14+i*.245
            top = 8.40+(5-abs(i))*.17
            bar('ochre',(x,8.055,z),(x,top,z),.218,.06,(0,0,1),'fan')
            bar('brass',(14+i*.035,8.08,z+(.04 if z<40 else -.04)),
                (x,top-.035,z+(.04 if z<40 else -.04)),.024,.018,(0,0,1),'fan')
        face_z = z + (.018 if z < 40 else -.018)
        loop('brass',[(13.35,8.055,face_z),(14,8.50,face_z),(14.65,8.055,face_z)],.035,.085,(0,0,1),'fan')
    return parts, subjects, panels


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    original = json.loads(SOURCE.read_text(encoding='utf-8'))
    result = copy.deepcopy(original)
    for rows in [result['buffers'], result.get('images',[])]:
        for row in rows:
            if 'uri' in row and not row['uri'].startswith('data:'):
                row['uri'] = Path(os.path.relpath((SOURCE.parent/row['uri']).resolve(),OUT)).as_posix()
    parts, subjects, panels = geometry()
    data = bytearray()
    buffer_id = len(result['buffers'])

    def accessor(values, width, bounds=False):
        start = len(data)
        for value in values: data.extend(struct.pack('<'+'f'*width,*value))
        view = len(result['bufferViews'])
        result['bufferViews'].append(dict(buffer=buffer_id,byteOffset=start,byteLength=len(data)-start,target=34962))
        a = dict(bufferView=view,componentType=5126,count=len(values),type='VEC'+str(width))
        if bounds:
            a.update(min=[min(v[i] for v in values) for i in range(width)],max=[max(v[i] for v in values) for i in range(width)])
        result['accessors'].append(a)
        return len(result['accessors'])-1

    catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
    for key, vertices in parts.items():
        material_key, tint = PALETTE[key]
        spec = catalog[material_key]
        def texture(filename):
            path=ROOT/'game/assets/building/textures'/filename
            assert path.is_file()
            result['images'].append(dict(uri=Path(os.path.relpath(path,OUT)).as_posix()))
            result['textures'].append(dict(source=len(result['images'])-1))
            return len(result['textures'])-1
        material = dict(name='M_v2_arcade_'+key,normalTexture=dict(index=texture(spec['files'][2]),scale=.55),
                        pbrMetallicRoughness=dict(baseColorFactor=tint,baseColorTexture=dict(index=texture(spec['files'][0])),
                                                roughnessFactor=spec['roughness_multiplier'] if key=='brass' else .72,metallicFactor=spec['metallic'],
                                                metallicRoughnessTexture=dict(index=texture(spec['files'][1]))))
        result['materials'].append(material)
        uv=[]
        for p,n in vertices:
            dominant=max(range(3),key=lambda i:abs(n[i]))
            axes=[i for i in range(3) if i!=dominant]
            uv.append(tuple(p[i]/spec['meters_per_tile'] for i in axes))
        attrs=dict(POSITION=accessor([p for p,n in vertices],3,True),NORMAL=accessor([n for p,n in vertices],3),TEXCOORD_0=accessor(uv,2))
        name='V2_PASSAGE_finish_ceiling_'+key
        result['meshes'].append(dict(name=name,primitives=[dict(attributes=attrs,material=len(result['materials'])-1,mode=4)]))
        result['nodes'].append(dict(name=name,mesh=len(result['meshes'])-1))
        result['scenes'][result.get('scene',0)]['nodes'].append(len(result['nodes'])-1)
    (OUT/'ceiling_detail.bin').write_bytes(data)
    result['buffers'].append(dict(uri='ceiling_detail.bin',byteLength=len(data)))
    (OUT/'passage.gltf').write_text(json.dumps(result,separators=(',',':'))+'\n',encoding='utf-8')
    # Source checks constrain the actual emitted vertices and keep the original
    # primitive/material/collision ownership untouched.
    assert result['nodes'][:len(original['nodes'])] == original['nodes']
    assert result['meshes'][:len(original['meshes'])] == original['meshes']
    assert result['materials'][:len(original['materials'])] == original['materials']
    assert panels == 100
    for key, verts in parts.items():
        assert len(verts)%3 == 0
        for p,n in verts:
            assert all(math.isfinite(v) for v in p+n)
            assert 10.99 < p[0] < 17.01 and 6.85 < p[1] < 9.95 and 38.59 < p[2] <= 64.360001
            assert abs(dot(n,n)-1)<1e-6
    triangles=sum(len(v)//3 for v in parts.values())
    assert triangles < 24000
    record=dict(schema_version=1,source=SOURCE.relative_to(ROOT).as_posix(),source_sha256=sha(SOURCE),
                references=[dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in sorted(REFS.glob('*.png'))],
                inspiration='Turquoise open geometric relief, nested brass borders, stepped ochre mouldings and compact fan crowns; no photographic projection.',
                output=(OUT/'passage.gltf').relative_to(ROOT).as_posix(),panels=panels,added_draws=3,added_triangles=triangles,
                added_lights=0,added_collision_bodies=0,original_meshes_preserved=len(original['meshes']),
                status='SOURCE_CHECKED_GODOT_NOT_RUN',buffer_sha256=sha(OUT/'ceiling_detail.bin'))
    assert len(record['references'])==2
    RECORD.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record))


if __name__=='__main__': build()
