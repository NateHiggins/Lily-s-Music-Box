"""Publish the authored book programme without changing stock identities.

Run before the native library batch. This changes catalogue text/trim heights
and featured excerpts, not household, inventory or case owner implementations.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]

def main():
    source=json.loads((ROOT/'art/data/readable_library/editorial.json').read_text(encoding='utf-8'))
    path=ROOT/'game/data/library.json';library=json.loads(path.read_text(encoding='utf-8'))
    spreads_path=ROOT/'game/data/orison_v2/book_spreads.json';spreads=json.loads(spreads_path.read_text(encoding='utf-8'))
    assert set(source['books'])=={row['id'] for row in library['books']}==set(spreads['spreads'])
    hues={'book_burgundy':350,'book_brown':25,'book_ochre':50,'book_green':110,'book_teal':180,'book_navy':225,'paper':45}
    revised=[]
    for existing in library['books']:
        identity=existing['id'];edition=source['books'][identity];record=dict(edition['catalogue']);format=source['formats'][edition['format']]
        assert record['id']==identity and set(record)==set(existing)
        assert edition['publisher'] in source['publishers'] and edition['layout'] in source['layouts']
        assert edition['page_count']>=8 and edition['page_count']%4==0
        if edition['case_text_preserved']:
            assert edition['featured_spread']==spreads['spreads'][identity], 'Do not overwrite a known clue: '+identity
        record['height']=round(format['height_m']*1000);record['hue']=hues[edition['material']]
        revised.append(record);spreads['spreads'][identity]=edition['featured_spread']
    library['books']=revised
    path.write_text(json.dumps(library,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
    spreads_path.write_text(json.dumps(spreads,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
    print('Published',len(revised),'existing book identities in',len(source['formats']),'declared trim categories')

if __name__=='__main__':main()
