"""Project the physical cap travel and collision envelope from native stock.
Manufacturing/sampling choices belong to art; only runtime inputs ship to Godot.
"""
import argparse,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/data/orison_v2/radiator_vent_thread_source.json'
TARGET=ROOT/'game/data/orison_v2/radiator_vent_thread.json'

def project(source):
    if isinstance(source.get('schema_version'),bool) or source.get('schema_version')!=1:raise ValueError('Unsupported thread source schema')
    for key in ['pitch_m','engagement_m','root_radius_m','crest_radius_m','female_radial_clearance_m','entry_chamfer_m','stem_bottom_m','shoulder_m','crest_fraction','flank_angle_degrees','angular_samples','samples_per_pitch']:
        value=source.get(key)
        if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or value<=0:raise ValueError('Invalid thread dimension: '+key)
    if abs(source['shoulder_m']-source['stem_bottom_m']-source['engagement_m'])>1e-9:raise ValueError('Thread engagement contradicts actual shoulder')
    if not 1<=source['engagement_m']/source['pitch_m']<=24:raise ValueError('Thread travel outside supported hand range')
    if not source['root_radius_m']<source['crest_radius_m'] or source['female_radial_clearance_m']>=(source['crest_radius_m']-source['root_radius_m'])/2:raise ValueError('Invalid mating radial stock')
    if not 20<=source['flank_angle_degrees']<=80 or not 0<source['crest_fraction']<.5:raise ValueError('Invalid thread profile')
    for key,minimum in [('angular_samples',32),('samples_per_pitch',8)]:
        if source[key]!=int(source[key]) or source[key]<minimum:raise ValueError('Insufficient native thread samples')
    return {key:source[key] for key in ['schema_version','pitch_m','engagement_m','crest_radius_m']}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    result=project(json.loads(SOURCE.read_text()))
    if args.check:
        if json.loads(TARGET.read_text())!=result:raise SystemExit('Runtime vent thread projection is stale')
    else:TARGET.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Runtime vent thread projection matches native stock: pitch / engagement / carried envelope')
if __name__=='__main__':main()
