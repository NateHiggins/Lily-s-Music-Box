class_name ResidentWeather
extends RefCounted
## Local observations only: no future forecast, case flags, trust or plot knowledge.
const PATH := "res://data/weather/resident_weather.json"
static var _residents: Dictionary = {}

static func profile(resident: String) -> Dictionary:
	if _residents.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for record: Dictionary in parsed.get("residents",[]):
				_residents[str(record.get("resident_id",""))]=record
	return _residents.get(resident,{})

static func observation(resident: String, date: Dictionary, conditions: Dictionary,
		elapsed_minutes: float, sunlit := true) -> Dictionary:
	var record := profile(resident)
	var row := CampaignWeather.day(CampaignWeather.date_key(date))
	if record.is_empty() or row.is_empty() or conditions.is_empty(): return {}
	var kind := "fair"
	if float(conditions.get("snow_intensity",0))>.1: kind="snow"
	elif float(conditions.get("rain_intensity",0))>.05: kind="wet"
	elif bool(conditions.get("foggy",false)): kind="fog"
	elif float(conditions.get("temperature_c",12))>=29: kind="heat"
	elif float(conditions.get("temperature_c",12))<5: kind="cold"
	elif str(row.kind) in ["rain","storm","snow"]: kind="clearing"
	if kind in ["fair","clearing"] and not sunlit: kind="night"
	# Fields are literal to the reader gate; lookup selects one already-authored voice.
	var lines := {"cold":str(record.get("cold","")),"heat":str(record.get("heat","")),
		"wet":str(record.get("wet","")),"snow":str(record.get("snow","")),
		"clearing":str(record.get("clearing","")),"fair":str(record.get("fair","")),
		"fog":str(record.get("fog","")),"night":str(record.get("night",""))}
	var line: String = lines[kind]
	var trend:=elapsed_minutes>=3*1440 and persistent_trend(date,str(row.kind))
	if trend:
		line += " " + str(record.get("trend",""))
	return {"id":"wx:%s:%s:%s%s"%[resident,str(row.chapter).to_snake_case(),kind,":spell" if trend else ""],
		"topic":"The weather at your window.","line":line}

static func persistent_trend(date: Dictionary, kind: String) -> bool:
	if kind not in ["cold","heat","rain","snow","fog"]: return false
	var midnight := "%sT00:00:00"%CampaignWeather.date_key(date)
	var seconds := Time.get_unix_time_from_datetime_string(midnight)
	for offset in [1,2]:
		var prior := Time.get_datetime_string_from_unix_time(seconds-offset*86400).left(10)
		if str(CampaignWeather.day(prior).get("kind",""))!=kind: return false
	return true
