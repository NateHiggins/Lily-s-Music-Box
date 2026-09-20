from pathlib import Path
import hashlib,json,subprocess,shutil,re
repo=Path(r'C:\ov\astra-main-acdb4be')
work=Path(__file__).parent
proof=repo/'art/renders/dream_critter_blender_rebuild_20260919'
native=proof/'native'
data=json.loads((native/'captures/dream_blender_critters.json').read_text(encoding='utf-8'))
assert data['failures']==0
f=data['frame_sample']
p=repo/'design/astra/DREAM_CRITTER_BLENDER_REBUILD_2026-09-19.md'
s=p.read_text(encoding='utf-8')
s=s.replace('It keeps two bounded controller batches, each with an opaque surface and one\nshared membrane surface.', 'It keeps two bounded controller batches, each with an opaque organ surface\nand one shared outer-envelope surface. The complete cortex, cilia and claws\nshare one lighting pass; only authored thin-window values admit transmission.')
s=s.replace('This does not substitute for the pending Godot import comparison.','The subsequent Godot comparison also passes for all 32 imports.')
start=s.index('## Native status and remaining verification')
end=s.index('## Reproduce and inspect',start)
s=s[:start]+f'''## Native verification and review

The shared lane became free after the owner closed Project Manager. Both
imports completed successfully. The final all-sixteen diagnostic passes
**486/486 checks**, with empty captured errors, warnings and stderr. It covers
all 32 imported pose arrays, attachment atlases, malformed manifest rejection,
complete-envelope/opaque-organ index partitions, stable draw identities,
count variants, inspection LODs, paused light rebinding and resource release.
These are scoped INERT diagnostics, not schema-2 campaign runtime contracts.

The first native run exposed JSON float-versus-integer Array equality in
Euplotes admission. The decoder now checks exact numeric values, refusing
fractional and string controls as well as the wrong cirral mapping. Original
attempt receipts are retained under the native review folder.

Existing controller clocks were observed for 18 seconds without writing
their state. All sixteen advanced their own phase; the seam grazer stayed
folded and Noctiluca did not spontaneously flash during that interval. Their
unfold/flash review captures are explicitly staged. The fixture also saves
the Fold Crab's real support-frame feet before its controlled poses.

The [native gallery](../../art/renders/dream_critter_blender_rebuild_20260919/native/index.html)
contains 150 full captures, with neutral 0/half/full poses, cutaways, dark,
oblique and accumulated-lamp views, appendage counts, jaws and hunting reach.
All sixteen were visually inspected. The Listener's broad mineral shading
was narrowed to its existing anatomical ridges; sustained light preserves
wine tissue. Wall-mounted specimens and Fold Crab use clearer default views.
The complete outer envelope now stays in one lighting pass, avoiding the
artificial polygon boundary from splitting smooth tissue at a window threshold.
Opaque internal organs retain depth. The shared draw and triangle budgets
are unchanged; this is approximate transmission, not physical refraction.

The last frame sample records 240 desktop frame intervals: median
{f['median_ms']:.3f} ms and p95 {f['p95_ms']:.3f} ms, {int(f['draw_calls'])} whole-warehouse draw calls
and {int(f['primitives'])} primitives at the fixed Tardigrade camera. CPU clocks were
paused; this includes the rescued hero, palps and architecture. It is not GPU
timing or a performance guarantee. The shared pose atlas is approximately
116 MiB (1024 x 7413 RGBAF), covering both detail levels of all sixteen.

Regressions pass: zoo 147/147, debug entry 13/13 and existing critters 70/70.
The entry test was repeated after the camera/text fixes and also passes.
Full-world entry and critter logs retain previously observed resident-route
errors; they are not globally clean runs. The isolated zoo and Blender logs
have no native errors. The final reader gate reports zero NEW unread fields.

Fine cilia remain bundled and internal organs simplified for the budgets.
Fold limbs are deliberately laminated blades; their knee overlap depends on
view angle, and nominal/source contact checks do not prove every live
raycast pose. Lacrymaria's default view leaves room for its full search reach;
use the wheel for close inspection. Closely layered cells and membranes use
approximate alpha sorting. Finite pose checks are not a continuum collision
proof. This pass is available for owner art review; acceptance is not claimed.

The [source gallery](../../art/renders/dream_critter_blender_rebuild_20260919/gallery/index.html)
remains separate: its sixteen previews match the committed LOD0 Blender
sources but use controlled studio shading. Historical lane blockage is
retained in lane_blocker.json; it no longer blocks this pass.

''' + s[end:]
s=re.sub(r'Last line: source rebuild complete; expanded runtime integration awaiting\nnative verification because the shared Godot lane is occupied\.',
         'Last line: all-sixteen Blender rebuild and native debug integration verified;\nreview gallery, diagnostics and reproducible sources saved on the work branch.',s)
