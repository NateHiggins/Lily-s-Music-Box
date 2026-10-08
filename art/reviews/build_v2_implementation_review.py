"""Build the illustrated owner-dossier implementation review from saved proof.

This report is INERT. It does not alter the owner's answering PDF or promote
world-completeness requirements. Image paths and hashes are emitted separately.
"""
from pathlib import Path
import hashlib
from io import BytesIO
import json
from xml.sax.saxutils import escape

from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "art/renders/orison_v2"
OUT = ROOT / "output/pdf/V2_dossier_implementation_review.pdf"
DATA = ROOT / "art/data/v2_owner_improvement_20261008.json"
PACKET = BASE / "building_finishes_20261008"
pdfmetrics.registerFont(TTFont("Segoe", "C:/Windows/Fonts/segoeui.ttf"))
pdfmetrics.registerFont(TTFont("SegoeBold", "C:/Windows/Fonts/segoeuib.ttf"))
W, H = 864, 648
INK = colors.HexColor("#182C32")
TEAL = colors.HexColor("#326F6F")
MUTED = colors.HexColor("#5A666C")
PAPER = colors.HexColor("#F6F4EF")
inventory = json.loads(DATA.read_text(encoding="utf-8"))
items = {row["id"]: row for row in inventory["items"]}
OUT.parent.mkdir(parents=True, exist_ok=True)
c = canvas.Canvas(str(OUT), pagesize=(W, H), pageCompression=1)
c.setTitle("The Orison V2 - Owner dossier implementation review")
c.setAuthor("Orison production review")
image_index = []
page_number = 0


def para(text, x, top, width, size=11, color=INK, leading=None):
    style = ParagraphStyle("body", fontName="Segoe", fontSize=size,
                           leading=leading or size*1.42, textColor=color)
    p = Paragraph(escape(text), style)
    _, height = p.wrap(width, 1000)
    assert top-height >= 37, (page_number, text[:80], height, top)
    p.drawOn(c, x, top-height)
    return top-height


def start(title, subtitle):
    global page_number
    page_number += 1
    c.setFillColor(PAPER); c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(TEAL); c.rect(32, H-31, 32, 4, fill=1, stroke=0)
    c.setFont("SegoeBold", 23); c.setFillColor(INK)
    c.drawString(32, H-67, title)
    para(subtitle, 32, H-83, W-64, 10, MUTED)
    c.setStrokeColor(colors.HexColor("#D4D8D4")); c.line(32, 31, W-32, 31)
    c.setFont("Segoe", 8); c.setFillColor(MUTED)
    c.drawString(32, 17, "THE ORISON / V2 OWNER DOSSIER / 08 OCT 2026 / INERT REVIEW")
    c.drawRightString(W-32, 17, f"{page_number:02d}")


def image(path, caption, x, top, width, height):
    path = Path(path)
    assert path.is_file(), path
    iw, ih = Image.open(path).size
    scale = min(width/iw, height/ih)
    c.setFillColor(colors.HexColor("#E3E5E2"))
    c.rect(x, top-height, width, height, fill=1, stroke=0)
    encoded = BytesIO()
    Image.open(path).convert("RGB").save(encoded, format="JPEG", quality=94, subsampling=0, optimize=True)
    encoded.seek(0)
    c.drawImage(ImageReader(encoded), x+(width-iw*scale)/2, top-height+(height-ih*scale)/2,
                width=iw*scale, height=ih*scale, preserveAspectRatio=True)
    para(caption, x, top-height-7, width, 9, MUTED)
    image_index.append({"page":page_number, "file":path.relative_to(ROOT).as_posix(),
                        "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
                        "caption":caption})


