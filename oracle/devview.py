"""The developer view: everything the house knew and why it did what it did.

One self-contained HTML file, written on request and never shown during play.
It contains the observations, every dimension with its confidence and evidence
both ways, how the profile moved turn by turn, which room was dealt after each
chamber and why, the design that came out, the reading, the exact prompt the
night handed over, any prompts sent to a narrating model, and the transcript.
"""

from __future__ import annotations

import html
import json
import time
from pathlib import Path

from .content import Registry
from .model import PlayerModel
from .session import Session, data_dir

FAMILY_TITLES = {
    "axis": "Core dimensions", "reward": "Reward motivations", "solve": "Problem-solving modes",
    "conflict": "Conflict preferences", "soc": "Social texture", "story": "Narrative interests",
    "arc": "Power arc", "tone": "Emotional tonality", "aesthetic": "Aesthetic signals",
}

CSS = """
:root{--bg:#f6f3ec;--fg:#1d1b18;--mut:#6b655c;--line:#d9d2c4;--card:#fffdf8;--pos:#2f6f5e;--neg:#9a4a2f;--acc:#8a6a1f}
@media (prefers-color-scheme:dark){:root{--bg:#171512;--fg:#ece6da;--mut:#a39b8d;--line:#3a352d;--card:#1f1c18;--pos:#6fc2a8;--neg:#e08a66;--acc:#d9b45a}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 Georgia,'Times New Roman',serif}
main{max-width:1080px;margin:0 auto;padding:24px 16px 80px}
h1{font-size:28px;margin:0 0 4px}h2{font-size:20px;margin:36px 0 10px;border-bottom:1px solid var(--line);padding-bottom:4px}
h3{font-size:16px;margin:22px 0 8px;color:var(--acc)}
p.sub{color:var(--mut);margin:0 0 16px}
table{border-collapse:collapse;width:100%;font:13px/1.4 ui-sans-serif,system-ui,sans-serif}
th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}
th{color:var(--mut);font-weight:600}
.scroll{overflow-x:auto}
.bar{position:relative;height:10px;width:160px;background:linear-gradient(to right,var(--line) 0,var(--line) 100%);border-radius:5px}
.bar i{position:absolute;top:0;bottom:0;border-radius:5px}
.bar b{position:absolute;left:50%;top:-3px;bottom:-3px;width:1px;background:var(--mut)}
.tag{display:inline-block;padding:1px 7px;border-radius:9px;font:11px ui-sans-serif,system-ui,sans-serif;border:1px solid var(--line);color:var(--mut)}
.tag.established{color:var(--pos);border-color:var(--pos)}.tag.leaning{color:var(--acc);border-color:var(--acc)}
.tag.contested{color:var(--neg);border-color:var(--neg)}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px 14px;margin:10px 0}
.mut{color:var(--mut)}.small{font-size:12px}
pre{white-space:pre-wrap;word-break:break-word;background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px;font:12px/1.45 ui-monospace,Consolas,monospace;max-height:520px;overflow:auto}
details{margin:8px 0}summary{cursor:pointer;color:var(--acc)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:10px}
.spark{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:8px 10px;font:12px ui-sans-serif,system-ui,sans-serif}
.player{color:var(--acc)}
ul{margin:6px 0;padding-left:20px}
"""


def e(value) -> str:
    return html.escape(str(value), quote=True)


def _bar(value: float, confidence: float) -> str:
    width = abs(value) * 50
    left = 50 if value >= 0 else 50 - width
    color = "var(--pos)" if value >= 0 else "var(--neg)"
    opacity = 0.25 + 0.75 * confidence
    return (f'<div class="bar" title="value {value:+.2f}, confidence {confidence:.2f}">'
            f'<i style="left:{left:.1f}%;width:{width:.1f}%;background:{color};opacity:{opacity:.2f}"></i><b></b></div>')


def _spark(points: list[tuple[int, float, float]], last_turn: int) -> str:
    """Value over turns as an inline SVG; the band is confidence."""
    w, h = 210, 46
    if not points:
        return ""
    span = max(last_turn, 1)
    xy = [(4 + (t / span) * (w - 8), h / 2 - v * (h / 2 - 4)) for t, v, _ in points]
    line = " ".join(f"{x:.1f},{y:.1f}" for x, y in xy)
    dots = "".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{1.2 + 2.2 * c:.1f}" fill="currentColor" opacity="0.7"/>'
                   for (x, y), (_, _, c) in zip(xy, points))
    return (f'<svg viewBox="0 0 {w} {h}" width="{w}" height="{h}" style="color:var(--acc)">'
            f'<line x1="0" y1="{h / 2}" x2="{w}" y2="{h / 2}" stroke="var(--line)"/>'
            f'<polyline points="{line}" fill="none" stroke="currentColor" stroke-width="1.5"/>{dots}</svg>')


