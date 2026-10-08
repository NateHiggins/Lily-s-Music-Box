from pathlib import Path
import json,hashlib,shutil,subprocess
from PIL import Image,ImageDraw
R=Path('C:/PleaseRemainOnTheLine'); O=R/'art/reviews/v2_remaining_20261008';O.mkdir(parents=True,exist_ok=True)
A='art/renders/orison_v2/'; C1='tmp/v2-finish-review/dossier-capture-01/';C2='tmp/v2-finish-review/dossier-capture-02/'
sets=[]
def add(id,title,category,what,condition,prompt,images,refs=''):
 sets.append(dict(id=id,title=title,category=category,what=what,condition=condition,prompt=prompt,images=[{'source':p,'caption':c} for p,c in images],references=refs))
def c1(name,cap):return (C1+name+'.png',cap+' | current model / neutral light')
def c2(name,cap):return (C2+name+'.png',cap+' | current model / neutral light')
def room(name,cap):return (C2+name+'.png',cap+' | current production light')
def native(path,cap):return (A+path,cap+' | native family review')
add('G01','Lobby call board and detector clock','Geometry + finish',
 'The porter call annunciator and the watchman detector clock; both are working lobby instruments with retained controls and text.',
 'The cases read as shallow rectangular boxes. Brown surfaces are largely uniform; sharp case edges and simple brass plates dominate. The clock face is legible, but depth, cabinet joinery and small hardware remain schematic.',
 'Case construction, timber character, dial depth and the amount of handling wear.',
 [c1('M01_2','LobbyPorterBoard'),c1('M03_2','F01_WATCHMAN_DETECTOR')])
add('G02','Night register, signal register and tour key','Geometry + finish',
 'Three related service stations: a shelf and key board, a signal recording cabinet, and the guarded tour key.',
 'Distinct functions are already readable. Shelf supports, blank brown panels, simple hooks and broad flat brass pieces still look assembled from basic shapes. Existing labels and paper content belong to the live interface.',
 'Shared cabinet style, joints, metal thickness, paper seating and restrained wear.',
 [c1('M04_2','F01_NIGHT_REGISTER'),c1('M05_2','F01_SIGNAL_REGISTER'),c1('M06_2','F01_TOUR_KEY_GUARD')])
add('G03','House telephone switchboard','Geometry + finish',
 'The lobby house-line board, with repeated sockets, indicators and trunk controls.',
 'The dark face and brass socket grid read clearly. The enclosing timber frame is severe and uniform; socket recesses, wiring, panel fasteners and layered construction need closer art direction.',
 'Socket detail, frame profiles, face material and visible cabling.',
 [c1('M08_0','Front three-quarter'),c1('M08_1','Opposite front')],'F01_HOUSE_TELEPHONE_BOARD')
add('G04','Service dumbwaiter','Geometry + finish',
 'The small lobby service lift with its original shaft opening, car, brake and overhead wheels.',
 'The frame, car and wheel silhouettes remain basic. The car looks like a plain solid box; the overhead parts have little surface detail. A neutral isolated view removes the surrounding wall, so it does not prove the installed shaft fit.',
 'Car construction, ropes and sheaves, hatch framing and worn working surfaces.',
 [c1('M09_2','Opening and car'),c1('M09_0','Back and overhead wheels')],'LobbyServiceDumbwaiter')
add('G05','Basement fuse panel','Geometry + finish',
 'The original electrical panel and its live service controls.',
 'The open cabinet is readable, but the outer material resembles coarse stone or concrete more than thin sheet metal. Interior parts are sparse blocks and bars. Door thickness, edges, fasteners and control detailing are still schematic.',
 'Painted-metal finish, cabinet section, period components and localized wear.',
 [c1('M07_2','Interior'),c1('M07_0','Exterior sheet and door')],'B1_FUSE_PANEL')
add('G06','House-tank level mechanism','Geometry + finish',
 'The roof tank ballcock assembly: a tall level/mechanical linkage with narrow brass and metal components.',
 'Thin rods and flat levers establish the mechanism, but much of the assembly looks smooth and minimally jointed. Several pieces are hard to distinguish at room distance. This is the mechanism alone, without the tank enclosure.',
 'Mechanical joints, bearing housings, metal variation and readable scale.',
 [c1('M02_0','Linkage and valve'),c1('M02_2','Reverse side')],'ROOF_TANK_BALLCOCK')
