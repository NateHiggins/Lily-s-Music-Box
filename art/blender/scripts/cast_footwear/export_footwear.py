"""Protected canonical export of existing private nativeauthoringtruth. No emittedasset edits/render."""
from pathlib import Path
import bpy,bmesh,numpy as np,json,hashlib,ast,sys,math,os,re,struct
import argparse,shutil
ap=argparse.ArgumentParser();ap.add_argument('--repo',required=True,type=Path);ap.add_argument('--original',required=True,type=Path);ap.add_argument('--control',required=True,type=Path);ap.add_argument('--repaired',required=True,type=Path);ap.add_argument('--output',required=True,type=Path);ap.add_argument('--person',required=True);ap.add_argument('--part',required=True);ap.add_argument('--pbr-dir',required=True,type=Path);ap.add_argument('--tangent-guide',action='store_true');ap.add_argument('--preserve-unchanged-native',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);R=args.repo;O=args.output;O.mkdir(parents=True,exist_ok=False);TRUTH=args.control.parent;CURRENT=args.original;SOURCES={'NATIVE_CURRENT_PBR_CONTROL.blend':args.control,'NATIVE_CURRENT_PBR_WEIGHT_REPAIRED.blend':args.repaired};PBR=args.pbr_dir;
OWNER=R/'art/blender/scripts/export_cast_actor.py';sys.path.insert(0,str(OWNER.parent))
from cast_export_derivatives import _read,_remap
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();g=json.loads(CURRENT.read_text());raw=[(CURRENT.parent/b['uri']).read_bytes()for b in g['buffers']];paths=[CURRENT,OWNER,OWNER.with_name('cast_export_derivatives.py'),*[CURRENT.parent/b['uri']for b in g['buffers']],*[PBR/i['uri']for i in g['images']],args.control,args.repaired];before={str(p):H(p)for p in paths}
def accessor(i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dt=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]);width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];assert not a.get('sparse');return np.ndarray((a['count'],width),dt,raw[v.get('buffer',0)],v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*width),dt.itemsize)).copy()
pr=g['meshes'][0]['primitives'][0];original={k:accessor(v)for k,v in pr['attributes'].items()};original_indices=accessor(pr['indices']).reshape(-1,3);palette=[g['nodes'][i]['name']for i in g['skins'][0]['joints']];canon=lambda n:n.replace('mixamorig:','');palette=[canon(n)for n in palette];assert len(palette)==76
scope=globals().copy();scope.update(WHO=args.person,MIN_AGREEMENT=.5,BODY_PICTURE_LIMIT=1024,PART_PICTURE_LIMIT=512);tree=ast.parse(OWNER.read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef))],type_ignores=[]),str(OWNER),'exec'),scope);controls=[]
for case,filename in [('control','NATIVE_CURRENT_PBR_CONTROL.blend'),('repair','NATIVE_CURRENT_PBR_WEIGHT_REPAIRED.blend')]:
 bpy.ops.wm.open_mainfile(filepath=str(SOURCES[filename]))
 image_by_basename={Path(im['uri']).name:(PBR/im['uri']).resolve()for im in g['images']}
 for image in bpy.data.images:
  basename=Path(bpy.path.abspath(image.filepath)).name
  if basename in image_by_basename:image.filepath=str(image_by_basename[basename])
 for im in g['images']:
  dst=O/case/im['uri'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(PBR/im['uri'],dst)
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');objects=[o for o in bpy.data.objects if o.type=='MESH'and o.get('part')==args.part and any(m.type=='ARMATURE'and m.object==rig for m in o.modifiers)];assert len(objects)==1 and len(rig.data.bones)==76
 assert set(canon(b.name)for b in rig.data.bones)==set(palette),'NativeRigBoneNamesChanged'
 baseline=g;assert [canon(baseline['nodes'][i]['name'])for i in baseline['skins'][0]['joints']]==palette,'ExistingCanonicalControlSkinPaletteChanged'
 authored={}
 for obj in objects:
  names={q.index:canon(q.name)for q in obj.vertex_groups}
  for v in obj.data.vertices:
   q=obj.matrix_world@v.co;key=tuple(np.array([q.x,q.z,-q.y],dtype='<f4').tolist());weights={names[x.group]:float(x.weight)for x in v.groups if names[x.group]in palette and x.weight>0}
   if key in authored:assert authored[key]==weights,'AmbiguousNativeCoincidentVertexWeights'
   authored[key]=weights
 if case=='control':control_authored={k:dict(v)for k,v in authored.items()}
 class ExactNamedWeights(scope['SmoothTangentRepair']):
  errors=[];reports=[];weight_report=[];image_bindings=[]
  def gather_image_hook(self,image,*unused):
   try:
    assert hasattr(image.uri,'data'),'ExpectedPreSerializationEncodedImage'
    data=image.uri.data;digest=hashlib.sha256(data).hexdigest();matches=[im for im in g['images']if H(PBR/im['uri'])==digest];assert len(matches)==1,'ImageByteIdentityNotUniqueOrChanged'
    uri=matches[0]['uri'];image.uri=uri
    self.image_bindings.append(dict(uri=uri,sha256=digest,source=str((CURRENT.parent/uri).resolve())))
   except Exception as e:type(self).errors.append('ImageURI:'+str(e))
  def gather_mesh_hook(self,mesh,*unused):
   try:
    self.repair(mesh)
    for primitive in mesh.primitives:
     if args.tangent_guide:
      sys.path.insert(0,str(Path(__file__).parent));from tangent_guide import apply_guide,load_guide
      apply_guide(primitive,load_guide(CURRENT),require_weights=(case=='control'))
     arrays={k:_read(a)for k,a in primitive.attributes.items()};indices=_read(primitive.indices).reshape(-1,3)
     assert np.array_equal(indices,original_indices),'WriterIndexCorrespondenceChanged'
     for k in original:
      if not k.startswith(('JOINTS_','WEIGHTS_')):assert np.array_equal(arrays[k],original[k]),'WriterGeometryCorrespondenceChanged:'+k
     assert set(arrays)==set(original),'WriterAttributeSetChanged'
     if case=='control':
      assert np.array_equal(arrays['JOINTS_0'],original['JOINTS_0'])and np.array_equal(arrays['WEIGHTS_0'],original['WEIGHTS_0']),'UnmodifiedControlWeightsDrifted'
      continue
     result_j=np.zeros_like(original['JOINTS_0']);result_w=np.zeros_like(original['WEIGHTS_0']);records=[]
     for vi,p in enumerate(arrays['POSITION']):
      key=tuple(p.tolist());assert key in authored,'MissingNativeAuthoredVertex';native=authored[key];old={palette[int(j)]:float(w)for j,w in zip(original['JOINTS_0'][vi],original['WEIGHTS_0'][vi])if w>0};new=dict(old);ratios=[]
      if args.preserve_unchanged_native and native==control_authored[key]:
       result_j[vi]=original['JOINTS_0'][vi];result_w[vi]=original['WEIGHTS_0'][vi];records.append(dict(vertex=vi,ratios=[],unchanged_native_row=True));continue
      for side in['Left','Right']:
       leg=side+'Leg';foot=side+'Foot';total=old.get(leg,0)+old.get(foot,0)
       if total==0:continue
       rawleg=native.get(leg,0);rawfoot=native.get(foot,0);assert rawleg+rawfoot>0,'LostAuthoredLegFootTotal';ratio=rawleg/(rawleg+rawfoot);nl=np.float32(total*ratio);nf=np.float32(total-float(nl));new[leg]=float(nl);new[foot]=float(nf);ratios.append(dict(side=side,authored_leg_fraction=ratio,reconstructed_leg_fraction=float(nl)/(float(nl)+float(nf)),old_pair_total=total,new_pair_total=float(nl)+float(nf)))
      positive=[(palette.index(n),np.float32(w))for n,w in new.items()if w>0];assert len(positive)<=4,'PositiveInfluenceCountExceeds4_NoPruneAllowed';positive.sort(key=lambda q:q[0])
      for k,(ji,w)in enumerate(positive):result_j[vi,k]=ji;result_w[vi,k]=w
      for n,w in old.items():
       if n not in['LeftLeg','LeftFoot','RightLeg','RightFoot']:assert new.get(n,0)==w,'ProtectedNamedWeightChanged:'+n
      records.append(dict(vertex=vi,ratios=ratios))
     primitive.attributes['JOINTS_0']=_remap(primitive.attributes['JOINTS_0'],result_j)
     primitive.attributes['WEIGHTS_0']=_remap(primitive.attributes['WEIGHTS_0'],result_w)
     self.weight_report.extend(records)
   except Exception as e:type(self).errors.append(str(e))
 import io_scene_gltf2
 io_scene_gltf2.glTF2ExportUserExtension=ExactNamedWeights;scope['OUT']=O/case;(O/case).mkdir(exist_ok=True);report=dict(renamed_materials={},completed_channels={});scope['prepare'](objects,512,report['renamed_materials'],report['completed_channels']);scope['export'](rig,objects,(args.person+'__'+args.part));assert not ExactNamedWeights.errors,ExactNamedWeights.errors;controls.append(dict(case=case,source_truth=str(SOURCES[filename]),source_truth_sha256=before[str(SOURCES[filename])],tangent_reports=ExactNamedWeights.reports,weight_ratios=ExactNamedWeights.weight_report,image_uri_bindings=ExactNamedWeights.image_bindings,errors=ExactNamedWeights.errors,prepare=report))
for case,_ in [('control',''),('repair','')]:
 outdoc=json.loads((O/case/(args.person+'__'+args.part+'.gltf')).read_text());assert [canon(outdoc['nodes'][i]['name'])for i in outdoc['skins'][0]['joints']]==palette,'ActualOutputSkinPaletteChanged'
 assert [im['uri']for im in outdoc['images']]==[im['uri']for im in g['images']],'ActualOutputImageURIsChanged'
 for im in outdoc['images']:assert H(O/case/im['uri'])==H(PBR/im['uri']),'CandidateOrInstallResolvedImageBytesMismatch'
assert all(H(p)==h for p,h in before.items());(O/'EXPORT_HOOK.json').write_bytes(json.dumps(dict(evidence_class='INERT_pre_serialization_protectedweight_nativeexport',input_hashes_before_after=before,controls=controls,limits='No emittedglTFhandedit. Nativeprivateblendauthoringtruth unchanged;protectedToe/othersreadfromcurrentcanonicalinput,FootLegratiosfromactualnativegroups.Independentnamedweightcomparisonrequired.'),indent=2).encode());print('PROTECTED_NATIVE_EXPORT_COMPLETE')