def _list(items) -> str:
    items = [i for i in items if i]
    return "<ul>" + "".join(f"<li>{e(i)}</li>" for i in items) + "</ul>" if items else '<span class="mut">none</span>'


def _pre(title: str, text: str) -> str:
    return f"<details><summary>{e(title)}</summary><pre>{e(text)}</pre></details>"


def render(registry: Registry, session: Session) -> str:
    model = PlayerModel.from_list(registry, session.observations)
    states = model.compute()
    w = session.world
    syn = session.synthesis or {}
    out: list[str] = []
    add = out.append
    add(f"<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        f"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>The Blank Deck: developer view {e(session.id)}</title><style>{CSS}</style></head><body><main>")
    add(f"<h1>The Blank Deck: what the house knew</h1>")
    add(f"<p class='sub'>Session {e(session.id)} &middot; phase {e(session.phase)} &middot; {session.turn} turns "
        f"&middot; {len(w.summaries)} chambers &middot; narrator: {e(session.config.get('backend_used', 'offline'))} "
        f"&middot; {len(model.observations)} observations &middot; written {e(time.strftime('%Y-%m-%d %H:%M'))}. "
        f"A model of play preferences only.</p>")

    # ---- the night
    add("<h2>The night</h2><div class='scroll'><table><tr><th>#</th><th>Chamber</th><th>Way taken in</th>"
        "<th>Turns</th><th>What happened</th></tr>")
    for s in w.summaries:
        add(f"<tr><td>{s['n']}</td><td>{e(s['title'])}</td><td>{e(s.get('skin') or '')}</td>"
            f"<td>{s.get('turns', '')}</td><td>{e(s['line'])}</td></tr>")
    add("</table></div>")
    add(f"<p class='small mut'>Carried at the end: {e(w.carrying())}. Failures: {w.failures}. "
        f"Companion: {e((w.companion or {}).get('name', 'none'))}. Open threads: {len(w.threads)}.</p>")

    # ---- dimensions
    add("<h2>The player model</h2><p class='sub'>Value runs from the first pole (-1) to the second (+1); for a "
        "weight, right means drawn to it. Faded bars are low confidence. Confidence is capped until the "
        "evidence comes from three independent scenes.</p>")
    by_id = {o.id: o for o in model.observations}
    for family, title in FAMILY_TITLES.items():
        rows = [st for st in states.values() if registry.dims[st.id].family == family]
        rows.sort(key=lambda s: s.salience(registry.dims[s.id].importance), reverse=True)
        known = [st for st in rows if st.mass > 0]
        add(f"<h3>{e(title)} <span class='mut small'>({len(known)} of {len(rows)} with any evidence)</span></h3>")
        add("<div class='scroll'><table><tr><th>Dimension</th><th>Poles</th><th>Value</th><th>Conf.</th>"
            "<th>Status</th><th>Scenes</th><th>For</th><th>Against</th></tr>")
        for st in rows:
            d = registry.dims[st.id]
            if st.mass <= 0:
                continue
            support = "; ".join(by_id[i].action for i in st.supporting[-3:] if i in by_id)
            against = "; ".join(by_id[i].action for i in st.contradicting[-3:] if i in by_id)
            poles = f"{d.neg} / {d.pos}" if d.bipolar else d.desc
            add(f"<tr><td><b>{e(st.id)}</b></td><td class='small'>{e(poles)}</td>"
                f"<td>{_bar(st.value, st.confidence)}<span class='small mut'>{st.value:+.2f}</span></td>"
                f"<td>{st.confidence:.2f}</td><td><span class='tag {e(st.status)}'>{e(st.status)}</span></td>"
                f"<td>{st.n_independent}</td><td class='small'>{e(support)}</td><td class='small'>{e(against)}</td></tr>")
        add("</table></div>")
        unknown = [st.id for st in rows if st.mass <= 0]
        if unknown:
            add(f"<p class='small mut'>We do not know: {e(', '.join(unknown))}</p>")

    # ---- evolution
    add("<h2>How the profile moved</h2><p class='sub'>Each chart is one dimension over the turns of the night; "
        "larger dots are higher confidence.</p><div class='grid'>")
    top = [st for st in model.ranked() if st.mass > 0][:18]
    for st in top:
        points = [(snap["turn"], snap["dims"][st.id][0], snap["dims"][st.id][1])
                  for snap in session.snapshots if st.id in snap.get("dims", {})]
        add(f"<div class='spark'><b>{e(st.id)}</b> <span class='mut'>{e(model.label(st.id))}</span><br>"
            f"{_spark(points, session.turn)}</div>")
    add("</div>")

    # ---- probes
    add("<h2>What the house dealt, and why</h2>")
    for p in session.probes:
        if p.get("kind") == "seed":
            title = registry.seeds.get(p["chosen"], {}).get("title", p["chosen"])
            add(f"<div class='card'><b>Chamber {p['for_chamber']}: {e(title)}</b> "
                f"<span class='mut small'>chosen at turn {p.get('turn', '?')}</span><br>{e(p['why'])}")
            add("<div class='scroll'><table><tr><th>Candidate</th><th>Score</th><th>Information</th>"
                "<th>Disambiguation</th><th>Variety</th><th>Timing</th><th>Probes</th></tr>")
            for c in p.get("candidates", []):
                parts = c["parts"]
                probes_txt = ", ".join(f"{d} {v}" for d, v in c.get("probes", []))
                add(f"<tr><td>{e(c['seed'])} <span class='mut'>({e(c['kind'])})</span></td><td>{c['score']}</td>"
                    f"<td>{parts['information']}</td><td>{parts['disambiguation']}</td><td>{parts['variety']}</td>"
                    f"<td>{parts['timing']}</td><td class='small'>{e(probes_txt)}</td></tr>")
            add("</table></div>")
            least = ", ".join(f"{d} {v}" for d, v in p.get("least_known", []))
            add(f"<p class='small mut'>Least known at that moment: {e(least)}. "
                f"Open ambiguities: {e(p.get('open_ambiguities', []))}</p></div>")
        elif p.get("kind") == "thresholds":
            add(f"<p class='small'>After chamber {p.get('after_chamber', '?')} the ways offered were "
                f"<b>{e(', '.join(p['chosen']))}</b> ({e(p['why'])}).</p>")
    if session.skins_taken:
        add(f"<p class='small'>Ways taken, in order: <b>{e(', '.join(session.skins_taken))}</b></p>")

    # ---- observations
    add("<h2>Every observation</h2><div class='scroll'><table><tr><th>#</th><th>Turn</th><th>Scene</th>"
        "<th>Strength</th><th>Kind</th><th>Source</th><th>What the player did</th><th>Readings (share, then share after later evidence)</th></tr>")
    for o in model.observations:
        readings = "; ".join(
            f"{h.dim}{'+' if h.dir > 0 else '-'} {h.share:.2f}"
            + (f" &rarr; {h.posterior:.2f}" if h.posterior is not None and abs(h.posterior - h.share) > 0.005 else "")
            + (f" <span class='mut'>({e(h.why)})</span>" if h.why else "") for h in o.hypotheses)
        add(f"<tr><td>{o.id}</td><td>{o.turn}</td><td class='small'>{e(o.scene)}</td><td>{e(o.strength)}</td>"
            f"<td>{e(o.kind)}</td><td>{e(o.source)}{(' / ' + e(o.signal)) if o.signal else ''}</td>"
            f"<td>{e(o.action)}<br><span class='small mut'>{e(o.context)}</span></td><td class='small'>{readings}</td></tr>")
    add("</table></div>")
    ambiguities = model.ambiguities()
    still_open = [a for a in ambiguities if a["open"]]
    add(f"<p class='small mut'>{len(ambiguities)} observations were recorded with competing readings; "
        f"{len(still_open)} are still open (no reading has pulled ahead): "
        f"{e(', '.join('#' + str(a['observation']) for a in still_open) or 'none')}.</p>")

    # ---- synthesis
    if syn:
        d, pr = syn.get("design", {}), syn.get("prophecy", {})
        draft = syn.get("draft") or {}
        add("<h2>From profile to design</h2>")
        add(f"<p class='sub'>Design by: {e(syn.get('source', {}).get('design'))}. Reading by: "
            f"{e(syn.get('source', {}).get('prophecy'))}.</p>")
        if syn.get("problems"):
            add(f"<div class='card'><b>Model answers that were rejected</b>{_list(f'{k}: {v}' for k, v in syn['problems'].items())}</div>")
        add(f"<div class='card'><b>{e(d.get('working_title', ''))}</b><br>{e(d.get('pitch', ''))}</div>")
        if draft.get("signals"):
            add("<h3>Signals, ranked by salience (value x confidence x importance)</h3><div class='scroll'><table>"
                "<tr><th>Signal</th><th>Salience</th><th>Value</th><th>Confidence</th><th>Status</th><th>Folded in</th></tr>")
            for s in draft["signals"][:20]:
                add(f"<tr><td>{e(s['token'])}</td><td>{s['salience']}</td><td>{s['value']}</td>"
                    f"<td>{s['confidence']}</td><td>{e(s['status'])}</td><td class='small'>{e(', '.join(s['merged']))}</td></tr>")
            add("</table></div>")
        sig = d.get("design_signals", {})
        for name in ("dominant", "secondary"):
            add(f"<h3>{name.title()} signals</h3>")
            for item in sig.get(name, []):
                add(f"<div class='card'><b>{e(item.get('signal'))}</b> <span class='mut small'>{e(', '.join(item.get('dims', [])))}</span>"
                    f"<br><span class='small'>Evidence: {e('; '.join(map(str, item.get('evidence', []))))}</span>"
                    f"<br>{e(item.get('design_consequence'))}</div>")
        pc = sig.get("productive_contradiction") or {}
        add(f"<h3>Productive contradiction</h3><div class='card'><b>{e(' / '.join(pc.get('between', [])) or 'none observed')}</b>"
            f"<br>{e(pc.get('resolution', ''))}</div>")
        add("<h3>Design implications</h3>" + _list(d.get("design_implications", [])))
        add("<h3>Game Design Vector</h3><div class='scroll'><table><tr><th>Field</th><th>Value</th><th>Rule draft source</th></tr>")
        sources = draft.get("gdv_sources", {})
        labels = {f["id"]: f["label"] for f in registry.implications["gdv_fields"]}
        for key, value in (d.get("game_design_vector") or {}).items():
            add(f"<tr><td>{e(labels.get(key, key))}</td><td>{e(value)}</td><td class='small mut'>{e(sources.get(key, ''))}</td></tr>")
        add("</table></div>")
        add("<h3>Negative constraints</h3>" + _list(d.get("negative_constraints", [])))
        add("<h3>Personal callbacks</h3>" + _list(f"{c.get('from')} -> {c.get('becomes')}" for c in d.get("personal_callbacks", [])))
        un = d.get("unrequested_feature") or {}
        add(f"<h3>Unrequested feature</h3><p>{e(un.get('feature', ''))} <span class='mut'>(follows from: {e(un.get('follows_from', ''))})</span></p>")
        add("<h3>Unknowns</h3>" + _list(d.get("unknowns", [])))
        add("<h2>The reading</h2>")
        add(f"<div class='card'>{e(pr.get('address', ''))}{_list(pr.get('recollections', []))}</div>")
        for v in pr.get("visions", []):
            add(f"<div class='card'><b>{e(v.get('card'))}</b><br>{e(v.get('text'))}<br>"
                f"<span class='small mut'>Fulfilled by: {e(v.get('fulfils'))}. Echo: {e(v.get('echo'))}</span></div>")
        add(f"<p><b>{e(pr.get('pronouncement', ''))}</b> {e(pr.get('final_line', ''))}</p>")
        add("<h2>Exact prompts</h2>")
        for name, text in (syn.get("prompts") or {}).items():
            add(_pre(f"Prompt sent to the model: {name}", text))
        if not syn.get("prompts"):
            add("<p class='mut small'>No model was used for the design or the reading; they were made by the rules.</p>")

    # ---- the prompt
    add("<h2>The prompt</h2>")
    if session.prompt:
        where = f" Saved at {e(session.prompt_path)}." if session.prompt_path else ""
        add(f"<p class='small'>{len(session.prompt.split()):,} words.{where} This is the whole of what the "
            f"night hands to a builder.</p>")
        add(_pre("Exact prompt handed over", session.prompt))
    else:
        add("<p class='mut'>This night has not reached the reading, so no prompt has been written.</p>")

    # ---- guard, backend, transcript
    add("<h2>Guard and backend</h2>")
    add("<h3>Guard events</h3>" + _list(json.dumps(g) for g in session.guard_events))
    add("<div class='scroll'><table><tr><th>Turn</th><th>Purpose</th><th>Backend</th><th>Seconds</th><th>Prompt chars</th>"
        "<th>Reply chars</th><th>Error</th></tr>")
    for b in session.backend_log:
        add(f"<tr><td>{b.get('turn')}</td><td>{e(b.get('purpose'))}</td><td>{e(b.get('served_by') or b.get('backend'))}</td>"
            f"<td>{b.get('latency', '')}</td><td>{b.get('prompt_chars', '')}</td><td>{b.get('reply_chars', '')}</td>"
            f"<td class='small'>{e(b.get('error', ''))} {e(b.get('detail', ''))}</td></tr>")
    add("</table></div>")
    add("<h2>Transcript</h2><details><summary>Show the night</summary>")
    for t in session.transcript:
        cls = "player" if t["role"] == "player" else ""
        prefix = "&gt; " if t["role"] == "player" else ""
        add(f"<p class='{cls}'>{prefix}{e(t['text'])}</p>")
    add("</details></main></body></html>")
    return "\n".join(out)


def write_devview(registry: Registry, session: Session, out_path: str | None = None) -> Path:
    if out_path:
        path = Path(out_path)
    else:
        path = data_dir() / "devview" / f"{session.id}.html"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(render(registry, session).encode("utf-8"))
    return path