add('G07','Six alley and shed work lights','Geometry + finish',
 'Four alley and two shed cage-bulb fixtures still use the older visual form. The shed entry lamp is the representative shown.',
 'A bright bulb sits inside a simple cage beneath a long straight stem. The small cap and cage are legible but lack the fitted mount, socket layering and local finish refinement of the newer indoor family.',
 'Cage construction, weathering, stem or cable treatment and mounting detail.',
 [c1('M10_0','ShedEntryWorkLamp'),native('fixed_lighting_20261008/native/cage_bulb_rise250.png','Newer indoor cage family for comparison')])
add('G08','Harukiya loudspeakers','Geometry + finish',
 'The two stage loudspeakers; the first speaker is shown from front and back.',
 'The case is a plain box with prominent, uniform wood grain. The driver, central disc and small controls are readable but simplified. Cabinet seams, grille or cloth treatment, hardware and surface age need a coherent direction.',
 'Cabinet construction, driver and grille detail, wood scale and mounting.',
 [c1('M11_2','Speaker front'),c1('M11_0','Speaker case')],'F01_KARAOKE_SPK_0 / F01_KARAOKE_SPK_1')
add('G09','Harukiya piano and stage microphone','Geometry + finish',
 'The upright piano and slender microphone on the small stage. The red stage drapes already have a separate native fabrication pass.',
 'The piano is still a few large timber blocks with a pale keyboard strip. Individual keys, pedals, legs, panels and lid construction are not clearly modeled. The microphone is a thin angular stem with a minimal head and base.',
 'Piano proportions and construction, visible key and pedal detail, microphone form.',
 [room('C01_piano','Piano and microphone'),room('C02_stage','Stage context')],'retail_bar_piano_body / retail_bar_piano_lid / retail_bar_piano_keys')
add('G10','Songbook playback apparatus','Geometry + finish',
 'The bar songbook terminal, presented as mechanical playback apparatus on a small timber base.',
 'The horn, drum and drive components are strongly faceted; several parts appear to hover or lack an obvious physical connection. Broad smooth colors and the simple base make the assembly look schematic.',
 'Mechanical connections, horn profile, base construction and metal finishes.',
 [c1('M13_0','Drive and horn'),c1('M13_2','Reverse assembly')],'F01_BAR_SONGBOOK')
add('G11','Darts board, score panel and loose darts','Geometry + finish',
 'The wall-mounted dartboard and scoring panel, plus the small live darts holder on the adjacent ledge.',
 'The board reads as a coarse colored radial emblem rather than a detailed target. Cabinet doors are large plain slabs; the score panel has a strong mottled texture. Loose darts are straight stems with flat rectangular flights.',
 'Target sectors and wire divisions, cabinet joinery, score surface and dart construction.',
 [room('C03_darts','Complete wall installation'),c1('M12_0','Loose darts and holder')])
add('G12','Harukiya receiving cabinets','Geometry + finish',
 'The two complete bar receiving cabinets, including original live scopes, programme headers and controls.',
 'Tall flat cabinets with broad material bands still resemble the earlier chassis. Their circular live displays are distinct, but case section, lower panels, feet and service detailing are simple. Actor-only images omitted the static cases; this production view includes them.',
 'Period cabinet construction, face hierarchy, vents, feet, hardware and material treatment.',
 [room('C04_bar_receivers','Both complete bar cabinets')],'retail_bar_cab01 / retail_bar_cab02')
add('G13','Bar, bodega and Orison signage','Geometry + finish',
 'Existing sign housings and supports; the lettering is retained scene text, not a generated texture.',
 'Harukiya has flat dark panels and simple lanterns. The bodega fascia is intensely yellow with very thin returns. The Orison blade is a narrow dark box with exposed lettering and small brackets. Mounts, case depth and weathering need consistency.',
 'Sign case sections, brackets, lanterns, saturation and surface age; retain wording.',
 [c1('M14_2','Harukiya'),c1('M17_2','Bodega fascia'),c1('M26_0','Orison blade')])
add('G14','Task-lamp supply cords','Detail completion',
 'Five existing apartment task lamps already have native body geometry. This landlord lamp represents the external supply-cord work that remains.',
 'The shade, stem, base and switch are fitted and readable. The visible base entry ends without a routed supply flex in this isolated view. Surface response is slightly grainy and bright, so cord detail and finish should be reviewed together.',
 'Flex route, plug and entry detail; preferred enamel roughness and wear.',
 [c1('M24_0','Front of landlord lamp'),c1('M24_2','Cable-entry side')],'F04_B_LAMP_01; five task-lamp variants')
