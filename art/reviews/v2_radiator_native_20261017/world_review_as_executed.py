"""UNINSTALLED neutral-pitch candidate versus all actual acquired emitter bays."""
from pathlib import Path
import bpy,bmesh,json,math,hashlib,sys
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
R=Path('C:/PleaseRemainOnTheLine');P=Path(__file__).resolve().parent;B=P/'portable_build_final'
context=P/'preinstall_context';metadata=json.loads((context/'context.json').read_text());bays=json.loads((P/'all_emitter_bays.json').read_text())
assert metadata['valid'] and hashlib.sha256((P/'all_emitter_bays.json').read_bytes()).hexdigest()==metadata['route_sha256']
assert hashlib.sha256((context/'context.glb').read_bytes()).hexdigest()==metadata['context_sha256']
sys.path.insert(0,str(R/'tools'))
from audit_orison_v2_completeness import runtime_inputs_sha256
from v2_surface_evidence import inputs
assert metadata['runtime_inputs_sha256']==runtime_inputs_sha256(R)
assert metadata['rendering_inputs_sha256']==inputs(R)['sha256']
candidate_sha256=hashlib.sha256((B/'packed_union_candidate.blend').read_bytes()).hexdigest()
vent_sha256=hashlib.sha256((B/'automatic_vent_finished_candidate.blend').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(B/'packed_union_candidate.blend'))
stocks={obj.name:obj for obj in bpy.data.objects if obj.type=='MESH'}
stand_off=.03
support_sha256=hashlib.sha256((B/'sliding_wall_ties_candidate.blend').read_bytes()).hexdigest()
with bpy.data.libraries.load(str(B/'sliding_wall_ties_candidate.blend'),link=False) as (available,loaded):loaded.objects=list(available.objects)
for obj in loaded.objects:
    if obj.type=='MESH':bpy.context.collection.objects.link(obj);stocks[obj.name]=obj
support_report=json.loads((B/'sliding_wall_ties_review.json').read_text())
assert not support_report['failures'] and support_report['native_sha256']==support_sha256
support_mounts=support_report['mounts']

packing_poses={}
packing_source=stocks['RemovableFibrousUnionPacking']
rest=[v.co.copy() for v in packing_source.data.shape_keys.key_blocks['Seated'].data]
spread=[v.co.copy() for v in packing_source.data.shape_keys.key_blocks['SpreadForRemoval'].data]
for peel in [0,.25,.5,.75,1]:
    obj=packing_source.copy();obj.data=packing_source.data.copy();bpy.context.collection.objects.link(obj);obj.shape_key_clear();obj.name='ClothPose_'+str(peel)
    amount=min(peel/.5,1)
    for vertex,a,b in zip(obj.data.vertices,rest,spread):vertex.co=a.lerp(b,amount)
    obj.data.update();packing_poses[peel]=obj
bpy.context.view_layer.update()

with bpy.data.libraries.load(str(B/'automatic_vent_finished_candidate.blend'),link=False) as (available,loaded):loaded.objects=available.objects
for obj in loaded.objects:
    if obj.type=='MESH':bpy.context.collection.objects.link(obj);stocks[obj.name]=obj

