from pathlib import Path
import json,os,hashlib
ROOT=Path(__file__).resolve().parents[1]
version=os.environ.get('HOSE_NATIVE_SURVEY','world_coil_v2')
folder=ROOT/'art/reviews/v2_unracked_hose_20261022'/version
stages=[];seen={};aliases=[]
for source in sorted(folder.glob('*_pose.json')):
    data=json.loads(source.read_text())
    digest=hashlib.sha256(json.dumps(dict(frames=data['frames'],bind_frames=data['bind_frames']),sort_keys=True,separators=(',',':')).encode()).hexdigest()
    if digest in seen:
        aliases.append(dict(source=str(source.relative_to(ROOT)),identical_to=seen[digest],frame_sha256=digest));continue
    seen[digest]=str(source.relative_to(ROOT))
    stages.append(dict(script='art/blender/scripts/review_deployed_hose.py',env={
        'ORISON_HOSE_POSE':str(source),
        'ORISON_HOSE_POSE_SOURCE':str(ROOT/'art/blender/v2_unracked_hose/native_v1/blender/unracked_fire_hose.blend'),
        'ORISON_HOSE_POSE_OBJECT':'UnrackedHose','ORISON_HOSE_POSE_RINGS':'135',
        'ORISON_HOSE_POSE_REVIEW_OUT':str(ROOT/'tmp/v2-unracked-hose-20261022'/(version+'_native_'+source.stem))}))
assert stages,'No clear poses to review'
target=ROOT/'tmp/v2-unracked-hose-20261022'/(version+'_native_plan.json')
target.write_text(json.dumps(dict(stages=stages),indent=2)+'\n',newline='\n')
alias_file=folder/'native_pose_aliases.json'
alias_file.write_text(json.dumps(dict(evidence_class='INERT',scope='Exact canonical imported bind/current frame identity. Reuse native geometry review only.',aliases=aliases),indent=2)+'\n',newline='\n')
print(len(stages),'native review stages')