add('G15','Retained V1 lights not installed in V2','Uninstalled source forms',
 'The source chandelier, eye pendant and street-lamp form. These are current source prototypes instantiated for review, not evidence of V2 placement.',
 'The chandelier has visible polygonal bowls and simple gold-colored links. The eye pendant is a low-detail white oval on a short stem. The street form is a faceted dark hood with an orange lower bowl. Their installation and native replacement remain separate decisions.',
 'Which forms to carry forward, then proportions, mounting and material character.',
 [c2('U_chandelier_0','Chandelier source'),c2('U_eye_pendant_0','Eye-pendant source'),c2('U_street_lamp_0','Street-lamp source')])
add('T01','Boiler, radiators and heating metals','Finish + detail review',
 'The current boiler and an eight-section household radiator, including the repeated cast sections omitted by the first capture draft.',
 'The boiler has fitted doors, fittings and instruments but broad pale bands and dark slabs remain visually dominant. Radiator metal has a strong mottled surface and simple repeated lobes. Brass valves are very saturated relative to the iron.',
 'Paint, casting texture, soot placement, brass age and small edge detail.',
 [c1('M18_0','B1_BOILER_01'),c2('M19_0','F02_A_RADIATOR_01 with all cast sections')])
add('T02','Basement washer, tubs and airer','Finish + detail review',
 'The wringer washer and the shared wash tubs with overhead drying rack.',
 'The operating components and supports are present. Tub surfaces have a pronounced pale granular pattern; enamel, zinc and cast-metal parts are not always visually distinct. Cloth pieces on the rack remain simple flat shapes. The room itself is sparsely furnished.',
 'Metal/enamel separation, wash wear, wet-use details and cloth treatment.',
 [c1('M20_1','Wringer washer'),c1('M21_0','Tubs and airer')])
add('T03','Bathroom porcelain, chrome and cloth','Finish review',
 'Current pedestal lavatory, water closet and curtained shower; representative of repeated household bathroom fittings.',
 'The forms are coherent and curved, but broad white regions are nearly featureless in neutral light. Chrome is pale and low in contrast. The toilet seat grain is strong, while the curtain has repeated regular folds with little visible fabric variation.',
 'Glaze roughness, chrome contrast, seat grain and curtain fabric/wear.',
 [c1('M23_0','Pedestal lavatory'),c2('M33_0','Water closet'),c1('M22_2','Shower interior')])
add('T04','Wardrobes and kept clothing','Finish review',
 'The fitted household wardrobe family, with original moving leaves and household garment sets.',
 'Paneling and cornice profiles are present. The 3B case has bright and conspicuous oak grain; garment material and folds need to sit convincingly beside the timber. The native open view supplements the current closed studio view; the earlier 3B room view remains partly obstructed.',
 'Oak tone and scale, edge wear, garment weight and variation.',
 [c1('M28_0','Current 3B closed case'),native('household_wardrobes_20261007/native/Wardrobe00_open.png','3B native open contents')])
add('T05','Seating and household tables','Finish review',
 'The fitted chair, sofa and table families used throughout the apartments.',
 'The native forms now have joined frames and shaped stock. Wood and upholstery still need a consistent level of grain, roughness and wear across families; room lighting can push the timber strongly orange. Review these as surface references, not requests to replace accepted supports.',
 'Wood color/grain, upholstery weave and compression, restrained wear.',
 [native('apartment_furniture_20261007/domestic-seating-native/ChairOak_front.png','Oak dining chair'),native('apartment_furniture_20261007/domestic-seating-native/Sofa195_front.png','Sofa'),native('apartment_furniture_20261007/domestic-tables-native/TableRound03_front.png','Round table')])
add('T06','Household storage, books and small objects','Finish + detail review',
 'The current bookshelf, 3B parts crate and photography softbox; representatives of storage, loose stock and portable equipment.',
 'These have fitted native forms. The crate grain remains conspicuous and its contents read as a plain metal strip from this angle. Books have simple pastel covers, and the softbox is a dark rectangular face with a clean thin stand. Surface variety and object-specific wear remain open.',
 'Book and paper edges, crate age and contents, softbox cloth and stand detail.',
 [c1('M25_2','Bookshelf front'),c1('M30_0','3B parts crate'),c1('M32_0','Photography softbox')])
