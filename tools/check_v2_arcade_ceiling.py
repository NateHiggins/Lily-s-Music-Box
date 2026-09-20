"""Static checks for the shipped ceiling detail and a labelled geometry study."""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import build_v2_arcade_ceiling as build

ROOT=build.ROOT
OUT=ROOT/'design/astra/evidence/v2_arcade_ceiling_01'


def check_geometry(subjects):
    for part in subjects:
        v=part['vertices']
        if part['kind'] in ['panel','tie']:
            lo,hi=min(p[2] for p in v),max(p[2] for p in v)
            assert hi<48.6 or lo>54.6, 'detail covers the crossing lantern'
            assert all(hi<rib-.10 or lo>rib+.10 for rib in range(39,64,2)), 'detail crosses a transverse roof rib'
        if part['kind']=='fan':
            for x,y,z in v:
                assert y>8.02, 'fan blocks the south lunette'
                half=.7 if y>9.2 else 1.5 if y>8.3 else 2.4
                assert abs(x-14)<half, 'fan overhangs the solid gable'


def preview(parts):
    # Orthographic drawing of actual generated triangles, deliberately labelled
    # as flat-colour geometry. This is not a simulated engine lighting result.
    from PIL import Image, ImageDraw, ImageFont
    canvas=Image.new('RGB',(1400,940),(17,24,28))
    draw=ImageDraw.Draw(canvas)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',23)
    title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',34)
    draw.text((45,28),'ARCADE / CEILING DETAIL',font=title,fill=(237,221,181))
    draw.text((45,80),'Source geometry study - flat colours, not a Godot render',font=font,fill=(160,180,185))
    # An eight-panel cutaway shows the real thickness, facet steps and open work.
    def project(p):
        x,y,z=p
        return (700+(x-14)*205+(z-42)*90, 330+(z-42)*108-(y-9.7)*150-(x-14)*48)
    triangles=[]
    colors={'teal':(34,175,158),'brass':(218,173,88),'ochre':(153,104,54)}
    for key,vertices in parts.items():
        for i in range(0,len(vertices),3):
            tri=vertices[i:i+3]
            ps=[p for p,n in tri]
            if not all(12.79<p[0]<15.21 and 40.99<p[2]<44.91 for p in ps):continue
            n=tri[0][1]
            shade=.65+.35*abs(build.dot(n,build.unit((.4,-1,.25))))
            color=tuple(int(c*shade) for c in colors[key])
            depth=sum(p[1]-.18*p[2] for p in ps)/3
            triangles.append((depth,[project(p) for p in ps],color))
    for _,points,color in sorted(triangles,reverse=True): draw.polygon(points,fill=color)
    draw.text((45,756),'100 open-work panels / turquoise enamel + brass',font=font,fill=(213,224,218))
    draw.text((45,796),'Stepped ochre edge mouldings and two fan crowns',font=font,fill=(213,224,218))
    draw.text((45,836),'Existing glazing, crossing lantern, clock and lights retained',font=font,fill=(160,180,185))
    draw.text((45,886),'3 added material batches / 22,344 triangles / engine appearance pending',font=font,fill=(160,180,185))
    canvas.save(OUT/'geometry_study.png')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    parts,subjects,_=build.geometry()
    check_geometry(subjects)
    controls=[]
    for name,delta in [('roof_rib_overlap',-.20),('lantern_overlap',10.0)]:
        p=next(s for s in subjects if s['kind']=='panel').copy()
        p['vertices']=[(x,y,z+delta) for x,y,z in p['vertices']]
        try:check_geometry([p])
        except AssertionError:controls.append(name)
        else:raise AssertionError('negative accepted: '+name)
    paths=[build.OUT/'passage.gltf',build.OUT/'ceiling_detail.bin',build.RECORD]
    before={str(p):build.sha(p) for p in paths}
    build.build()
    assert before=={str(p):build.sha(p) for p in paths}, 'regeneration differs'
    d=json.loads(paths[0].read_text(encoding='utf-8'))
    for row in d['buffers']+d['images']:
        assert (build.OUT/row['uri']).resolve().is_file(),row['uri']
    for row in d['buffers']:
        assert (build.OUT/row['uri']).stat().st_size==row['byteLength']
    data=(build.OUT/'ceiling_detail.bin').read_bytes()
    for mesh in d['meshes'][-3:]:
        attrs=mesh['primitives'][0]['attributes']
        a=d['accessors'][attrs['POSITION']];v=d['bufferViews'][a['bufferView']]
        ns=d['accessors'][attrs['NORMAL']];nv=d['bufferViews'][ns['bufferView']]
        assert a['count']==ns['count'] and a['count']%3==0
        for i in range(0,a['count'],3):
            ps=[struct.unpack_from('<3f',data,v['byteOffset']+(i+j)*12) for j in range(3)]
            n=struct.unpack_from('<3f',data,nv['byteOffset']+i*12)
            face=build.cross(build.sub(ps[1],ps[0]),build.sub(ps[2],ps[0]))
            assert build.dot(face,n)>1e-10,'reversed or collapsed output triangle'
    sys.path.insert(0,'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
    from gdtoolkit.parser import parser
    scripts=['game/scripts/building/orison_v2_passage_region.gd','game/scripts/building/orison_v2_passage_residency.gd',
             'game/tests/orison_v2_passage_residency_test.gd']
    for path in scripts:parser.parse((ROOT/path).read_text(encoding='utf-8'))
    preview(parts)
    report=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',checks=['rib/lantern/lunette clearances','solid gable support',
                'byte-identical regeneration','all glTF resources resolve','binary lengths and emitted triangle winding','three GDScript syntax parses'],
                rejected_controls=controls,artifacts={p.relative_to(ROOT).as_posix():build.sha(p) for p in paths},
                preview='Flat-colour drawing of generated geometry only; not material, lighting or runtime proof.')
    (OUT/'checks.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))


if __name__=='__main__':main()