def plate(title, subtitle, pics, text, limit):
    start(title, subtitle)
    if len(pics) == 2:
        for n, (path, caption) in enumerate(pics):
            image(path, caption, 32+n*408, 526, 392, 276)
        y = 211
    else:
        assert len(pics) == 4
        for n, (path, caption) in enumerate(pics):
            image(path, caption, 32+(n%2)*408, 526-(n//2)*183, 392, 153)
        y = 149
    y = para(text, 32, y, 800, 11)
    para(limit, 32, y-13, 800, 9, MUTED)
    c.showPage()


def old(packet, path):
    return BASE / packet / path


def installed(path):
    return PACKET / "installed" / path


def native(path):
    return PACKET / "native" / path


start("The Orison V2", "Owner improvement dossier - illustrated implementation review")
reviewed = sum(r["status"] == "implemented_reviewed" for r in items.values())
c.setFont("SegoeBold", 48); c.setFillColor(TEAL)
c.drawString(32, 461, f"{reviewed} / 40")
para("Scoped items implemented and visually reviewed", 32, 437, 660, 17)
para("G15 remains conditional and uninstalled by default. The other items cover geometry, materials, practical-light review and fitted details requested in the answering dossier.", 32, 388, 760, 13)
para("This is a completion review of that bounded request, not a claim that the entire V1-to-V2 conversion or photoreal world pass is finished. The original answering dossier is preserved. Native component plates and production views are labeled separately.", 32, 307, 760, 12)
para("The final plates cover apartments, public interiors, appliances, lights, plant soil, entry frontage, roof, skyline and lift. Earlier verified batches are indexed and represented by their saved images. Full-resolution images, source hashes, runtime contracts and limitations accompany the committed evidence packets.", 32, 224, 760, 12)
para("Review feedback: identify the card ID and pictured view; describe the visible problem, desired change, objects to preserve, and priority. Separate a required correction from a new narrative or set-dressing proposal.", 32, 126, 760, 11)
c.showPage()

for group, ids in [("Geometry and functional stock", [f"G{i:02}" for i in range(1,16)]),
                   ("Household and shop finishes", [f"T{i:02}" for i in range(1,18)]),
                   ("Building finishes", [f"A{i:02}" for i in range(1,9)])]:
    start(group, "Complete card index. Reviewed means the scoped visual intervention, not unrestricted world acceptance.")
    y = 519
    for identity in ids:
        row = items[identity]
        c.setFont("SegoeBold", 10); c.setFillColor(TEAL); c.drawString(32,y,identity)
        c.setFont("Segoe", 10); c.setFillColor(INK); c.drawString(79,y,row["title"])
        state = "Reviewed" if row["status"] == "implemented_reviewed" else row["status"].replace("_"," ")
        c.drawRightString(832,y,state)
        y -= 24
    if ids[0].startswith("A"):
        y = para("Preserved authorities",32,y-17,790,14,TEAL)
        para("Room dimensions, practical-light controls, original doors, fan mechanics, roof drainage, lift drive and gate ownership remain source-owned. Finish shaders add no geometric displacement. Unchanged native geometry is reused with explicit evidence; captures alone are not runtime proof.",32,y-10,790,12)
    c.showPage()

plate("Service instruments and lamp supply", "G01-G07 and G14 / earlier verified implementation", [
 (old("service_instruments_20261008","runtime/F01_HOUSE_TELEPHONE_BOARD.jpg"),"Telephone board / installed native stock"),
 (old("service_instruments_20261008","runtime/ROOF_TANK_BALLCOCK.jpg"),"Tank service / original working controls"),
 (old("service_instruments_20261008","runtime/LobbyServiceDumbwaiter.jpg"),"Dumbwaiter / fitted moving construction"),
 (old("bar_and_supply_20261008","runtime_supply/F03_B_LAMP_01_outlet_detail.jpg"),"Task lamp / one of five authorized outlet routes")],
 "Fabricated instruments retain their original controls and state. Five task-lamp supplies terminate at documented, owner-authorized outlet placements.",
 "Full item results and proof: service_instruments_20261008 and bar_and_supply_20261008 evidence packets. These are selected views.")
plate("Bar equipment and signage", "G08-G13 / earlier verified implementation", [
 (old("bar_furniture_20261008","native/Piano_keys.png"),"Piano / native construction study"),
 (old("bar_furniture_20261008","installed/darts_score_oblique.png"),"Darts and score panel / installed view"),
 (old("bar_receiving_20261008","installed/receivers_whole.png"),"Receiving cabinets / original programme owners"),
 (old("signage_20261008","installed/bodega_lit.png"),"Bodega sign / retained live lettering and power")],
 "Native cases, playable control owners, fitted supports and Label3D lettering remain distinct. The final lighting check also seats the west bar sconce against the replacement score-panel face.",
 "G15 is deliberately excluded from default installation. The receiving-cabinet review does not authorize populating other empty positions.")
plate("Household cloth and service finishes", "T01-T06, T08, A03-A04 / earlier verified implementation", [
 (old("cloth_shops_20261008","native/wet-cloth-native/airer_full.png"),"Airer / native cloth, tubs and fitted support"),
 (old("cloth_shops_20261008","final/household_wardrobes/3B_aw_wardrobe_open.png"),"3B wardrobe / all four garments from standing gap"),
 (old("service_finishes_20261008","installed/service/washer_open.png"),"Washer / original tub and mechanisms"),
 (old("service_finishes_20261008","installed/bedding/2A_bed0_bedding_0.png"),"2A bedding / installed cloth finish")],
 "Cloth gains shaped hems, folds and seams; zinc, enamel, timber and iron receive bounded finish changes. Existing inventories, garment counts and working mechanisms remain.",
 "Wardrobe image frames contents at the original lens; the separate native plate records the complete open cabinet. No furniture was moved for the view.")
plate("Shop materials and fitted stock", "T10-T16 / earlier verified implementation", [
 (old("cloth_shops_20261008","native/shop-native/pawn_display_0.png"),"Pawn display / neutral native study"),
 (old("cloth_shops_20261008","shops/diner_apparatus/griddle_front.png"),"Diner / production cooking stock"),
 (old("cloth_shops_20261008","native/shop-native/druggist_carboys_0.png"),"Druggist carboys / rounded shoulders and stoppers"),
 (old("cloth_shops_20261008","shops/cobbler_fittings/bench.png"),"Cobbler / installed bench and materials")],
 "Shop timber, paper, cloth and metal are quieter and more distinct. Glass and emission remain with their optical owners; source-local wear follows handling and service areas.",
 "Shop interaction and ordinary passage reload are covered by the saved contract. Empty source displays remain empty; no broad stock expansion is implied.")
plate("T17 / Plants and soil", "Final detail and finish review", [
 (native("DomesticObject05.png"),"Household plant / final neutral native plate"),
 (installed("domestic_objects/3A_story_specimen_native.png"),"Same plant / installed 3A view")],
 "The household specimen retains its six source leaf stations. Curved blades, petioles, midribs and terminal bud improve form. Soil is recessed and dark brown; the pot retains quiet terracotta variation.",
 "Earlier funeral-foliage geometry and finish evidence is reused. No added plant inventory, growth system or wind simulation.")
plate("A01 / Apartment balance", "Fixed production stations / bright and dim rooms", [
 (installed("owner_building_finish/dim_2A_production.png"),"2A main room / existing nighttime practicals"),
 (installed("owner_building_finish/bright_3B_production.png"),"3B main room / existing nighttime practicals")],
 "Shared plaster and timber keep finer relief and lower pigment contrast. Cream surfaces, cloth and wood remain distinct within warm practical pools. Bright and dim households retain their existing lighting identities.",
 "Exposure and practical controls are retained. Paired room-off images accompany these views; the carried service lamp is present and explicitly labeled.")
plate("A02 / Public interiors", "Vestibule and lobby / current installed finish", [
 (installed("owner_building_finish/vestibule_production.png"),"Vestibule / floor, dado, door and casing"),
 (installed("owner_building_finish/lobby_production.png"),"Lobby / public floor and timber framing")],
 "Mapped aggregate, dark dado and painted trim keep separate material identities. The review reuses accepted joinery and thresholds while calming shared surface contrast.",
 "Entrance and inner-door collision, input and motion are exercised separately by the route contract. These stills do not independently prove traversability.")
plate("T07 / Refrigerators and ranges", "Retained native construction / current production finish", [
 (installed("household_fridges/F02_2A_FRIDGE_01_native_open.png"),"2A refrigerator / stocked interior and original leaf"),
 (installed("household_stoves/F02_2B_STOVE_01_native_open.png"),"2B gas range / original oven and cooking controls")],
 "Pale enamel, dark cooking iron, zinc and timber remain readable under practical lighting. Door, hatch, drip-pan and stove-control travel is checked after the original tweens settle.",
 "The current source contains 18 refrigerators, including seven monitor-top units. The dossier's older four-unit wording was not used to delete existing assignments. No cabinet geometry was rebuilt here.")
plate("T09 / Practical fixtures", "Same camera and fixture / original powered and off states", [
 (installed("fixed_lighting/3B_LT_SCONCE_powered.png"),"3B opal sconce / powered"),
 (installed("fixed_lighting/3B_LT_SCONCE_off.png"),"3B opal sconce / off"),
 (installed("fixed_lighting/F04_B_MAIN_LT_PENDANT_SHADE_powered.png"),"4B pendant / powered"),
 (installed("fixed_lighting/F04_B_MAIN_LT_PENDANT_SHADE_off.png"),"4B pendant / off")],
 "Fitted opal envelopes and holders remain finite shapes. The original mutable bulb, emitter, bounce, halo, swing and circuits are preserved across all 199 installations and 27 variants.",
 "The service lamp remains present in both states. Neutral component renders intentionally omit runtime bloom. West bar sconce attachment is checked against its actual native support.")
plate("A05 / Entry frontage", "Same approach / production day and night", [
 (installed("owner_building_finish/facade_day/front.png"),"Frontage / daytime production atmosphere"),
 (installed("owner_building_finish/front_facade/front.png"),"Frontage / nighttime production atmosphere")],
 "Stone receives restrained relief and ledge-related runoff. Timber and public iron use the calibrated finishes. Opening dimensions, canopy construction, door reveals and threshold remain intact.",
 "A neutral entrance component plate accompanies the full-resolution packet. The live route checks the closed barrier and a keyboard-operated entrance round trip.")
plate("A06 / Roof and ventilators", "Roof-scale production view / native fan detail", [
 (installed("owner_building_finish/roof_day.png"),"Roof / retained laps, structures and production daylight"),
 (native("roof_ventilator.png"),"Fan / neutral default-variant material and construction plate")],
 "Fine bitumen and quieter galvanizing preserve physical laps and authored bond colors. Bounded roof-coordinate variation follows seams. Fan stock keeps its original motor, shutter and service ownership.",
 "The isolated membrane is not a complete drainage model. Existing roof support, service-door motion and route evidence remain separate; no new LOD policy was introduced.")
plate("A07 / Neighboring skyline", "Native detail / verified roof and street observations", [
 (native("city_tanks.png"),"One original tank assembly / neutral base finish"),
 (PACKET/"capture_final/owner_building_finish/skyline_roof_day.png","Neighboring skyline / supported roof station, daylight"),
 (native("city_aerials.png"),"Original aerial dish / neutral native construction"),
 (PACKET/"capture_final/owner_building_finish/skyline_street_day.png","Street observation / tank partially masked by parapet")],
 "Stave timber, zinc bands and aerial metals are separated. Tank-band wear and small seeded tone differences follow the source component frame. Near and far views retain measured draw-submission observations.",
 "Original geometry and support tests remain. Two older whole-blockout hash pins are preserved with an explicit comparison proving the registration fields consumed by these assets are unchanged.")
plate("A08 / Lift cab", "Complete installed cab / native joinery detail", [
 (installed("owner_building_finish/lift_joinery/finished_cab_joinery.png"),"Assembled cab / mirror, rails, panels and original light"),
 (installed("owner_building_finish/lift_joinery/raised_panel_detail.png"),"Panel detail / quiet grain and bounded touch wear")],
 "Wood grain is reduced without flattening the raised-panel construction. Metal and varnished fields remain distinct. Native metre charts keep the joinery texture attached to the moving cab.",
 "The live passenger route visits B1 through F06, verifies platform carry and the empty-shaft barrier, and recalls the car. Gate articulation and existing collision are retained; save reconstruction is outside this review.")

start("Evidence and remaining scope", "Use the individual contracts and file hashes when making implementation claims.")
y=526
for title, text in [
 ("Evidence packet", "art/renders/orison_v2/building_finishes_20261008 contains native and installed plates, complete batch results, runner receipts and test-written schema-2 contracts. review_images.json binds delivered images to source files. The PDF image index records every embedded source hash."),
 ("Scope limits", "The dossier is a bounded geometry/material improvement request. It does not establish complete V2 world acceptance, save reconstruction for every item, historical certainty for all adaptations, or a fully photoreal environment. Known baseline resource-shutdown warnings are reported in the technical record."),
 ("Conditional item", "G15 remains uninstalled by default. No empty stock positions or new programme owners were added to turn this conditional item into a completed installation."),
 ("Broader V2 work", "The V1 fabrication census, unregistered builders and older source-binding drift remain separate work. Continue by room and shared dependency, using native fit/render checks followed by one composed Godot batch for changed areas."),
 ("Returning feedback", "Quote the card ID and view caption. State the observed defect, requested visual outcome, priority, and any functional or canon constraints. New room narratives or backstory expansions should be labeled proposals until accepted.")]:
    y=para(title,32,y,800,14,TEAL)-7
    y=para(text,32,y,800,11)-21
c.showPage();c.save()
PACKET.mkdir(parents=True,exist_ok=True)
(PACKET/"pdf_image_index.json").write_text(json.dumps({"evidence_class":"INERT","pdf":OUT.relative_to(ROOT).as_posix(),"pages":page_number,"images":image_index},indent=2)+"\n",encoding="utf-8",newline="\n")
print(f"Created {OUT}: {page_number} pages, {len(image_index)} source-bound images")