add('T07','Refrigerators and gas ranges','Finish review / latest completed batch',
 'The newly completed household refrigerator and stove geometry, with original moving controls and stocked interiors.',
 'Cabinets now have hollow interiors, supported shelves/racks and fitted moving parts. Neutral views read clearly. In production, amber lighting turns pale enamel yellow and obscures dark cooking parts; broader finish calibration remains distinct from the completed local geometry work.',
 'Enamel color, iron roughness, subtle wear and room-light balance.',
 [native('household_stoves_20261008/native/HouseholdGasRange_open.png','Current stove'),native('household_fridges_20261008/native/FridgeIcebox_open.png','Icebox shell and shelves')])
add('T08','Small appliances and medicine stock','Finish review',
 'Native toaster bodies, medicine cabinets and kept personal items; original controls and contents remain.',
 'Small-scale construction is present, but bright nickel, plain pale packaging and glass response still need a consistent finish language. Tiny repeated items can read as generic shapes unless roughness, thickness and local contrast are balanced.',
 'Nickel polish, bottle glass, packaging edges and restrained household wear.',
 [native('household_accessories_20261007/native/household_toasters/ToasterFront.png','Toaster'),native('household_accessories_20261007/native/medicine_cabinets/2A_cabinet_open.png','Stocked medicine cabinet')])
add('T09','Installed indoor lighting family','Finish review',
 'The completed native indoor fixture family: 199 room, passage and bar actors across 27 fitted variants.',
 'The new forms have fitted stock and supports. Opal glass, shade interiors and metal finishes still need to be judged against powered room appearance. Neutral review images intentionally omit the existing glow/halo, so they show the fixture rather than its light pool.',
 'Opal translucency, metal/enamel finish and powered color balance.',
 [native('fixed_lighting_20261008/native/flush_dome.png','Flush dome'),native('fixed_lighting_20261008/native/pendant_shade.png','Pendant shade'),native('fixed_lighting_20261008/native/sconce_globe_back050.png','Wall globe')])
add('T10','Pawnbroker cases and window stock','Finish review',
 'The fitted glazed display cases and passive watches, field glasses and telescope stock.',
 'Case framing, hollow display volume and supported stock are modeled. Glass, brass and timber still need a shared level of gloss and aging. Small unlettered merchandise is readable by silhouette; reflections can conceal it in the production window.',
 'Glazing clarity, metal patina, timber finish and merchandise contrast.',
 [native('pawn_display_20261007/images/native/storm_shop_pawnbroker_case_e_front.jpg','East display case'),native('pawn_display_20261007/images/native/watch_stock.jpg','Watch stock')])
add('T11','Hardware and locksmith stock','Finish review',
 'Key blanks, counter machinery, hand tools, glass racks, drawers and stock trays.',
 'Native pieces are separated and supported. The repeated stock is geometrically legible, but dark wood, brass and painted tools need consistent microtexture and edge wear. Keep the intentionally empty tool slot and original stock identities.',
 'Metal thickness and finish, tool-handle wear, cabinet timber and stock variation.',
 [native('locksmith_fittings_20261005/native/storm_shop_keys_cut_cutter_front.jpg','Key-cutting machine'),native('wood_grain_20261007/native/hardware_tools/tool_forms_detail.jpg','Hand-tool stock')])
add('T12','Cobbler machinery and shoe stock','Geometry + finish review',
 'The passive finisher, sewing apparatus, shoe stock and work furniture.',
 'Mechanical frames, wheels and stock are fitted. The finisher and patcher remain very dark and blocky in these native views. Wheel, belt, tool-bed and housing details need art direction alongside iron, wood, leather, dust and rubber finishes. Live machine operation is a separate task.',
 'Oiled metal, leather finish, dust placement and working-surface wear.',
 [native('cobbler_fittings_20261005/native/storm_shop_shoe_rebuilding_finisher_front.jpg','Finisher'),native('cobbler_fittings_20261005/native/storm_shop_shoe_rebuilding_patcher_treadle_front.jpg','Treadle patcher')])
add('T13','Druggist glass, bottles and stonework','Finish review',
 'The window carboys and marble fountain, representative of the dispensary, jars and counter apparatus.',
 'The fitted vessels and stone carcass are modeled. The carboys have visibly faceted shoulders and opaque-looking colored liquid; bright marble can flatten the fountain panels. Small metal spouts and supports need enough contrast to remain readable beside bright stone and saturated glass.',
 'Glass thickness and color, liquid appearance, marble scale and metal contrast.',
 [native('druggist_carboys_20261006/native/composed_rear.jpg','Window carboys'),native('druggist_fountain_20261006/native/cabinet_front.jpg','Marble fountain')])