with bpy.data.libraries.load(str(B/'pitch_shims_candidate.blend'),link=False) as (available,loaded):loaded.objects=[n for n in available.objects if n.startswith('Shim_')]
for obj in loaded.objects:bpy.context.collection.objects.link(obj);stocks[obj.name]=obj
pitch_poses=json.loads((B/'pitch_kinematics_review.json').read_text())['poses']
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(context/'context.glb'))
sources={row['name']:row for row in metadata['draws']};world=[]
structural_wall_roles={(row['room'],row['wall']) for row in metadata['wall_boxes']}
def bounds(obj,pose):
    points=[pose@Vector(v) for v in obj.bound_box]
    return [min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
def overlaps(a,b):return all(a[i]<=b[i+3]+1e-6 and a[i+3]>=b[i]-1e-6 for i in range(3))
def tree(obj,pose):
    bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(pose);bm.normal_update();result=BVHTree.FromBMesh(bm);bm.free();return result
for obj in bpy.data.objects:
    if obj in before or obj.type!='MESH':continue
    source=sources[obj.name.split('.')[0]];world.append((obj,source,bounds(obj,obj.matrix_world),tree(obj,obj.matrix_world)))
distribution=[row for row in world if '/HeatingDistribution/' in row[1]['source']]
retired=[row for row in world if row[1]['source'].endswith('/F02_B_RADIATOR_MASS')]
world=[row for row in world if row not in distribution and row not in retired and '/RadiatorTiePlates/' not in row[1]['source']]
proposed_furniture=[]
for index,(obj,source,bb,bvh) in enumerate(world):
    if '/1D_din_t/' in source['source']:
        # Explicit uninstalled furniture proposal, never a waiver of contact.
        pose=Matrix.Translation((0,-.12,0))@obj.matrix_world
        world[index]=(obj,source,bounds(obj,pose),tree(obj,pose))
        proposed_furniture.append(dict(source=source['source'],translation_building=[0,0,.12],reason='Clear actual fixed floor supply; move table and stance together in source on integration'))
# Production explicitly retires this old visual and disables its shapes. The
# acquired mesh contains hidden descendants too; do not mistake it for a live prop.
runtime_source=(R/'game/scripts/building/orison_v2_runtime_root.gd').read_text()
assert '_retire_blockout_fixture("F02_B_RADIATOR_MASS")' in runtime_source
assert 'fixture.visible = false' in runtime_source and '(node as CollisionShape3D).disabled = true' in runtime_source
with bpy.data.libraries.load(str(R/'art/blender/heating_distribution.blend'),link=False) as (available,loaded):loaded.objects=available.objects
for obj in loaded.objects:
    if obj.type!='MESH':continue
    bpy.context.collection.objects.link(obj)
    source=dict(source='RETAINED_NATIVE_DISTRIBUTION/'+obj.name,retained_stock=obj.name)
    world.append((obj,source,bounds(obj,obj.matrix_world),tree(obj,obj.matrix_world)))
contacts=[];unexplained=[];states=[];pose_cache={};samples=[];reused_samples=0
for bay in bays['branches']:
    actor=bay['id'];count=bay['sections'];half=(count-1)*.092/2;shift=bay['body_shift_candidate_m']
    frame=bay['actor_frame_building'];p=frame['position'];pose=Matrix.Translation((p[0],-p[2],p[1]))@Matrix.Rotation(frame['yaw'],4,'Z')
    for row in [r for r in pitch_poses if r['sections']==count]:
        for progress in [0,.2,.4,.7,1,1.25,1.5,1.75,2]:
            opening=.04*max((min(progress,1)-.4)/.6,0);peel=max(progress-1,0);backoff=.001*min(progress/.4,1);withdraw=Matrix.Translation((opening,0,0));pitch=row['pitch'];body=withdraw@Matrix(row['body_matrix']);a=Vector(row['fixed_joint']);b=Vector(row['header_joint']);beta=row['feed_angle_radians'];theta=row['body_angle_radians']
            up=Matrix.Translation(a)@Matrix.Rotation(-beta,4,'Y');down=Matrix.Translation(b)@Matrix.Rotation(-theta,4,'Y');bearing=Matrix.Translation(b)@Matrix.Rotation(-beta,4,'Y')
            parts=[(stocks['ArticulatedValveHousing'],Matrix.Identity(4)),(stocks['SweptSupplyElbow'],Matrix.Identity(4)),(stocks['FixedStemPacking'],Matrix.Translation((0,.03,0)))]
            for name in ['ThreadedMovingValveCore','SixSpokeHandwheel']:parts.append((stocks[name],Matrix.Translation((-.53,.03,.396))@Matrix.Rotation(3.5*math.tau,4,'Z')))
            parts.extend([(stocks['SphericalNeck_%d'%count],up),(stocks['FloatingMetalBearingRing'],Matrix.Translation(a)),(stocks['ValveSphericalRetainer'],up),(stocks['PackedHeaderSocket'],withdraw@down),(stocks['FloatingMetalBearingRing'],bearing),(stocks['HeaderSphericalRetainer'],withdraw@down@Matrix.Translation((backoff,0,0)))])
            for index in range(count):parts.append((stocks['CastSectionThreeColumnCandidate'],body@Matrix.Translation(((index-(count-1)/2)*.092+shift,.03,.105))))
            for x in [-half,half]:parts.append((stocks['CastShoeFoot'],body@Matrix.Translation((x+shift,.03,0))))
            if pitch:parts.append((stocks['Shim_%d_%s_%s'%(count,str(pitch).replace('-','minus'),'supply' if pitch<0 else 'far')],withdraw))
            for name,point,rotation in [('BlindHeaderPlug',(-half+shift-.046,.085,.72),math.pi),('BlindHeaderPlug',(half+shift+.046,.085,.19),0),('VentHeaderReducer',(half+shift+.046,.085,.72),0)]:
                xf=body@Matrix.Translation(point)@Matrix.Rotation(rotation,4,'Z');parts.extend([(stocks[name],xf),(stocks['HeaderSealWasher'],xf)])
            vent_pose=body@Matrix.Translation((half+shift+.046,.085,.72))
            for vent_name in ['VentBody','VentCap','FloatAndNeedle','VentOrificeInsert_2']:
                parts.append((stocks[vent_name],vent_pose))
            packing_offset=max((peel-.5)/.5,0)*.12
            parts.append((packing_poses[peel],Matrix.Translation((0,packing_offset,0))@down))
            support_backings=set()
            for mount in [m for m in support_mounts if m['actor']==actor]:
                cx,cy,cz=mount['column_local_blender']
                fixed=Matrix.Translation((cx,mount['bracket_front_y'],cz))
                parts.extend([(stocks['SlottedWallBracket'],fixed),(stocks[mount['hardware']],fixed),(stocks[mount['rod']],body@Matrix.Translation((cx,cy,cz)))])
                support_backings.update([mount['backing_source'],mount['upper_bearing_source'],mount['lower_bearing_source']])
            state_sample_ids=[]
            states.append(dict(id=actor,pitch=pitch,progress=progress,opening_m=opening,sections=count,parts=len(parts),samples=state_sample_ids))
            for obj,local in parts:
                transform=pose@local@obj.matrix_world
                signature=(actor,obj.name,tuple(value for row in transform for value in row))
                if signature in pose_cache:
                    state_sample_ids.append(pose_cache[signature]);reused_samples+=1;continue
                sample_id=len(samples);pose_cache[signature]=sample_id;state_sample_ids.append(sample_id)
                samples.append(dict(actor=actor,part=obj.name,matrix=[list(row) for row in transform]))
                bb=bounds(obj,transform);candidate=None
                for other,source,wb,other_tree in world:
                    path=source['source']
                    if '/'+actor+'/' in path:continue # explicitly replaced visual owner
                    if source.get('retained_stock') in [actor+'__UnionTailpiece',actor+'__Tailpiece']:continue
                    if not overlaps(bb,wb):continue
                    if candidate is None:candidate=tree(obj,transform)
                    hits=candidate.overlap(other_tree)
                    if not hits:continue
                    expected=None
                    # World floor Z is Blender height. Only flush seating at the
                    # actual contact plane is accepted; penetration is not waived.
                    if '/Floor' in path and (obj.name in ['CastShoeFoot','SweptSupplyElbow'] or obj.name.startswith('Shim_')) and abs(min((transform@vertex.co).z for vertex in obj.data.vertices)-wb[5])<.00001:
                        expected='Flush shoe/supply base on actual floor plane'
                    if source.get('retained_stock')==actor and obj.name=='SweptSupplyElbow' and abs(min((transform@vertex.co).z for vertex in obj.data.vertices)-wb[5])<.00001:
                        expected='Flush new supply base on the same retained branch endpoint'
                    verified_core_alias=False
                    if obj.name.startswith('WallAnchors_') and tuple(path.split('/')[-2:]) in structural_wall_roles:
                        rear=-int(obj.name.split('_')[1].removesuffix('um'))*1e-6
                        inverse=transform.inverted();direction=transform.to_3x3()@Vector((0,-1,0))
                        for anchor_z in [.080,-.060]:
                            at,normal,face,distance=other_tree.ray_cast(transform@Vector((.020,.010,anchor_z)),direction,.12)
                            if at is not None and normal.dot(direction)<-.9 and abs((inverse@at).y-(rear+.025))<1e-5:
                                verified_core_alias=True
                    if (path in support_backings or verified_core_alias) and (obj.name=='SlottedWallBracket' or obj.name.startswith('WallAnchors_')):
                        inside=[]
                        inverse=transform.inverted()
                        for vertex in obj.data.vertices:
                            point=transform@vertex.co
                            hit,normal,face,distance=other_tree.find_nearest(point)
                            depth=-(point-hit).dot(normal)
                            if depth>1e-6:inside.append((inverse@point,depth))
                        if obj.name=='SlottedWallBracket' and not inside:
                            expected='Declared stand-off foot seats on its actual finished backing; no sampled penetration'
                        if obj.name.startswith('WallAnchors_'):
                            rear=-int(obj.name.split('_')[1].removesuffix('um'))*1e-6
                            if all(abs(point.x-.020)<=.0031 and min(abs(point.z-.080),abs(point.z+.060))<=.0031 and rear-1e-5<=point.y<=.00801 and depth<=.026 for point,depth in inside):
                                expected='Only declared anchor-stud envelopes, bounded25mm core embedment; retained collision-wall aliases require an actual facing ray at the identical backing plane' if verified_core_alias else 'Only the two declared anchor-stud envelopes enter the identified backing, bounded25mm core embedment'
                    contact=dict(actor=actor,opening=opening,pitch=pitch,part=obj.name,other=source,triangle_pairs=len(hits),candidate_bounds=bb,world_bounds=wb,expected=expected)
                    contact['sample_id']=sample_id;contacts.append(contact)
                    if expected is None:unexplained.append(contact)
    print('BAY',actor,'reviewed',flush=True)
assert support_sha256==hashlib.sha256((B/'sliding_wall_ties_candidate.blend').read_bytes()).hexdigest(),'Support source changed during review'
assert candidate_sha256==hashlib.sha256((B/'packed_union_candidate.blend').read_bytes()).hexdigest(),'Candidate changed during world acquisition'
assert vent_sha256==hashlib.sha256((B/'automatic_vent_finished_candidate.blend').read_bytes()).hexdigest(),'Vent changed during world acquisition'
report=dict(evidence_class='INERT',scope='UNINSTALLED regenerated portable family plus native fixed/captive anti-tip supports; actual triangle review in23acquiredrooms at5pitchsettings and9staged service/peel positions. Explicit proposed12cm1Dtablemove and replacement ofsameactorvisuals/oldtailonly. Retaineddistribution checked asindividualnativestocks. Old RadiatorTiePlates explicitly proposed for retirement. Exact identical actor/mesh/matrix samples reused within this immutable geometry acquisition. No exhaustivecontainment, pressure or custody, runtimeorhumanacceptance.',context_sha256=metadata['context_sha256'],native_sha256=candidate_sha256,vent_native_sha256=vent_sha256,shim_native_sha256=hashlib.sha256((B/'pitch_shims_candidate.blend').read_bytes()).hexdigest(),retained_native_sha256=hashlib.sha256((R/'art/blender/heating_distribution.blend').read_bytes()).hexdigest(),retirement_source_sha256_lf=hashlib.sha256(runtime_source.replace('\r\n','\n').encode()).hexdigest(),proposed_furniture=proposed_furniture,support_native_sha256=support_sha256,states=states,samples=samples,reused_samples=reused_samples,contacts=contacts,unexplained=unexplained)
(P/'portable_final_world_fit.json').write_text(json.dumps(report,indent=2)+'\n');print('SUPPORTED FAMILY WORLD FIT',len(states),'states',len(contacts),'contacts',len(unexplained),'unexplained',flush=True)
if unexplained:raise RuntimeError('Resolve articulated candidate/world contacts before integration')
