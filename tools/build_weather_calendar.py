"""Rebuild fictional campaign weather from the existing papers; never historical observations."""
import datetime as dt
import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "game/data/weather/campaign_weather.json"
START, END = dt.date(1928, 11, 10), dt.date(1929, 11, 9)
MEAN_HIGH = [39, 41, 49, 61, 71, 80, 85, 83, 76, 65, 54, 44]
# Authored chapter labels, not objectives or claims of historical weather.
CHAPTERS = [
    ("1928-11-10", "The first coal", "Cold windows, extra coal, and an exchange listening to a borough settling indoors."),
    ("1928-11-24", "The borough goes quiet", "Overnight snow softens the street; the papers count the calls that did not come."),
    ("1928-12-01", "An honest winter", "Ice cutters measure their livelihood in inches; neighbours compare cold rooms."),
    ("1928-12-21", "A Christmas forecast", "A mild interruption, rain, then snow; the forecast becomes part of the holiday argument."),
    ("1929-01-06", "An eleven-thousand-ton summer", "The January thaw costs the ice men work now and threatens the price of summer."),
    ("1929-01-18", "Winter resumes", "Clear cold after the thaw; every draught has acquired a name."),
    ("1929-02-01", "The short light", "Soot against winter light; damp wool and the work of keeping things warm."),
    ("1929-03-01", "Things thaw at different speeds", "Dripping cornices and wet cuffs; the company blames a thaw for sounds it cannot explain."),
    ("1929-04-01", "Rain keeps the appointment", "Umbrellas, coat hooks, drying paper and postponed washing."),
    ("1929-05-01", "The first open window", "Longer evenings put the neighbours within earshot; ice wagons prepare for heat."),
    ("1929-05-24", "The price of a cool room", "First heat; fans carry voices farther than anyone intends."),
    ("1929-06-18", "Sleeping outside", "Heat builds across days; the papers discuss ice deliveries and sleeping grounds."),
    ("1929-06-26", "After the first great storm", "Cool air, wet brick, and the audible absence of the heat."),
    ("1929-07-08", "A second summer", "Four hot days; a late thunderstorm makes the whole block stop speaking."),
    ("1929-07-20", "Borrowed cool", "Brief relief, slow heat, and the recurring argument over an open window."),
    ("1929-08-01", "Six days in the oven", "Six days of heat end under bruised clouds, sudden rain and a little invented hail."),
    ("1929-08-08", "Summer loosens its grip", "Airing rooms, drying garments, and little clear evenings worth remembering."),
    ("1929-09-01", "The evening wants a coat", "The first cold forecast brings coal orders before anyone agrees summer is over."),
    ("1929-10-01", "Windows shut one by one", "Warm afternoons, cold stairs, low amber haze and the return of the boiler."),
    ("1929-11-01", "The weather comes round", "Another coal season; a year of remarks can end with the same coat on the same hook."),
]
RARE = {"1929-02-12": 4, "1929-03-18": 1, "1929-05-14": 2,
        "1929-09-19": 3, "1929-10-13": 4}
DESCRIPTIONS = {
    "cold": "Fair and cold; frost in sheltered places. Keep the coal dry.",
    "fair": "Fair intervals; a little haze toward the river. Washing may go out.",
    "grey": "Cloudy; light variable wind. The low sky holds the chimney smoke.",
    "rain": "Rain at intervals; wet pavements and dripping coat hems.",
    "snow": "Snow in the borough; colder air and a quieter street.",
    "fog": "Fog or low mist; the river is heard before it is seen.",
    "heat": "Hot, close weather; shade, water and fresh ice are in demand.",
    "storm": "Thunder showers; squalls possible. Close exposed windows before the rain.",
}


