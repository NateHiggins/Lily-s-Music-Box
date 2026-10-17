"""Verify archived native diagnostics; never confers runtime acceptance."""
from pathlib import Path
import argparse,gzip,hashlib,json,os,runpy,shutil,sys,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=ROOT/'tmp/v2-radiator-native-packet-check')
    parser.add_argument('--historical',action='store_true')
    parser.add_argument('--prepare-world-replay',action='store_true')
    args=parser.parse_args();out=args.out.resolve();root=ROOT.resolve()
    assert out!=root and not out.is_relative_to(root/'game') and not out.is_relative_to(root/'art'),'Use disposable output'
    out.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((HERE/'packet_manifest.json').read_text())
    for name,digest in manifest['files'].items():
        path=(HERE/name).resolve();assert path.is_relative_to(HERE.resolve())
        assert sha(path.read_bytes())==digest,name
    for name,digest in manifest.get('uncompressed_sha256',{}).items():
        with gzip.open(HERE/(name+'.gz'),'rb') as stream:assert sha(stream.read())==digest,name
    with gzip.open(HERE/'world_context.json.gz','rt',encoding='utf-8') as stream:context=json.load(stream)
    with gzip.open(HERE/'world_fit.json.gz','rt',encoding='utf-8') as stream:world=json.load(stream)
    digest=hashlib.sha256()
    with gzip.open(HERE/'world_context.glb.gz','rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk)
    assert digest.hexdigest()==context['context_sha256']==world['context_sha256']
    assert sha((HERE/'emitter_bays.json').read_bytes())==context['route_sha256']
    assert not world['unexplained'] and len(world['states'])==1035
    samples=world['samples'];references=0
    for state in world['states']:
        assert len(state['samples'])==state['parts']
        for index in state['samples']:
            assert 0<=index<len(samples) and samples[index]['actor']==state['id']
        references+=len(state['samples'])
    assert references==len(samples)+world['reused_samples']
    payload=out/'portable_build_final';payload.mkdir(exist_ok=True)
    assets=['automatic_vent_scratch.glb','packed_union_scratch.glb','sliding_wall_ties_scratch.glb','pitch_shims_scratch.glb']
    with zipfile.ZipFile(HERE/'native_outputs.zip') as archive:
        build=json.loads(archive.read('build_manifest.json'));assert build['status']=='PASS'
        for name,digest in build['outputs_sha256'].items():
            raw=archive.read(name)
            if Path(name).suffix in {'.py','.gd','.json'}:raw=raw.replace(b'\r\n',b'\n')
            assert sha(raw)==digest,name
        for key,name in [('native_sha256','packed_union_candidate.blend'),('vent_native_sha256','automatic_vent_finished_candidate.blend'),('support_native_sha256','sliding_wall_ties_candidate.blend'),('shim_native_sha256','pitch_shims_candidate.blend')]:assert world[key]==sha(archive.read(name)),name
        for preview in manifest['previews']:assert sha(archive.read(preview['archive_entry']))==preview['sha256']
        for name in ['union_packing_review.json','sliding_wall_ties_review.json','tie_casting_fit_review.json','packing_morph_buffer_review.json']:
            assert not json.loads(archive.read(name))['failures'],name
        for name in assets:(payload/name).write_bytes(archive.read(name))
        if args.prepare_world_replay:
            for entry in archive.infolist():
                if entry.is_dir():continue
                target=(payload/entry.filename).resolve();assert target.is_relative_to(payload.resolve())
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.read(entry))
    sys.path.insert(0,str(root/'art/blender/scripts'))
    from check_exported_tangents import validate
    buffers=[validate(payload/name) for name in assets]
    os.environ['ORISON_RADIATOR_BUILD_ROOT']=str(root);os.environ['ORISON_RADIATOR_BUILD_OUT']=str(payload)
    sys.path.insert(0,str(HERE/'native_recipe'))
    runpy.run_path(str(HERE/'native_recipe/check_morph_buffers.py'),run_name='__main__')
    morph=json.loads((payload/'packing_morph_buffer_review.json').read_text());assert not morph['failures']
    sys.path.insert(0,str(root/'tools'))
    from audit_orison_v2_completeness import runtime_inputs_sha256
    from v2_surface_evidence import inputs
    current=runtime_inputs_sha256(root)==context['runtime_inputs_sha256'] and inputs(root)['sha256']==context['rendering_inputs_sha256']
    assert world['retained_native_sha256']==sha((root/'art/blender/heating_distribution.blend').read_bytes()) or args.historical
    assert current or args.historical,'Historical snapshot: current source differs; use --historical for integrity-only review'
    if args.prepare_world_replay:
        directory=out/'preinstall_context';directory.mkdir(exist_ok=True)
        with gzip.open(HERE/'world_context.glb.gz','rb') as source,(directory/'context.glb').open('wb') as target:shutil.copyfileobj(source,target)
        with gzip.open(HERE/'world_context.json.gz','rb') as stream:(directory/'context.json').write_bytes(stream.read())
        shutil.copyfile(HERE/'emitter_bays.json',out/'all_emitter_bays.json')
        shutil.copyfile(HERE/'world_review_as_executed.py',out/'review_portable_final_world_fit.py')
    report=dict(evidence_class='INERT',scope='Archived native artifact integrity and freshly evaluated final GLB base/morph buffers; historical/current geometry snapshot only, never runtime or human acceptance.',status='PASS',current_inputs_match=current,world_states=len(world['states']),unique_part_poses=len(samples),reused_part_poses=world['reused_samples'],buffers=buffers,morph_samples=len(morph['samples']))
    (out/'packet_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('NATIVE PACKET PASS:',len(buffers),'GLBs;',len(morph['samples']),'morph samples;',len(world['states']),'archived world states; current inputs',current,flush=True)
if __name__=='__main__':main()
