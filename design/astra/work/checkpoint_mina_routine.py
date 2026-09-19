from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[3]
paths=['game/data/orison_v2/room_lighting.json','game/data/orison_v2_blockout.json','game/scripts/building/orison_v2_domestic_doors.gd','game/scripts/building/orison_v2_runtime_root.gd','game/scripts/characters/animated_resident.gd','game/scripts/game/reality_case_manager.gd','game/tests/orison_v2_golden_repair_route_test.gd','game/tests/orison_v2_connected_world_test.gd','game/data/orison_v2/mina_routine.json','game/scripts/characters/orison_v2_mina_routine.gd','game/scripts/characters/mina_idle_animation.gd','game/scripts/building/orison_v2_laundry.gd','game/tests/orison_v2_mina_routine_test.gd','game/tests/mina_pose_review.gd','game/tests/orison_v2_laundry_route_test.gd','game/tests/orison_v2_mail_route_test.gd']
paths += ['game/tests/'+name+'.tscn' for name in ['OrisonV2MinaRoutineTest','OrisonV2MinaReturnTest','OrisonV2MinaDomesticRoutineTest','OrisonV2MinaMailRoutineTest','OrisonV2MinaLaundryRoutineTest','OrisonV2MinaOffMapTest','MinaPoseReview','OrisonV2LaundryRouteTest','OrisonV2MailRouteTest']]
packet=root/'design/astra/evidence/v2_mina_routine_01'
(packet/'source_hashes.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
with (packet/'README.md').open('a') as f:
 f.write('\n`save_matrix.log` passes all 38 checks and all four V1/V2 disk-save directions, preserving calendar, inventory and case selections. Stderr contains the deliberate invalid-selector warning and existing V1 found-art warning; no new errors. Actor mid-route persistence is not part of this matrix.\n')
state_path=root/'design/astra/LIVE_STATE.json'
state=json.loads(state_path.read_text())
current=state['current_v2_completion_resume']
current['latest_committed_head']='954a6e7 (Mina checkpoint follows; see git history)'
current['mina_routine']='Physical timetable-driven Mina: bodega, domestic, mail, laundry and observed off-map round trips pass. Corrected own-skeleton idle and case activation. 73-waypoint actual complaint/repair; 17 laundry and 16 mail player waypoints; 521 composition, 29 service and 38 four-direction disk-save checks pass. Exact actor travel persistence and activities remain open.'
current['evidence'].append('evidence/v2_mina_routine_01/README.md')
current['next']='Owner reprioritized flashlight: retire photographic overlay and integrate reviewed volumetric/voxel lamp work with real scene occlusion, matched rendered review and performance/lifecycle evidence. Full golden shift resumes afterward.'
state_path.write_text(json.dumps(state,indent=2)+'\n')
paths+=['design/astra/LIVE_STATE.json','design/astra/evidence/v2_mina_routine_01','design/astra/work/checkpoint_mina_routine.py']
subprocess.run(['git','add','--',*paths],cwd=root,check=True)
subprocess.run(['git','diff','--cached','--check'],cwd=root,check=True)
subprocess.run(['git','diff','--cached','--stat'],cwd=root,check=True)
