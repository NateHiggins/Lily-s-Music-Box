"""Fit public region programmes to retained source stock; no acceptance grant.

Existing regions, templates, instances and routes remain byte-value equivalent.
New geometry owners are explicit; this never emits duplicate visual geometry.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math
ROOT=Path(__file__).resolve().parents[1]
REGIONS='game/data/orison_v2/exterior/regions.json'
BINDINGS='game/data/orison_v2/exterior/public_region_programmes.json'
NAMES=['CONSTRUCTION_SEAM','ARCADE_PORTAL','ARCADE_THROAT','ARCADE_HALL']

def rectangle(x0,z0,x1,z1):
    if not all(math.isfinite(v) for v in [x0,z0,x1,z1]) or x0>=x1 or z0>=z1:raise ValueError('Invalid programme envelope')
    return [[x0,z0],[x1,z0],[x1,z1],[x0,z1]]

def derive(layout,source,shed,frame):
    document=copy.deepcopy(source)
    if frame.get('frame')!='ORISON_FRONT_DOOR_THRESHOLD' or shed.get('frame')!=frame['frame']:raise ValueError('Shared frame changed')
    rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
    floor=rows['site_passage_aisle_floor'];west=rows['site_passage_throat_w'];east=rows['site_passage_throat_e']
    x0,neg_end,x1,neg_start=floor['rect'];start,end=-neg_start,-neg_end;y=floor['z0']+floor['h'];cx=(x0+x1)/2
    joint=-west['rect'][1];shift=float(frame['source_threshold_z'])
    if abs(start-shift-float(frame['arcade_building_line_z']))>1e-7 or west['rect'][2]!=x0 or east['rect'][0]!=x1 or east['rect'][1:]!=[west['rect'][1],east['rect'][2],west['rect'][3]]:raise ValueError('Throat/floor/frame registration changed')
    if not start<joint<end or min(west['h'],east['h'])<2.4:raise ValueError('Invalid public throat')
    front=[r for r in rows.values() if r['id'].startswith('site_passage_proxy') and 'rect' in r]
    walls=[r for r in rows.values() if r['id'].startswith('site_passage_wall_') and 'rect' in r]
    if not front or not walls:raise ValueError('Missing actual gateway/hall stock')
    def envelope(stock):return [min(r['rect'][0] for r in stock),min(-r['rect'][3] for r in stock),max(r['rect'][2] for r in stock),max(-r['rect'][1] for r in stock)]
    portal=envelope(front);portal[3]=max(portal[3],start+.8);hall=envelope(walls)
    if hall[0]>=x0 or hall[2]<=x1 or hall[1]>joint or hall[3]<end:raise ValueError('Hall stock does not contain its aisle')
    boxes={r['id']:r for r in shed['boxes']}
    def box_xz(row):
        c,s=row['center'],row['size'];return [c[0]-s[0]/2,c[2]-s[2]/2,c[0]+s[0]/2,c[2]+s[2]/2]
    a=box_xz(boxes['ShedStreetRoof']);b=box_xz(boxes['ShedTurnRoof'])
    if abs(a[2]-b[2])>1e-7 or abs(a[1]-b[3])>1e-7 or not a[0]<b[0]<a[2]:raise ValueError('Covered dogleg requires new fitting')
    construction=[[a[0],a[1]],[b[0],a[1]],[b[0],b[1]],[b[2],b[1]],[a[2],a[3]],[a[0],a[3]]]
    origins={'CONSTRUCTION_SEAM':[boxes['ShedStreetRoof']['center'][0],0,0],'ARCADE_PORTAL':[cx,y,start-shift],'ARCADE_THROAT':[cx,y,start-shift],'ARCADE_HALL':[cx,y,joint-shift]}
    bounds={'CONSTRUCTION_SEAM':construction,'ARCADE_PORTAL':rectangle(portal[0],portal[1]-shift,portal[2],portal[3]-shift),'ARCADE_THROAT':rectangle(west['rect'][0],start-shift,east['rect'][2],joint-shift),'ARCADE_HALL':rectangle(hall[0],hall[1]-shift,hall[2],hall[3]-shift)}
    generated_regions={'REGION_'+n for n in NAMES};generated_templates={'TEMPLATE_'+n+'_V2' for n in NAMES};generated_instances={n+'_01' for n in NAMES}
    for key,ids in [('regions',generated_regions),('surface_templates',generated_templates),('instances',generated_instances)]:document[key]=[r for r in document[key] if r['id'] not in ids]
    route_ids={'ROUTE_STREET_TO_ARCADE','ROUTE_ARCADE_TO_STREET','ROUTE_STREET_TO_CONSTRUCTION','ROUTE_CONSTRUCTION_TO_STREET'}
    document['routes']=[r for r in document['routes'] if r['id'] not in route_ids]
    street=next(t for t in document['surface_templates'] if t['id']=='TEMPLATE_STREET_SEGMENT_V1')
    if next(i for i in document['instances'] if i['id']=='STREET_ORISON_01')['owner_instance_id']!='':raise ValueError('Street root lost ownership')
    def surface(identity,point,size,kind='walkable',u=None,v=None,n=None):return dict(id=identity,kind=kind,point_m=point,u_axis=u or [1,0,0],v_axis=v or [0,0,1],normal=n or [0,1,0],size_m=size)
    def placement(identity,at,purpose,surface_id='floor',facing=None):return dict(id=identity,purpose=purpose,surface_id=surface_id,offset_uvn_m=at,facing_local=facing or [0,0,1])
    street['surfaces']=[s for s in street['surfaces'] if s['id']!='arcade_crossing']
    street['surfaces'].append(surface('arcade_crossing',[cx,0,(4.955+start-shift)/2],[2.5,start-shift-4.955]))
    # The retained lamp stands at (8.1, 3.975). Use the pavement centre,
    # rather than a straight eastward segment through that physical post.
    additions=[placement('public_pavement_clear',[-2.6,0,.04],'Clear centre of the retained pavement','pavement'),placement('arcade_pavement_turn',[cx-2.6,0,.04],'Pavement approach to arcade crossing','pavement'),placement('arcade_crossing_near',[0,-(start-shift-4.955)/2+.4,.04],'Crossing near-side stance','arcade_crossing'),placement('arcade_crossing_far',[0,(start-shift-4.955)/2-.7,.04],'Crossing far-side stance','arcade_crossing'),placement('construction_approach',[19.5-2.6,3-2.4775,.04],'Covered construction route arrival','pavement')]
    street['placements']=[p for p in street['placements'] if p['id'] not in {r['id'] for r in additions}]+additions
    bindings=[]
    for name in NAMES:
        origin=origins[name];poly=bounds[name];lineage='entrance_apron' if name=='CONSTRUCTION_SEAM' else 'arcade_portal'
        local=[p[0]-origin[0] for p in poly];depth=[p[1]-origin[2] for p in poly]
        document['regions'].append(dict(id='REGION_'+name,kind=name.lower(),lineage_id=lineage,boundary=poly))
        if name=='CONSTRUCTION_SEAM':
            sx=origin[0];surfaces=[surface('floor',[0,0,3],[a[2]-a[0],a[3]-a[1]]),surface('turn_floor',[24-sx,0,(b[1]+b[3])/2],[b[2]-b[0],b[3]-b[1]])]
            positions=[placement('under_roof',[21.5-sx,0,.04],'Covered street run'),placement('dogleg',[24-sx,0,.04],'Turn into the covered service dogleg'),placement('turn_middle',[0,0,.04],'Inside the covered return','turn_floor'),placement('closure_before',[0,-2.1-(b[1]+b[3])/2,.04],'Stop before the retained closure','turn_floor')]
            parent='STREET_ORISON_01';parent_surface='pavement';offset=[sx-2.6,-2.4775,0];source_origin=origin;owner='StreetBoundaries';path='NativeConstructionStock'
        elif name=='ARCADE_PORTAL':
            surfaces=[surface('floor',[0,0,0],[x1-x0,1.4]),surface('opening',[0,1.6,0],[2.5,3.2],'portal',v=[0,1,0],n=[0,0,-1])]
            positions=[placement('before',[0,-.7,.04],'Public arcade opening exterior'),placement('inside',[0,.45,.04],'Public arcade opening interior')]
            parent='STREET_ORISON_01';parent_surface='pavement';offset=[cx-2.6,start-shift-2.4775,y];source_origin=[cx,y,start];owner='VantryArcade';path='gateway'
        elif name=='ARCADE_THROAT':
            length=joint-start;surfaces=[surface('floor',[0,0,length/2],[x1-x0,length])]
            positions=[placement('near',[0,-length/2+1,.04],'Throat arrival'),placement('middle',[0,0,.04],'Compressed arcade throat'),placement('hall_before',[0,length/2-.65,.04],'Hall threshold approach')]
            parent='ARCADE_PORTAL_01';parent_surface='floor';offset=[0,0,0];source_origin=[cx,y,start];owner='VantryArcade';path='ResidentGeometry/passage'
        else:
            length=end-joint;surfaces=[surface('floor',[0,0,length/2],[x1-x0,length])]
            positions=[placement('arrival',[0,-length/2+.8,.04],'Arcade hall arrival'),placement('middle',[0,0,.04],'Shopfront and cart circulation'),placement('clock_stance',[0,51.6-joint-3-length/2,.04],'Crossing-clock player stance'),placement('far_turn',[0,length/2-1,.04],'Far arcade return stance',facing=[0,0,-1])]
            parent='ARCADE_THROAT_01';parent_surface='floor';offset=[0,(joint-start)/2,0];source_origin=[cx,y,joint];owner='VantryArcade';path='ResidentGeometry/passage'
        document['surface_templates'].append(dict(id='TEMPLATE_'+name+'_V2',kind=name.lower(),lineage_id=lineage,boundary_xz_m=[min(local),min(depth),max(local),max(depth)],surfaces=surfaces,placements=positions))
        document['instances'].append(dict(id=name+'_01',template_id='TEMPLATE_'+name+'_V2',region_id='REGION_'+name,lineage_id=lineage,owner_instance_id=parent,owner_surface_id=parent_surface,offset_uvn_m=offset,local_yaw_degrees=0,root_frame_identity='',semantic_identity=name,display_name=name.replace('_',' ')))
        paths=[path]
        if name=='ARCADE_PORTAL':paths.append('ResidentGeometry/passage')
        bindings.append(dict(instance_id=name+'_01',region_id='REGION_'+name,owner_node=owner,geometry_paths=paths,source_origin_m=source_origin))
    def nodes(pairs):return [dict(id=owner+'__'+place,owner_instance_id=owner,placement_id=place) for owner,place in pairs]
    arcade=[('STREET_ORISON_01',p) for p in ['orison_exit','public_pavement_clear','arcade_pavement_turn','arcade_crossing_near','arcade_crossing_far']]+[('ARCADE_PORTAL_01',p) for p in ['before','inside']]+[('ARCADE_THROAT_01',p) for p in ['near','middle','hall_before']]+[('ARCADE_HALL_01',p) for p in ['arrival','middle','clock_stance','far_turn']]
    construction_route=[('STREET_ORISON_01',p) for p in ['orison_exit','public_pavement_clear','construction_approach']]+[('CONSTRUCTION_SEAM_01',p) for p in ['under_roof','dogleg','turn_middle','closure_before']]
    for label,pairs,regions,lineage in [('ARCADE',arcade,['REGION_STREET','REGION_ARCADE_PORTAL','REGION_ARCADE_THROAT','REGION_ARCADE_HALL'],'arcade_portal'),('CONSTRUCTION',construction_route,['REGION_STREET','REGION_CONSTRUCTION_SEAM'],'entrance_apron')]:
        for reverse in [False,True]:document['routes'].append(dict(id='ROUTE_'+(label+'_TO_STREET' if reverse else 'STREET_TO_'+label),direction='toward_orison' if reverse else 'toward_shop',lineage_id=lineage,region_ids=list(reversed(regions)) if reverse else regions,threshold_ids=[],nodes=nodes(list(reversed(pairs)) if reverse else pairs)))
    return document,dict(schema_version=1,bounded_instance_ids=['SHOP_BODEGA','STREET_ORISON_01'],modules=bindings)

def build(root=ROOT):
    paths=['art/data/building_layout.json',REGIONS,'game/data/orison_v2/exterior/construction_shed.json','game/data/orison_v2/exterior/street_frame.json']
    values=[json.loads((root/p).read_text(encoding='utf8')) for p in paths]
    return derive(*values)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args();regions,bindings=build()
    if args.write:
        for path,value in [(REGIONS,regions),(BINDINGS,bindings)]: (ROOT/path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf8',newline='\n')
    print(json.dumps({'evidence_class':'INERT','scope':'Source-fitted public programmes; real geometry, walk, surface and human verification pending','regions':len(regions['regions']),'instances':len(regions['instances']),'routes':len(regions['routes']),'modules':bindings['modules']},indent=2))
