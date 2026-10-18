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
    for row in source['boxes']:
        expected='paper' if row['id']=='ClosureNoticeBoard' else 'oak_quartered'
        if row['material']!=expected:raise ValueError('construction source stock requires a new native recipe: '+row['id'])
    parts=[];joints=[]
    def stock(identity,actor,center,size,material='site_softwood',bevel=.0015,roll=0.,cuts=None):
        if min(size)<=0 or not all(math.isfinite(x) for x in center+size):raise ValueError(identity)
        parts.append({'id':identity,'actor':actor,'kind':'box','center_m':center,
            'size_m':size,'material':material,'bevel_m':min(bevel,min(size)/5),
            'roll_degrees':roll,'cuts':cuts or []})
        return parts[-1]
    def fastener(identity,actor,at,normal,kind='nail'):
        parts.append({'id':identity,'actor':actor,'kind':kind,'center_m':at,
            'axis':normal,'material':'zinc_quiet' if kind=='bolt' else 'iron_blackened'})
        return parts[-1]
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
        key='paper' if identity=='ClosureNoticeBoard' else 'site_softwood'
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
            hardware=fastener(beam['id']+'_'+post['id']+'_Bolt',post['actor'],at,normal,'bolt')
            joints[-1]['bolt_id']=hardware['id']
    for i,a in enumerate(beams):
        for b in beams[i+1:]:
            overlap=[[max(interval(a,k)[0],interval(b,k)[0]),min(interval(a,k)[1],interval(b,k)[1])] for k in range(3)]
            if any(hi-lo<.001 for lo,hi in overlap):continue
            if (a['size_m'][0]>a['size_m'][2])==(b['size_m'][0]>b['size_m'][2]):continue
            middle=sum(overlap[1])/2
            for piece,upper in [(a,True),(b,False)]:
                ranges=[v.copy() for v in overlap];ranges[1]=[middle,overlap[1][1]] if upper else [overlap[1][0],middle]
                piece['cuts'].append({'low':[v[0] for v in ranges],'high':[v[1] for v in ranges]})
            joints.append({'kind':'beam_cross_lap','lower':a['id'],'upper':b['id'],
                           'plane_axis':1,'plane_m':middle,'overlap':overlap})
    # Hoarding is scribed around the primary framing, rather than drawn
    # through it. The secondary roof members clear the continuous post heads.
    for piece in parts:
        if piece['kind']!='box' or piece in posts or piece in beams or piece.get('roll_degrees'):continue
        candidates=posts+beams if piece['actor'] in panel_faces else posts if '_Secondary' in piece['id'] else []
        for frame in candidates:
            overlap=[[max(interval(piece,k)[0],interval(frame,k)[0]),min(interval(piece,k)[1],interval(frame,k)[1])] for k in range(3)]
            if any(hi-lo<.00001 for lo,hi in overlap):continue
            piece['cuts'].append({'low':[v[0] for v in overlap],'high':[v[1] for v in overlap]})
    omitted=[]
    for piece in parts.copy():
        if piece['kind']=='box' and piece['cuts'] and not solid_cells(piece)[1]:
            if piece['actor'] not in panel_faces:raise ValueError('framing disappeared: '+piece['id'])
            omitted.append({'id':piece['id'],'reason':'fully covered by retained primary framing'});parts.remove(piece)
    # The retained diagonal brace was 18.5 mm off the hoarding boards.
    # Real cleats and through bolts bridge that source gap without moving
    # the collision-bearing brace, closure or notice.
    brace=boxes['ClosureCrossbrace'];panel=boxes['ShedTemporaryClosure'];pitch=panel['size'][0]/math.ceil(panel['size'][0]/.145)
    face=panel['center'][2]+panel['size'][2]/2-.0035
    brace_back=brace['center'][2]-brace['size'][2]/2
    for i,side in enumerate([-1,1]):
        desired=brace['center'][0]+side*.9
        slot=round((desired-(panel['center'][0]-panel['size'][0]/2+pitch/2))/pitch)
        x=panel['center'][0]-panel['size'][0]/2+pitch*(slot+.5)
        y=brace['center'][1]+(x-brace['center'][0])*math.tan(math.radians(brace.get('roll_degrees',0)))
        stock(f'ClosureBraceCleat{i}','ClosureCrossbrace',[x,y,(face+brace_back)/2],[.055,.12,brace_back-face],roll=brace.get('roll_degrees',0))
        hardware=fastener(f'ClosureBraceBolt{i}','ClosureCrossbrace',[x,y,face],[0.,0.,1.],'bolt')
        hardware['bearing_offsets_m']=[-.022,brace['center'][2]+brace['size'][2]/2-face]
        joints.append({'kind':'brace_cleat','actor':'ClosureCrossbrace','plane_axis':2,'plane_m':brace_back,'sample_m':[x,y,brace_back]})
    # Verify the remaining contact after all intersecting joints are cut.
    # Hardware is centred on a surviving bearing patch, never a bevel edge.
    by_id={p['id']:p for p in parts}
    for joint in joints:
        if joint['kind'] not in ['complementary_half_lap','beam_cross_lap']:continue
        if joint['kind']=='complementary_half_lap':negative=by_id[joint['beam']];positive=by_id[joint['post']]
        else:negative=by_id[joint['lower']];positive=by_id[joint['upper']]
        contact=contact_patches(negative,positive,joint['plane_axis'],joint['plane_m'],joint['overlap'])
        if not contact:raise ValueError('joinery has no remaining bearing: '+str(joint))
        area,point=max(contact,key=lambda row:row[0]);joint['contact_area_m2']=sum(row[0] for row in contact);joint['sample_m']=point
        if 'bolt_id' in joint:
            bolt=by_id[joint['bolt_id']];bolt['center_m']=point;axis=joint['plane_axis']
            bolt['bearing_offsets_m']=[interval(negative,axis)[0]-point[axis],interval(positive,axis)[1]-point[axis]]
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
        'parts':parts,'joints':joints,'omitted_occluded_stock':omitted}

