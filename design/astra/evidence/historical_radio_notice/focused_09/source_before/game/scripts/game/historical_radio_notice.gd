class_name HistoricalRadioNotice
extends RefCounted
## A printed license notice, interpreted against an injected campaign date.
## No clock advances, broadcasts, delivery events, or knowledge writes.

const DATA_PATH := "res://data/historical_radio_reallocation.json"
var event: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		event = parsed


func printed_text() -> String:
	var lines := PackedStringArray([
			str(event.get("notice_heading", "WIRELESS NOTICE")),
			"Hand copy for the tenants", "",
			str(event.get("notice_date_line", "")), "LICENSES CHANGE", "",
			"        BEFORE   FROM 3 A.M."])
	for row in event.get("assignments", []):
		lines.append("%-5s    %d       %d" % [str(row.station), int(row.before_kc), int(row.after_kc)])
	lines.append("             KILOCYCLES")
	lines.append("")
	lines.append(_shared_line() + ", divided time")
	lines.append("under the new list.")
	lines.append("Consult the programme listings.")
	return "\n".join(lines)


func copy_at(civil: Dictionary) -> Dictionary:
	var phase := _phase_at(civil)
	var rows := PackedStringArray()
	for row in event.get("assignments", []):
		var key := "before_kc" if phase == "BEFORE" else "after_kc"
		rows.append("%s %d>%d" % [str(row.station), int(row.before_kc), int(row.after_kc)]
				if phase == "UNRESOLVED" and row.before_kc != row.after_kc
				else "%s %d" % [str(row.station), int(row[key])])
	# Three short lines fit the existing 74px service-wire body. The fixed
	# paper retains the full notice; the field copy keeps its effective date.
	var body := "BEFORE: " if phase == "BEFORE" else "FROM 03:00: " if phase == "AFTER" else ""
	body += " / ".join(rows) + " KC."
	body += "\nNEW LIST: " + _shared_line() + ", DIVIDED TIME."
	body += "\nPROGRAMME HOURS NOT GIVEN."
	var condition := "READ DATE UNAVAILABLE / CHANGE 1928-11-11 03:00 EST"
	if phase != "UNRESOLVED":
		var minute := int(civil.minute_of_day)
		condition = "READ %04d-%02d-%02d %02d:%02d / CHANGE 1928-11-11 03:00 EST" % [
				int(civil.year), int(civil.month), int(civil.day_of_month),
				minute / 60, minute % 60]
	return {"card_id": str(event.get("id", "")), "title": "NEW YORK WIRELESS NOTICE",
			"body": body, "condition": condition, "stamp": "HAND-COPIED NOTICE",
			"notice_phase": phase, "evidence_medium": "printed_license_notice"}


func _shared_line() -> String:
	var shared: Dictionary = event.get("shared_after", {})
	return "%s: %d" % [" / ".join(shared.get("stations", [])), int(shared.get("kc", 0))]


func _phase_at(civil: Dictionary) -> String:
	var minute: Variant = civil.get("minute_of_day", -1)
	if (minute is not int and minute is not float) or not is_finite(float(minute)):
		return "UNRESOLVED"
	if not bool(civil.get("valid", false)) or int(civil.get("year", 0)) <= 0 \
			or int(civil.get("month", 0)) not in range(1, 13) \
			or int(civil.get("day_of_month", 0)) not in range(1, 32) \
			or float(civil.get("minute_of_day", -1)) < 0.0 \
			or float(civil.get("minute_of_day", -1)) >= 1440.0:
		return "UNRESOLVED"
	var effective: Dictionary = event.get("effective", {})
	if effective.is_empty():
		return "UNRESOLVED"
	var today := int(civil.year) * 10000 + int(civil.month) * 100 + int(civil.day_of_month)
	var boundary := int(effective.year) * 10000 + int(effective.month) * 100 + int(effective.day_of_month)
	return "AFTER" if today > boundary or (today == boundary \
			and float(civil.minute_of_day) >= float(effective.minute_of_day)) else "BEFORE"