add('T14','Diner counters and plated apparatus','Finish review',
 'The fitted counter, griddle, soda pumps, urns and other passive service apparatus.',
 'Hollow cases and slender supports have replaced the original blocks. Plated metal, stone and dark cooking iron remain visually uneven across the family; reflections can flatten the shapes. Controls and food-service wear need deliberate restraint.',
 'Nickel/chrome response, heat staining, countertop scale and edge wear.',
 [native('diner_apparatus_20261006/native/griddle_front.jpg','Griddle'),native('diner_apparatus_20261006/native/five_pumps.jpg','Five soda pumps')])
add('T15','Photo and radio shop equipment','Finish review',
 'Darkroom apparatus, photographic equipment, radio cabinets, batteries and wire stock.',
 'Current native forms include framed furniture, lenses, vessels and fine wire. Finish balance remains open between dark lacquer, timber, bright metal and glass. Some material detail is stronger than the size of the object warrants.',
 'Optical glass, lacquer, brass, copper and timber scale across related equipment.',
 [native('wood_grain_20261007/native/photo_cameras/storm_shop_photo_supplies_camera_body0_front.jpg','Bellows camera'),native('wood_grain_20261007/native/radio_wire/stock_front.jpg','Radio wire stock')])
add('T16','Laundry parcels and hanging cloth','Finish review',
 'The retail laundry parcel wall and the funeral-room hanging fabric; representatives of paper wraps, ties and large cloth surfaces.',
 'Parcels, supports, pleats, hems and suspension details are present. Repeated cloth folds and parcel shapes need believable material variation without losing the ordered layout. Textile roughness and localized dirt remain open.',
 'Fabric weight, weave scale, paper wrinkles, ties and subtle variation.',
 [native('laundry_trade_20261007/native/parcel_wall.jpg','Laundry parcel wall'),native('funeral_drapes_20261006/native/run0_header.jpg','Drape header and suspension')])
add('T17','Plants and funeral foliage','Finish + detail review',
 'The household specimen plant and larger funeral palm/wreath family.',
 'The small plant is very sparse, with a thin straight stem and a few regular leaves; pot and soil are simple. Larger fronds add silhouette detail but still need convincing leaf thickness, translucency, color variation and natural irregularity.',
 'Species character, leaf density and shape, leaf translucency, soil and pot wear.',
 [c1('M31_1','Household specimen'),native('funeral_foliage_20261006/native/palm2_front.jpg','Funeral palm')])
add('A01','Apartment light, plaster and floor grain','Building-wide finish',
 'Representative current apartment rooms, including Mina\'s living room and the 3B main room.',
 'The warm light strongly shifts white surfaces toward yellow and timber toward orange. Floor grain and plank contrast dominate the rooms; plaster has large visible noise. The same materials look substantially different across bright and dim rooms.',
 'Target warmth, contrast, floor grain scale, plaster relief and room-to-room balance.',
 [room('C_F02_A_MAIN','2A main room'),room('C_F03_B_MAIN','3B main room')])
add('A02','Public floors, paneling and door joinery','Building-wide finish',
 'The current vestibule and lobby: stone/terrazzo floor, timber dado, painted trim and doors.',
 'Large mottled floor patterns and strong dark paneling set the visual balance. Door/casing profiles are present, but edges, paint sheen and junctions need closer finish review. Bright seams and local changes in lighting make adjacent materials feel inconsistent.',
 'Floor aggregate scale, timber tone, painted trim and junction wear.',
 [room('C_F01_VESTIBULE','Vestibule'),room('C_F01_LOBBY','Lobby')])
add('A03','Bedrooms and bedding','Building-wide finish',
 'Current bedroom furniture and bedding in 2A, shown under the production lighting.',
 'Bed frame and pillows are recognizable. The cover is broad and smooth, and the pillows have simple rounded silhouettes with limited visible seams, compression or folds. Warm wall and floor colors reduce separation between materials.',
 'Bedding weight and folds, seams, mattress compression and bedroom light.',
 [room('C_F02_A_BED','2A bedroom')])
add('A04','Basement walls, floors and service context','Building-wide finish',
 'The complete current laundry and boiler-room settings surrounding the fitted service equipment.',
 'Large uninterrupted wall and floor areas are visually plain while a few practicals create bright pools. Equipment can look detached from the room. Surface scale, believable local use marks and coherent light levels need review.',
 'Concrete/plaster character, floor use patterns, service-room lighting and context detail.',
 [room('C_B1_LAUNDRY','Shared laundry'),room('C_B1_BOILER_ROOM','Boiler room')])