def solid_cells(row):
    import itertools
    low=[c-s/2 for c,s in zip(row['center_m'],row['size_m'])];high=[c+s/2 for c,s in zip(row['center_m'],row['size_m'])]
    axes=[sorted(set([low[k],high[k]]+[max(low[k],min(high[k],c[end][k])) for c in row.get('cuts',[]) for end in ['low','high']])) for k in range(3)]
    cells=set()
    for index in itertools.product(*(range(len(v)-1) for v in axes)):
        middle=[(axes[k][index[k]]+axes[k][index[k]+1])/2 for k in range(3)]
        if not any(all(c['low'][k]<middle[k]<c['high'][k] for k in range(3)) for c in row.get('cuts',[])):cells.add(index)
    return axes,cells

def contact_patches(negative,positive,axis,plane,overlap):
    import itertools
    other=[k for k in range(3) if k!=axis]
    def solid(row,p):
        return all(abs(p[k]-row['center_m'][k])<row['size_m'][k]/2+1e-9 for k in range(3)) and not any(all(c['low'][k]<p[k]<c['high'][k] for k in range(3)) for c in row.get('cuts',[]))
    coordinates=[]
    for k in other:
        low,high=overlap[k];coordinates.append(sorted(set([low,high]+[max(low,min(high,c[end][k])) for row in [negative,positive] for c in row.get('cuts',[]) for end in ['low','high']])))
    result=[]
    for i,j in itertools.product(range(len(coordinates[0])-1),range(len(coordinates[1])-1)):
        ranges=[coordinates[0][i:i+2],coordinates[1][j:j+2]];area=math.prod(b-a for a,b in ranges)
        if area<1e-8:continue
        at=[0.,0.,0.];at[axis]=plane
        for k,(a,b) in zip(other,ranges):at[k]=(a+b)/2
        left=at.copy();right=at.copy();left[axis]-=.00001;right[axis]+=.00001
        if solid(negative,left) and solid(positive,right):result.append((area,at))
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();plan=build();args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf8',newline='\n')
    print(f"Native shed candidate: {len(plan['parts'])} parts, {len(plan['joints'])} declared joints; retained actors/lights unchanged.")

if __name__=='__main__':main()
