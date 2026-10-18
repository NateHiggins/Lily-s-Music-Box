"""Build a native timber candidate inside the retained construction-shed frame.

The existing boxes remain collision and placement authority. This planner emits
separate construction stock, lapped framing and real fastener locations; it
does not edit gameplay data, protected layout files, or generated glTF.
"""
from pathlib import Path
import argparse, copy, hashlib, json, math

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'art/data/orison_v2/exterior/construction_shed_source.json'
RUNTIME = 'game/data/orison_v2/exterior/construction_shed.json'

def digest(path):
    return hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()

def build(root=ROOT):
    source=json.loads((root/SOURCE).read_text(encoding='utf8'))
    runtime=json.loads((root/RUNTIME).read_text(encoding='utf8'))
    authored=copy.deepcopy(source);authored.pop('intent')
    if authored!=runtime:raise ValueError('shed authoring/runtime projection drift')
    boxes={row['id']:row for row in source['boxes']}
    if len(boxes)!=len(source['boxes']):raise ValueError('duplicate retained actor')
    parts=[];joints=[]
    def stock(identity,actor,center,size,material='timber',bevel=.0015,roll=0.,cuts=None):
        if min(size)<=0 or not all(math.isfinite(x) for x in center+size):raise ValueError(identity)
        parts.append({'id':identity,'actor':actor,'kind':'box','center_m':center,
            'size_m':size,'material':material,'bevel_m':min(bevel,min(size)/5),
            'roll_degrees':roll,'cuts':cuts or []})
        return parts[-1]
    def fastener(identity,actor,at,normal,kind='nail'):
        parts.append({'id':identity,'actor':actor,'kind':kind,'center_m':at,
            'axis':normal,'material':'zinc_quiet' if kind=='bolt' else 'iron_blackened'})
    def evenly(low,high,count):return [low+(high-low)*i/(count-1) for i in range(count)]
    def panel(row,normal_axis,sign):
        actor=row['id'];c=row['center'];size=row['size'];width_axis=2 if normal_axis==0 else 0
        count=math.ceil(size[width_axis]/.145);pitch=size[width_axis]/count
        front=c[normal_axis]+sign*size[normal_axis]/2
        plank_front=front-sign*.0035;plank_back=plank_front-sign*.022
        for i in range(count):
            at=c.copy();at[width_axis]+=(-size[width_axis]+pitch)/2+i*pitch
            at[normal_axis]=(plank_front+plank_back)/2
            dims=size.copy();dims[width_axis]=pitch-.0015;dims[normal_axis]=.022
            stock(f'{actor}_Board{i:02}',actor,at,dims)
            for rail in [.24,1.3,2.42]:
                for edge in [-1,1]:
                    point=at.copy();point[1]=rail;point[width_axis]+=edge*min(.044,pitch*.28);point[normal_axis]=plank_front
                    normal=[0.,0.,0.];normal[normal_axis]=sign
                    fastener(f'{actor}_Nail{i:02}_{rail}_{edge}',actor,point,normal)
        # Cover joints without making a view through the world boundary.
        for i in range(1,count):
            at=c.copy();at[width_axis]+=-size[width_axis]/2+i*pitch;at[normal_axis]=front-sign*.00175
            dims=size.copy();dims[width_axis]=.025;dims[normal_axis]=.0035
            stock(f'{actor}_Batten{i:02}',actor,at,dims,bevel=.00045)
        for i,y in enumerate([.24,1.3,2.42]):
            at=c.copy();at[1]=y;at[normal_axis]=plank_back-sign*.0445
            dims=size.copy();dims[1]=.089;dims[normal_axis]=.089
            stock(f'{actor}_Nailer{i}',actor,at,dims)
            joints.append({'kind':'plank_to_nailer','actor':actor,'plane_axis':normal_axis,
                           'plane_m':plank_back,'height_m':y,'count':count})
    panel_faces={'ShedRoadHoarding':(2,-1),'ShedEastHoarding':(0,-1),
        'ShedInnerReturn':(0,1),'ShedTemporaryClosure':(2,1),'ShedInnerStreetHoarding':(2,1)}
    for identity,face in panel_faces.items():panel(boxes[identity],*face)
    for identity in ['ShedStreetRoof','ShedTurnRoof','ShedTurnFloor']:
        row=boxes[identity];c=row['center'];size=row['size'];floor=identity.endswith('Floor')
        # Secondary members cross the retained primary beams. The walking
        # surface and the highest roof plane retain their original heights.
        length_axis=0 if identity=='ShedTurnRoof' else 2
        across=2 if length_axis==0 else 0
        count=math.ceil(size[across]/.145);pitch=size[across]/count;top=c[1]+size[1]/2
        board_top=top if floor else top-.006
        board_bottom=board_top-.045
        for i in range(count):
            at=c.copy();at[across]+=(-size[across]+pitch)/2+i*pitch;at[1]=(board_top+board_bottom)/2
            dims=size.copy();dims[1]=.045;dims[across]=pitch-.0015
            stock(f'{identity}_Deck{i:02}',identity,at,dims,bevel=.001)
        # A closed backing protects the finite undercroft; top roofing is
        # separately mapped bitumen, never a metal imitation of roofing felt.
        at=c.copy();dims=size.copy();dims[1]=.02 if floor else .006
        at[1]=c[1]-size[1]/2+.01 if floor else top-.003
        stock(identity+'_Backing' if floor else identity+'_Felt',identity,at,dims,'concrete' if floor else 'roof_bitumen',.0006)
        joist_count=max(2,math.ceil(size[length_axis]/.55)+1)
        for i,t in enumerate(evenly(-size[length_axis]/2+.045,size[length_axis]/2-.045,joist_count)):
            at=c.copy();at[length_axis]+=t
            bottom=c[1]-size[1]/2+(.02 if floor else .02)
            dims=size.copy();dims[length_axis]=.07;dims[1]=board_bottom-bottom;at[1]=(bottom+board_bottom)/2
            stock(f'{identity}_Secondary{i:02}',identity,at,dims)
            joints.append({'kind':'deck_to_secondary','actor':identity,'plane_axis':1,
                           'plane_m':board_bottom,'stock_id':parts[-1]['id']})
    framing={}
    for row in source['boxes']:
        identity=row['id']
        if identity in panel_faces or identity in ['ShedStreetRoof','ShedTurnRoof','ShedTurnFloor']:continue
        key='paper' if identity=='ClosureNoticeBoard' else 'timber'
        framing[identity]=stock(identity,row['id'],row['center'].copy(),row['size'].copy(),key,
                               roll=float(row.get('roll_degrees',0)))
    # Complementary half laps retain a continuous post web: a beam is not
    # drawn through an intact post. Cuts are axis-aligned authored joinery.
    posts=[p for name,p in framing.items() if 'Post' in name]
    beams=[p for name,p in framing.items() if 'Beam' in name]
    def interval(p,axis):return (p['center_m'][axis]-p['size_m'][axis]/2,p['center_m'][axis]+p['size_m'][axis]/2)
    for beam in beams:
        along=0 if beam['size_m'][0]>beam['size_m'][2] else 2;width=2 if along==0 else 0
        for post in posts:
            overlap=[[max(interval(beam,k)[0],interval(post,k)[0]),min(interval(beam,k)[1],interval(post,k)[1])] for k in range(3)]
            if any(b-a<.001 for a,b in overlap):continue
            middle=sum(overlap[width])/2
            for piece,upper in [(post,False),(beam,True)]:
                ranges=[v.copy() for v in overlap]
                ranges[width]=[middle,interval(beam,width)[1]] if upper else [interval(post,width)[0],middle]
                piece['cuts'].append({'low':[v[0] for v in ranges],'high':[v[1] for v in ranges]})
            joints.append({'kind':'complementary_half_lap','post':post['id'],'beam':beam['id'],
                           'plane_axis':width,'plane_m':middle,'overlap':overlap})
            at=post['center_m'].copy();at[1]=beam['center_m'][1];normal=[0.,0.,0.];normal[width]=1.
            fastener(beam['id']+'_'+post['id']+'_Bolt',post['actor'],at,normal,'bolt')
    ids=[p['id'] for p in parts]
    if len(set(ids))!=len(ids):raise ValueError('duplicate construction part')
    materials=json.loads((root/'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
    if any(p['material'] not in materials for p in parts):raise ValueError('uncatalogued construction finish')
    return {'schema':'orison.construction-shed-native-plan.v1','evidence_class':'INERT',
        'scope':'Native visual candidate. Retained collision, lights, label and gameplay authority are not replaced.',
        'frame':source['frame'],'asset_origin_m':[22.25,0.,0.],
        'source_bindings':{SOURCE:digest(root/SOURCE),RUNTIME:digest(root/RUNTIME),
                           'tools/plan_v2_construction_shed.py':digest(Path(__file__))},
        'retained_actors':runtime['boxes'],'retained_lights':runtime['lights'],
        'parts':parts,'joints':joints}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();plan=build();args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf8',newline='\n')
    print(f"Native shed candidate: {len(plan['parts'])} parts, {len(plan['joints'])} declared joints; retained actors/lights unchanged.")

if __name__=='__main__':main()
