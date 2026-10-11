extends RefCounted
const Treatment := preload("res://scripts/building/orison_v2_window_treatment.gd")
static func mount(world: Node3D) -> bool:
    var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/apartment_life_profiles.json"))
    var profiles := {}
    for profile: Dictionary in document.profiles:profiles[str(profile.unit)]=profile
    var root: Node3D=world.adapter.root
    for record: Dictionary in world.layout.windows:
        if str(record.id)=="B1_BOILER_AIR_E":continue
        var opening := root.get_node_or_null(str(record.id)) as Node3D
        var room: Dictionary={}
        for candidate: Dictionary in world.layout.spaces:
            if candidate.id==record.space:room=candidate;break
        if opening==null or room.is_empty():return false
        var tokens: PackedStringArray=str(record.space).split("_")
        var unit := str(int(str(record.level).trim_prefix("F")))+tokens[1] if tokens.size()>2 and tokens[1] in ["A","B","C","D"] else ""
        var actor := Treatment.new();actor.name="WindowTreatment"
        actor.width=float(record.width);actor.height=float(record.height)
        var profile: Dictionary=profiles.get(unit,{})
        if not profile.is_empty():
            var authored: Dictionary=profile.window_treatment
            actor.style=str(authored.style);actor.fabric=str(authored.material)
            actor.tint=Color(authored.tint[0],authored.tint[1],authored.tint[2])
            actor.raised=float(authored.raise);actor.tilt_degrees=float(authored.tilt_degrees)
            actor.curtain_open=float(authored.curtain_open);actor.character_note=str(authored.character_note)
            var info: Dictionary=world.campaign_clock.day_info()
            var sleeping := false
            for resident: String in profile.resident_ids:
                var block: Dictionary=world.resident_presence.resolve(resident,str(info.day),world.campaign_clock.minute_of_day(),int(info.doy),bool(info.first_sat))
                if str(block.get("activity",""))=="sleeping":sleeping=true
            if sleeping and ("BED" in str(record.space) or "ALCOVE" in str(record.space) or str(profile.sleep_schedule)=="days"):
                actor.raised=0;actor.tilt_degrees=75;actor.curtain_open=0
            if actor.style=="split":
                actor.style="linen"
                if str(record.space).ends_with("BED2"):actor.raised=.2;actor.tilt_degrees=60;actor.curtain_open=.35
        else:
            actor.tint=Color(.82,.77,.66);actor.character_note="Quiet civic linen and matched blinds in the shared rooms."
        if "KITCHEN" in str(record.space):actor.style="bare";actor.raised=.65;actor.tilt_degrees=20
        if "BATH" in str(record.space):actor.style="cafe";actor.fabric="linen";actor.raised=0;actor.tilt_degrees=75;actor.curtain_open=0
        var span: Vector2=root.window_reveal_span(record)
        var along_x: bool=str(record.axis)=="x"
        var fixed_axis := 2 if along_x else 0
        var rect: Array=room.rect
        var room_middle: float=(float(rect[1 if along_x else 0])+float(rect[3 if along_x else 2]))*.5
        var inward := 1.0 if room_middle>(span.x+span.y)*.5 else -1.0
        var at := Vector3(float(record.center[0]),float(root.level_y[record.level])+float(record.sill)+float(record.height)-.155,float(record.center[1]))
        at[fixed_axis]=(span.y if inward>0 else span.x)+inward*.045
        var yaw := (0.0 if inward>0 else PI) if along_x else (PI*.5 if inward>0 else -PI*.5)
        actor.transform=opening.transform.affine_inverse()*Transform3D(Basis(Vector3.UP,yaw),at)
        actor.set_meta("unit",unit);actor.set_meta("semantic_window",str(record.id))
        opening.add_child(actor);actor.add_to_group("v2_window_treatments")
    return true