add('A05','Exterior stone trim and entry frontage','Building-wide finish',
 'The current facade trim and entry assembly. The isolated native view shows this component only; masonry and windows belong to other building owners.',
 'Bands and opening outlines are very regular. The entry has more depth than the upper trim, and the full facade needs a coherent stone, brick, painted-metal and glass response. The saved native material study is useful for shape; the labeled production reference shows the assembled frontage.',
 'Stone scale and joints, reveal depth, brick contrast, glass and entry wear.',
 [('tmp/v2-finish-review/dossier-native/front_facade_0.png','Current facade component | saved Blender materials'),native('front_facade_20261005/approach.png','Assembled facade reference / 2026-10-05')])
add('A06','Roof field, drainage and ventilator housings','Building-wide finish',
 'The current east roof membrane component and a production ventilator. Flashings, outlets, leaders and their junctions belong to the same wider roof review.',
 'The isolated membrane shows a broad repeated surface with faint seams. The ventilator has a simple cap and box housing with small fitted hardware. Roof-scale weathering, material contrast, seam readability and junction details remain open; the isolated membrane does not show the entire drainage system.',
 'Membrane scale, seam character, galvanized metal and localized weathering.',
 [('tmp/v2-finish-review/dossier-native/roof_membrane_0.png','East membrane component | saved Blender materials'),c1('M27_0','Current roof ventilator')])
add('A07','Neighboring rooftop tanks and aerials','Building-wide finish',
 'One current tank assembly and one dish assembly from the neighboring skyline families, shown as isolated native geometry.',
 'Tank bands, slender legs and diagonal braces are present, as are the dish support and feed. The saved Blender materials are pale and simple; these plates establish current shapes, not final runtime weathering. Stave definition, metal joins and variation across the skyline need final art direction.',
 'Timber stave character, galvanized-metal weathering, dish finish and readable supports.',
 [('tmp/v2-finish-review/dossier-native/city_tanks_0.png','Current tank geometry | saved Blender materials'),('tmp/v2-finish-review/dossier-native/city_aerials_1.png','Current dish geometry | saved Blender materials')])
add('A08','Lift cab paneling and public metalwork','Building-wide finish',
 'The current lift joinery component: lower panel fields and backing around the mirror opening. Other cab, gate, rail and indicator owners are deliberately absent from this isolated component view.',
 'Panel divisions and layered fields are fitted but very plain in the saved native material study. The remaining full-cab review is about timber scale, paint or varnish, metal contrast and wear at touch points; this view must not be read as a cab missing its other parts.',
 'Panel finish, molding edge character, hand-wear and consistency with public joinery.',
 [('tmp/v2-finish-review/dossier-native/lift_joinery_0.png','Current cab joinery component | saved Blender materials')])

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in sets:
 for i,im in enumerate(row['images']):
  source=R/im['source'];assert source.is_file(),source
  im['source_sha256']=sha(source)
  dest=O/'images'/f'{row["id"]}_{i+1}{source.suffix.lower()}';dest.parent.mkdir(exist_ok=True);shutil.copy2(source,dest)
  im['file']=dest.relative_to(O).as_posix()
manifest={'evidence_class':'INERT','title':'V2 geometry and texture review dossier','date':'2026-10-08','model_source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),'sets':sets,'scope':'Representative model sets and shared finish work remaining for owner art direction. Current runtime plates were captured 2026-10-08. Reused native views are labeled and retain their source paths/hashes. This is an art review, not whole-V2 acceptance or runtime-contract proof.'}
(O/'dossier.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
imgs=[(row['id'],im) for row in sets for im in row['images']]
for start in range(0,len(imgs),16):
 group=imgs[start:start+16];sheet=Image.new('RGB',(1800,390*((len(group)+3)//4)),'white');draw=ImageDraw.Draw(sheet)
 for i,(id,im) in enumerate(group):
  pic=Image.open(O/im['file']).convert('RGB');pic.thumbnail((448,352));x=i%4*450;y=i//4*390;sheet.paste(pic,(x,y+32));draw.text((x+4,y+3),id+' '+im['caption'].split('|')[0],fill='black')
 sheet.save(R/f'tmp/v2-finish-review/dossier-selected-{start//16}.jpg')
print(len(sets),'sets',len(imgs),'selected images')
