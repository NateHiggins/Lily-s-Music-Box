"""Project remaining V2 homes from their authored source, retaining other owners."""
import argparse
import json
from build_v2_vertical_services import project, ROOT
from build_v2_roof import render

SOURCE = ROOT / 'art/data/orison_v2/completion_interiors_source.json'
TARGET = ROOT / 'game/data/orison_v2_blockout.json'
CONSUMERS = ROOT / 'game/data/orison_v2/completion_interiors.json'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    source=json.loads(SOURCE.read_text(encoding='utf-8'))
    original=TARGET.read_text(encoding='utf-8')
    before=json.loads(original)
    after=project(before,source)
    consumers=json.dumps(source['consumers'],indent=2)+'\n'
    if args.check:
        if before!=after or not CONSUMERS.is_file() or CONSUMERS.read_text(encoding='utf-8')!=consumers:
            raise SystemExit('Completion interiors projection is stale')
        print('Completion interiors match authored source')
    else:
        TARGET.write_text(render(original,after),encoding='utf-8',newline='\n')
        CONSUMERS.write_text(consumers,encoding='utf-8',newline='\n')


if __name__=='__main__': main()