p.write_text(s,encoding='utf-8',newline='\n')
p=repo/'DOCS.md';s=p.read_text(encoding='utf-8')
s=s.replace('Editable Blender sources and warehouse integration for all sixteen critters, source checks and pending native verification',
            'Editable Blender sources, native warehouse gallery and completed verification for all sixteen critters')
p.write_text(s,encoding='utf-8',newline='\n')
p=proof/'README.md'
p.write_text('''Evidence class: **INERT**

[Implementation and verification report](../../../design/astra/DREAM_CRITTER_BLENDER_REBUILD_2026-09-19.md).

[Native warehouse gallery](native/index.html): all sixteen, 150 captures,
486/486 scoped diagnostic checks. Full images and receipts are retained.
[Native review summary](native/review_summary.json).

[Blender source gallery](gallery/index.html): source-hash-matched studio views.
All 32 LOD exports pass anatomy and raw GLB checks. These source and native
diagnostics are not campaign runtime_contract evidence or owner art acceptance.

Earlier Project Manager lane blockage is preserved in lane_blocker.json;
the owner subsequently freed the lane and verification completed.
Full-world regression logs retain existing resident-route errors.
''',encoding='utf-8',newline='\n')
p=proof/'gallery/index.html';s=p.read_text(encoding='utf-8')
old='Source checks pass. The expanded in-engine warehouse review is pending; these studio plates do not use the native voxel light or GPU joint deformation.'
assert old in s;s=s.replace(old,'Source and native checks pass. <a href="../native/index.html">Open the native warehouse gallery</a> for voxel light and GPU deformation; these plates retain controlled studio shading.')
p.write_text(s,encoding='utf-8',newline='\n')
gate=subprocess.run(['C:/Users/nate_/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe','tools/audit_data_consumption.py','--baseline'],cwd=repo,capture_output=True)
assert gate.returncode==0 and b'NEW: 0' in gate.stdout
(native/'reader_gate.log').write_bytes(gate.stdout.replace(b'\r\n',b'\n'))
for name in ['package_native_review.py','finalize_native_docs.py']:
    shutil.copy2(work/name,native/name)
p=proof/'implementation_sources.json';inv=json.loads(p.read_text(encoding='utf-8'))
inv['native_status']='PASS_486_OF_486'
inv['native_diagnostic']='native/captures/dream_blender_critters.json'
for row in inv['files']:
    blob=(repo/row['path']).read_bytes()
    if row['hash_mode']=='LF-normalized':blob=blob.replace(b'\r\n',b'\n')
    row['sha256']=hashlib.sha256(blob).hexdigest()
for rel in ['game/shaders/dream_critter_blender_fold.gdshaderinc.uid','game/tests/dream_blender_decoder_controls.gd.uid']:
    if not any(row['path']==rel for row in inv['files']):
        inv['files'].append({'path':rel,'sha256':hashlib.sha256((repo/rel).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'hash_mode':'LF-normalized'})
p.write_text(json.dumps(inv,indent=2)+'\n',encoding='utf-8',newline='\n')
file_rows=[]
for p in sorted(native.rglob('*')):
    if p.is_file():file_rows.append({'path':p.relative_to(proof).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
(native/'files.json').write_text(json.dumps({'evidence_class':'INERT','files':file_rows},indent=2)+'\n',encoding='utf-8')
print('Updated implementation report, gallery, reader gate, source hashes and native evidence inventory.')
