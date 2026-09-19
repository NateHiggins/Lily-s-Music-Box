from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[3]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths=['.gitattributes','tools/build_v2_passage_gateway.py','tools/build_v2_street_section.py','tools/relocate_v2_subway_pavement.py',
 'game/assets/building/orison_v2/exterior/passage_gateway.gltf',
 'game/assets/building/orison_v2/exterior/passage_gateway_subway.bin',
 'game/data/orison_v2/exterior/exterior_geometry.json','game/data/orison_v2/exterior/passage_gateway_source.json',
 'game/tests/orison_v2_subway_route_test.gd','game/tests/OrisonV2SubwayRouteTest.tscn',
 'game/tests/orison_v2_subway_overview.gd','game/tests/OrisonV2SubwayOverview.tscn',
 'game/tests/orison_v2_earned_conversation_route_test.gd','game/tests/OrisonV2EarnedConversationRouteTest.tscn']
packet=root/'design/astra/evidence/v2_subway_relocation_01'
assert '18 waypoints; 0 failures' in (packet/'route_05.log').read_text()
assert not (packet/'route_05.log.stderr').read_bytes()
conversation=root/'design/astra/evidence/v2_earned_conversation_01'
assert '76 waypoints; 0 failures' in (conversation/'route_02.log').read_text()
assert not (conversation/'route_02.log.stderr').read_bytes()
section=root/'game/data/orison_v2/exterior/street_section_source.json'
report=json.loads(section.read_text())
report['geometry_sha256']=sha(root/'game/data/orison_v2/exterior/exterior_geometry.json')
section.write_text(json.dumps(report,indent=2)+'\n')
paths.append(section.relative_to(root).as_posix())
receipt={'base_head':'2064e5d','status':'SUBWAY_RELOCATED_CONNECTED_TRAVERSAL_PASS',
 'source_sha256':{p:sha(root/p) for p in paths},
 'evidence_sha256':{p.relative_to(root).as_posix():sha(p) for directory in [packet,conversation]
 for p in sorted(directory.rglob('*')) if p.is_file() and p.name!='source_hashes.json'}}
(packet/'source_hashes.json').write_text(json.dumps(receipt,indent=2)+'\n')
state_path=root/'design/astra/LIVE_STATE.json'
state=json.loads(state_path.read_text())
current=state['current_v2_completion_resume']
current['latest_committed_head']='2064e5d'
current['subway_entrance']='Owner-requested kiosk relocation: entire source assembly rotated along opposite sidewalk outside arcade, real pavement opening, existing closed gate preserved. Final 18-waypoint loop and approach plus 76-waypoint repair/conversation pass; empty stderr. See v2_subway_relocation_01.'
current['earned_conversation']='76 continuous waypoints now reach physical Mina after actual repair, persist the first-stable interpretation and release movement. Recurrence/integration/dream/wake remain open.'
for entry in ['evidence/v2_subway_relocation_01/README.md','evidence/v2_earned_conversation_01/README.md']:
 if entry not in current['evidence']:current['evidence'].append(entry)
current['next']='Continue full optical material/visual/total-effect performance gates and V2 second visit, physical manifestation placement, integration and dream/wake. Default stays V1 until the full completion gates pass.'
state_path.write_text(json.dumps(state,indent=2)+'\n')
paths+=['design/astra/LIVE_STATE.json','design/astra/evidence/v2_subway_relocation_01',
 'design/astra/evidence/v2_earned_conversation_01','design/astra/work/checkpoint_v2_subway.py']
subprocess.run(['git','add','--',*paths],cwd=root,check=True)
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--cached','--check'],cwd=root,check=True)
