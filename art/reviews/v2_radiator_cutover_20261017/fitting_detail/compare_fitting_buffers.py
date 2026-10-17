from pathlib import Path
p=Path(__file__).with_name('compare_cast_retained_buffers.py')
s=p.read_text()
s=s.replace('cast_detail_metric/radiator_mechanisms.glb','fitting_detail/radiator_mechanisms.glb')
s=s.replace('cast_surface_prepared/radiator_mechanisms.glb','cast_detail_metric/radiator_mechanisms.glb')
s=s.replace("allowed={'CastSectionThreeColumnCandidate','CastShoeFoot'}", "allowed={'BlindHeaderPlug','VentHeaderReducer','ValveSphericalRetainer','HeaderSphericalRetainer','PackedHeaderSocket'}")
s=s.replace('cast_detail_retained_buffers.json','fitting_detail_retained_buffers.json')
exec(compile(s,str(p),'exec'))
