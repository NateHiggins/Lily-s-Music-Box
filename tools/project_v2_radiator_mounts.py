"""Project the reviewed native wall-tie survey into runtime installation facts."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def project(build_directory: Path) -> dict:
    reviewed = json.loads((build_directory / 'sliding_wall_ties_review.json').read_text())
    assert not reviewed['failures']
    plan = ROOT / 'art/reviews/v2_radiator_native_20261017/native_recipe/mount_plan.json'
    assert hashlib.sha256(plan.read_bytes()).hexdigest() == reviewed['plan_sha256'], 'Changed wall survey'
    assert hashlib.sha256((build_directory / 'sliding_wall_ties_candidate.blend').read_bytes()).hexdigest() == reviewed['native_sha256'], 'Changed reviewed tie geometry'
    survey = json.loads(plan.read_text())
    facts = {}
    for mount in reviewed['mounts']:
        source = next(row for row in survey['ties']
                      if row['actor'] == mount['actor'] and row['side'] == mount['side'])
        identity = mount['actor']
        actor = facts.setdefault(identity, dict(sections=source['sections'],
            floor_origin=source['actor_frame_building']['position'],
            yaw=source['actor_frame_building']['yaw'], ties=[]))
        x, y, z = mount['column_local_blender']
        actor['ties'].append(dict(column=[x, z, -y], bracket_z=-mount['bracket_front_y'],
                                  rod=mount['rod'], hardware=mount['hardware']))
    assert len(facts) == 23 and all(len(actor['ties']) == 2 for actor in facts.values())
    return {"installations": [dict(id=identity, **actor) for identity, actor in sorted(facts.items())]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', required=True, type=Path)
    parser.add_argument('--out', type=Path, default=ROOT / 'game/data/orison_v2/radiator_wall_mounts.json')
    args = parser.parse_args()
    args.out.write_text(json.dumps(project(args.build_dir), indent=2) + '\n',
                        encoding='utf-8', newline='\n')
    print('Radiator mounts: 23 installations, 46 surveyed native ties')