def weather_kind(ear, high):
    text = ear.lower()
    text = re.sub(r"[^.;]*(?:tomorrow|by wednesday|possible friday|storms friday)[^.;]*[.;]?", "",text)
    text = re.sub(r"snow lying[^.;]*", "",text)
    if "after storms" in text:
        return "fair"
    if "storm" in text:
        return "storm"
    if "snow" in text:
        return "snow"
    if "rain" in text or "shower" in text:
        return "rain"
    if "fog" in text or "mist" in text:
        return "fog"
    if high >= 86:
        return "heat"
    if "cloud" in text or "grey" in text or "overcast" in text:
        return "grey"
    return "cold" if high < 42 else "fair"


def generate():
    issues = {}
    for path in sorted((ROOT / "game/data/newspapers").glob("19*.json")):
        for row in json.loads(path.read_text(encoding="utf-8"))["issues"]:
            issues[row["date"]] = row
    days = []
    date = START
    while date <= END:
        key = date.isoformat()
        ear = issues[key]["record"]["ear"]
        n = (date - START).days
        found = re.search(r"[Hh]igh\s+(\d+)", ear)
        high = int(found[1]) if found else MEAN_HIGH[date.month-1] + round(4*math.sin(n*.48))
        found = re.search(r"[Ll]ow(?: tonight)?\s+(\d+)", ear)
        low = int(found[1]) if found else high - (12 if "cloud" in ear.lower() else 16)
        kind = weather_kind(ear, high)
        chapter = max(c for c in CHAPTERS if c[0] <= key)
        # Six-hourly anchors plus late-afternoon and late-evening weather beats.
        frames = []
        anchors = [0, 360, 720, 900, 1080, 1260]
        if key == "1929-07-11": anchors += [1304,1305,1365,1390,1391]
        for minute in sorted(anchors):
            hour = minute/60
            heat = max(0, min(1, (hour-6)/9)) if hour <= 15 else (24-hour)/9
            temperature = low + (high-low)*heat
            active = kind
            t = ear.lower()
            if kind == "storm" and minute < (1260 if "tonight" in t else 1080):
                active = "heat"
            if kind in ["rain", "snow"]:
                if any(s in t for s in ["ending", "ended", "overnight", "early", "then clearing"]) and minute >= 720:
                    active = "fair"
                if any(s in t for s in ["by night", "tonight", "by evening"]) and minute < 1080:
                    active = "grey"
                if "by afternoon" in t and minute < 720: active = "grey"
            if kind == "fog":
                if "tonight" in t: active="fog" if minute>=1080 else "fair"
                elif "then" in t: active="fog" if minute<720 else "fair"
                elif minute in [720,900]: active="grey"
            cloud = {"cold":.18,"fair":.28,"grey":.82,"rain":.94,"snow":.96,"fog":.76,"heat":.32,"storm":1.0}[active]
            wind = {"cold":14,"fair":11,"grey":10,"rain":23,"snow":19,"fog":3,"heat":7,"storm":44}[active]
            if active in ["cold","fair","heat"]:
                cloud = round(max(.05,min(.6,cloud+.14*math.sin(n*.73+hour*.18))),3)
                wind = round(max(3,wind+5*math.sin(n*.29+hour*.21)),2)
            rain = 4.0 if active == "storm" else (1.0 if active == "rain" else 0.0)
            snow = 1.1 if active == "snow" else 0.0
            # Preserve the paper's explicitly timed local thunderstorms.
            if key == "1929-07-11" and 1260 <= minute < 1305:
                rain = 0.0; cloud = .95; wind = 21
                active = "grey";temperature=92
            if key == "1929-07-11" and minute >= 1305:
                temperature = 92 if minute==1305 else 70
                if minute >= 1391: active="fair"; rain=0; cloud=.4; wind=16
            if key == "1928-12-22":
                active="rain" if minute<1260 else "snow"
                rain=1.0 if minute<1260 else 0.0
                snow=0.0 if minute<1260 else 1.1
            if key == "1929-08-06" and minute >= 900:
                active = "storm"; rain = 4.5; cloud = 1.0; wind = 48
                temperature = 72 if minute >= 1080 else 96
                if minute >= 1260: active="fair";rain=0.0;cloud=.4;wind=16
            if key == "1928-11-24" and minute >= 1260:
                active = "snow"; snow = 1.4; rain = 0; cloud = 1; temperature = 28
            code = {"cold":0,"fair":2,"grey":3,"rain":61,"snow":73,"fog":45,"heat":2,"storm":95}[active]
            hail = key == "1929-08-06" and minute == 900
            if hail: code = 96
            if "gale" in t and minute < 720: wind = 48
            frames.append({"minute":minute,"weather_code":code,"temperature_c":round((temperature-32)*5/9,2),
                "relative_humidity":90 if active in ["rain","snow","fog","storm"] else (74 if active=="heat" else 60),
                "cloud_total":cloud,"cloud_low":round(cloud*.82,3),"cloud_mid":round(cloud*.55,3),"cloud_high":.24,
                "wind_speed_kmh":wind,"wind_gusts_kmh":wind*1.6,"wind_direction_degrees":45 if active in ["rain","snow"] else (240 if active=="storm" else 285),
                "pressure_hpa":996 if active=="storm" else (1006 if active in ["rain","snow"] else 1023),
                "rain_mm":rain,"snowfall_cm":snow,"hail":1.0 if hail else 0.0,
                "cyclone":.45 if active=="rain" and date.month in [11,12,1,2,3,4] else 0.0,
                "severe_storm_threat":.85 if active=="storm" else 0.0,
                "formation":RARE.get(key,0) if active in ["fair","cold","grey"] and minute in [900,1080] else 0})
        forecasts = []
        for issued in [360, 1020]:
            missed = key in ["1929-04-16", "1929-07-19", "1928-12-22"] and issued == 360
            prediction = "Cloudy; clearing expected toward evening." if missed else DESCRIPTIONS[kind]
            outlook = "Little change is indicated; the next report may alter this outlook."
            valid_date = date if issued == 360 else date+dt.timedelta(days=1)
            if issued == 1020 and valid_date.isoformat() in issues:
                tomorrow = issues[valid_date.isoformat()]["record"]["ear"]
                tomorrow_high = re.search(r"[Hh]igh\s+(\d+)",tomorrow)
                tomorrow_kind = weather_kind(tomorrow,int(tomorrow_high[1]) if tomorrow_high else high)
                prediction = "Tomorrow: " + DESCRIPTIONS[tomorrow_kind]
            expected_high = high
            if issued == 1020 and valid_date.isoformat() in issues and tomorrow_high:
                expected_high = int(tomorrow_high[1])
            prediction += f" Expected high about {expected_high} degrees."
            forecasts.append({"issued_minute":issued,
                "issued_at":f"{key}T{issued//60:02d}:00",
                "valid_from":f"{valid_date.isoformat()}T06:00",
                "valid_until":f"{valid_date.isoformat()}T18:00",
                "prediction":prediction,"outlook":outlook,
                "confidence":"uncertain" if missed or kind in ["rain","storm","snow"] else "fair",
                "revision":"The expected clearing has been delayed; wet weather continues." if issued==1020 and key in ["1929-04-16","1928-12-22"] else ""})
        days.append({"date":key,"chapter":chapter[1],"story_hook":chapter[2],"kind":kind,
            "record_ear":ear,"speaker_ear":issues[key]["speaker"]["ear"],
            "frames":frames,"bulletins":forecasts})
        date += dt.timedelta(days=1)
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps({"schema_version":1,"first_date":START.isoformat(),"last_date":END.isoformat(),
        "authorship":"Fictional alternate-history weather, aligned with the existing campaign papers; not a reconstruction of observed 1928-29 weather.",
        "days":days},indent=1)+"\n",encoding="utf-8",newline="\n")
    print(f"Authored {len(days)} days, {sum(len(d['frames']) for d in days)} anchors and {sum(len(d['bulletins']) for d in days)} bulletins: {OUT}")


if __name__ == "__main__":
    generate()
