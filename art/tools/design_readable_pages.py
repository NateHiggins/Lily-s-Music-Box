"""Author genre-specific layouts without altering library identity or edition."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'game/data/orison_v2/book_spreads.json'
content=json.loads(path.read_text(encoding='utf8'))
for identity,plate in {'wiring':'circuit_wiring','cordcircuits':'circuit_switchboard','radio':'circuit_radio','onefinger':'onefinger_drawing'}.items():
    content['spreads'][identity]['right']['illustration']=plate
content['spreads']['prospectus']['right']['body']='The proposed garden is shown fully furnished. The artist has included an extra chair beyond the balustrade. Subscribers are advised that the plate is an impression of the completed work, rather than a measured survey.'
path.write_text(json.dumps(content,indent=2)+'\n',encoding='utf8',newline='\n')
groups={
    'prospectus':['prospectus'],
    'register':['minutes','sorting','letters','missing','deadletter'],
    'verse':['hymns','barsongs'],
    'botanical':['glass','flowers','birds'],
    'literary':['dreams','walls'],
    'pamphlet':['onefinger'],
}
captions={
    'roof_plan':'The proposed garden, as imagined by its illustrator.',
    'circuit_wiring':'An ordinary bell, its button disconnected.',
    'circuit_switchboard':'Cord and plug apparatus at an idle position.',
    'circuit_radio':'A receiver after the household has retired.',
    'seedling':'Plants brought clear of the cold glass.',
    'bird_window':'A window left open; no cage required.',
    'pressed_flower':'A specimen kept between the leaves.',
    'elevation':'Construction opened to view, and to repair.',
    'lift_section':'The car, its counterweight and the empty landing.',
    'door':'A familiar door, imperfectly remembered.',
    'street_plan':'Streets recorded before the ground was ready.',
    'keyboard':'A place for the second player.',
    'onefinger_drawing':'There is room for somebody beside you.',
    'contact_frames':'The interrupted exposure was the one retained.',
    'knot':'A practical fastening for ordinary household use.',
    'pattern':'Cloth allowed for the life of its wearer.',
    'billiards':'A position left for the next player.',
    'dartboard':'The familiar figure, observed too quickly.',
    'timetable':'The connection worth keeping in mind.',
    'envelope':'The cover returned; its contents withheld.',
}
designs={}
for identity,spread in content['spreads'].items():
    style=next((style for style,ids in groups.items() if identity in ids),'manual')
    designs[identity]={'style':style,'annotation_heading':'A READER’S MARK' if style!='pamphlet' else 'ANOTHER HAND'}
    plate=spread['right'].get('illustration')
    if plate: designs[identity]['caption']=captions[plate]
out=ROOT/'art/illustrations/book_plates/page_designs.json'
out.write_text(json.dumps(designs,indent=2,ensure_ascii=False)+'\n',encoding='utf8',newline='\n')
