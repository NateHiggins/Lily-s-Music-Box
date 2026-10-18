"""Source-fitted four-face pendant-clock candidate; no runtime publication."""
from pathlib import Path
import hashlib,json,math
ROOT=Path(__file__).resolve().parents[1]

def build(layout=None):
    source=ROOT/'art/data/building_layout.json'
    layout=layout or json.loads(source.read_text(encoding='utf8'))
    rows={row['id']:row for floor in layout['floors'] if floor['id']=='F01' for row in floor['furniture']}
    def bounds(row):
        a,b,c,d=row['rect'];return [a,row['z0'],-d],[c,row['z0']+row['h'],-b]
    names=['body','face_ns','face_ew','band_0','band_1']
    source_rows=[rows['site_passage_crossing_clock_'+name] for name in names]
    expected=['bakelite_black','milk_glass','milk_glass','brass_dull','brass_dull']
    if [r['mat'] for r in source_rows]!=expected:raise ValueError('Clock source materials changed')
    low,high=bounds(source_rows[0]);center=[(a+b)/2 for a,b in zip(low,high)]
    if any(abs(v-w)>1e-7 for v,w in zip([high[k]-low[k] for k in range(3)],[.56,.62,.56])):raise ValueError('Clock case envelope changed')
    envelopes=[([-.28,-.31,-.28],[.28,.31,.28]),([-.24,-.25,-.31],[.24,.25,.31]),([-.31,-.25,-.24],[.31,.25,.24]),([-.30,-.37,-.30],[.30,-.31,.30]),([-.30,.31,-.30],[.30,.37,.30])]
    for row,(lo,hi) in zip(source_rows,envelopes):
        actual_low,actual_high=bounds(row)
        if any(abs(actual-center[k]-expected)>1e-7 for values,target in [(actual_low,lo),(actual_high,hi)] for k,(actual,expected) in enumerate(zip(values,target))):raise ValueError('Clock source boundary changed: '+row['id'])
    stem=rows['site_crossing_clock_stem'];drop=rows['site_crossing_clock_drop']
    for row,radius in [(stem,.03),(drop,.05)]:
        if abs(row['r']-radius)>1e-7 or any(abs(point[0]-center[0])+abs(-point[1]-center[2])>1e-7 for point in [row['p0'],row['p1']]):raise ValueError('Retained clock support axis or stock changed')
    if abs(min(stem['p0'][2],stem['p1'][2])-high[1])>1e-7:raise ValueError('Retained clock stem no longer seats at case top')
    bottom=bounds(source_rows[3])[0][1]-center[1];top=bounds(source_rows[4])[1][1]-center[1]
    if abs(max(drop['p0'][2],drop['p1'][2])-(bottom+center[1]))>1e-7:raise ValueError('Retained lower finial bearing changed')
    parts=[]
    def box(name,lo,hi,key='iron_blackened',bevel=.0006):
        if any(a>=b for a,b in zip(lo,hi)):raise ValueError('Empty clock stock '+name)
        parts.append(dict(id=name,kind='box',low=lo,high=hi,catalog_key=key,bevel_m=bevel))
    # Closed cap stocks meet both retained supports; four real folded sides
    # and corner uprights enclose a cavity rather than a solid black cube.
    box('bottom_foot',[-.30,bottom,-.30],[.30,bottom+.018,.30],'brass_dull',.0018)
    box('bottom_step',[-.286,bottom+.018,-.286],[.286,-.31,.286],'brass_dull',.0015)
    box('top_step',[-.286,.31,-.286],[.286,top-.018,.286],'brass_dull',.0015)
    box('top_crown',[-.30,top-.018,-.30],[.30,top,.30],'brass_dull',.0018)
    for x in [-1,1]:
        for z in [-1,1]:box('corner_%s_%s'%(x,z),[x*.264-.014,-.31,z*.264-.014],[x*.264+.014,.31,z*.264+.014],bevel=.0012)
    faces=[]
    for name,normal in [('north',[0,0,-1]),('east',[1,0,0]),('south',[0,0,1]),('west',[-1,0,0])]:
        # A viewer's right, up and outward frame has positive orientation.
        u=[normal[2],0,-normal[0]];v=[0,1,0]
        face=dict(id=name,normal=normal,u=u,v=v,center=[n*.28 for n in normal],dial_radius=.211)
        faces.append(face)
        def part(suffix,kind,key,**kw):parts.append(dict(id=name+'_'+suffix,kind=kind,catalog_key=key,face=name,**kw))
        part('pierced_side','square_ring','iron_blackened',half=.27,half_height=.31,radius=.212,low=-.005,high=.001,bevel_m=.0004)
        part('bezel','lathe','brass_dull',profile=[[.214,.005],[.214,.021],[.217,.025],[.226,.027],[.234,.024],[.242,.012],[.242,0],[.238,-.005],[.220,-.005]],segments=72)
        part('dial','disc','enamel',radius=.211,low=.005,high=.0065,segments=72)
        # Minute strokes and heavier five-minute strokes are closed ink stock.
        for index in range(60):
            part('index_%02d'%index,'stroke','iron_blackened',angle=math.tau*index/60,low=.0065,high=.00658,radius=.201,length=.018 if index%5==0 else .007,width=.003 if index%5==0 else .001)
        # Each hand remains an independent export node, with its origin on
        # the actual spindle and its local +Y pointing to twelve o'clock.
        for hand,length,width,depth in [('hour',.126,.010,.010),('minute',.177,.007,.013)]:
            part(hand+'_hand','hand','iron_blackened',length=length,width=width,low=depth,high=depth+.0012,pivot=True)
        part('spindle_cap','disc','brass_dull',radius=.012,low=.0145,high=.018,segments=32)
        part('glass','disc','milk_glass',radius=.213,low=.020,high=.021,segments=72,optics_role='registered_clear_glass')
        for sx in [-1,1]:
            for sy in [-1,1]:part('screw_%s_%s'%(sx,sy),'screw','brass_dull',radius=.0045,low=.001,high=.003,segments=32,offset=[sx*.184,sy*.238])
    for row in parts:
        if row['catalog_key']=='brass_dull':row['catalog_key']='radiator_service_brass'
        if row['catalog_key']=='enamel':row['catalog_key']='washer_enamel'
    retired=[dict(id=row['id'],key=row['mat'],low=bounds(row)[0],high=bounds(row)[1],expected_triangles=12) for row in source_rows]
    return dict(evidence_class='INERT',source='art/data/building_layout.json',source_sha256_lf=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),origin=center,retire=retired,parts=parts,faces=faces,retained_stem=stem['id'],retained_finial=drop['id'],support_low=bottom,support_high=top,numerals='Runtime Label3D only; no generated texture or exported font mesh.',scope='Offline native clock candidate. No game publication, clock authority, interaction, UV/PBR/mipmap qualification or appearance acceptance.')

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    data=build();a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n');print(len(data['parts']),'closed clock stocks;',len(data['retire']),'exact source boundaries')
