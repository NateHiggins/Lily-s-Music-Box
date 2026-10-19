from pathlib import Path
p=Path('tmp/v2-fire-hand-20261019/stage28_relax_experiment.py')
s=p.read_text().replace("['stage27_mass9','stage27_mass10']", "['native_globalization']").replace("Path('art/reviews/v2_fire_hose_mass_20261019/cases',stem,'kernel_case.json')", "Path('game/tests/fixtures/fire_hose_globalization_case.json')").replace('range(256)','range(8192)').replace('[0,3,15,63,127,255]','[0,3,15,63,127,255,511,1023,2047,4095,8191]')
exec(compile(s,str(p),'exec'),{'__file__':str(p.resolve()),'__name__':'trial'})
