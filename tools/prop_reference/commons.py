"""Wikimedia Commons search and download with per-file provenance.

Commons is used because every file carries machine-readable licensing in
``extmetadata``. Only permissive licences pass ``licence_allowed``; anything
non-commercial, no-derivatives, fair-use or unlabelled is refused, recorded
as refused, and never downloaded. Network access is injected so the tests
run against canned responses and never touch the wire.
"""

from __future__ import annotations

import hashlib
import json
import re
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Callable, Iterable

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = ("OrisonPropReference/0.1 "
              "(https://github.com/NateHiggins/Lily-s-Music-Box; "
              "natehiggins78@gmail.com)")
ALLOWED_MIME = {"image/jpeg", "image/png", "image/tiff", "image/webp"}

# LicenseShortName values seen on Commons, lowercased. Order matters only for
# readability; a value must match an ALLOW pattern and no DENY pattern.
_ALLOW = (
    re.compile(r"^public domain"),
    re.compile(r"^pd\b"),
    re.compile(r"^cc0\b"),
    re.compile(r"^cc[- ]by(-sa)?([-\s]*\d(\.\d)?)?([-\s]*[a-z]{2})?$"),
    re.compile(r"^no restrictions"),
    re.compile(r"^gfdl"),
)
_DENY = (
    re.compile(r"\bnc\b"),
    re.compile(r"\bnd\b"),
    re.compile(r"non-?commercial"),
    re.compile(r"no derivatives"),
    re.compile(r"fair use"),
    re.compile(r"copyrighted"),
    re.compile(r"non-?free"),
)


def licence_allowed(short_name: str) -> bool:
    """True only for licences that permit reuse with at most attribution."""
    text = (short_name or "").strip().lower()
    if not text:
        return False
    if any(p.search(text) for p in _DENY):
        return False
    return any(p.search(text) for p in _ALLOW)


@dataclass
class Hit:
    title: str
    page_id: int
    url: str
    thumb_url: str
    descriptionurl: str
    mime: str
    width: int
    height: int
    licence: str
    artist: str
    credit: str
    description: str
    query: str
    rank: int
    allowed: bool = False
    refused_reason: str = ""

    def to_record(self) -> dict:
        return asdict(self)


def _strip_html(text: str) -> str:
    return re.sub(r"<[^>]+>", "", text or "").strip()


def _meta(info: dict, key: str) -> str:
    ext = info.get("extmetadata") or {}
    value = ext.get(key) or {}
    return _strip_html(str(value.get("value", "")))


def default_fetch_json(url: str, sleep: float = 0.35) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.loads(response.read().decode("utf-8"))
    if sleep:
        time.sleep(sleep)
    return data


def default_fetch_bytes(url: str, sleep: float = 0.35) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    if sleep:
        time.sleep(sleep)
    return data


def search_url(query: str, limit: int, width: int) -> str:
    params = {
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"filetype:bitmap {query}", "gsrnamespace": "6",
        "gsrlimit": str(limit), "prop": "imageinfo",
        "iiprop": "url|extmetadata|size|mime", "iiurlwidth": str(width),
    }
    return API + "?" + urllib.parse.urlencode(params)


def parse_hits(payload: dict, query: str) -> list[Hit]:
    """Turn one API response into Hits, ranked by Commons' own search index."""
    pages = (payload.get("query") or {}).get("pages") or {}
    ordered = sorted(pages.values(), key=lambda p: int(p.get("index", 1 << 30)))
    hits: list[Hit] = []
    for rank, page in enumerate(ordered):
        infos = page.get("imageinfo") or []
        if not infos:
            continue
        info = infos[0]
        licence = _meta(info, "LicenseShortName")
        mime = str(info.get("mime", ""))
        hit = Hit(
            title=str(page.get("title", "")), page_id=int(page.get("pageid", 0)),
            url=str(info.get("url", "")), thumb_url=str(info.get("thumburl") or info.get("url", "")),
            descriptionurl=str(info.get("descriptionurl", "")), mime=mime,
            width=int(info.get("width", 0) or 0), height=int(info.get("height", 0) or 0),
            licence=licence, artist=_meta(info, "Artist"), credit=_meta(info, "Credit"),
            description=_meta(info, "ImageDescription")[:400], query=query, rank=rank,
        )
        if not licence_allowed(licence):
            hit.refused_reason = f"licence not permissive: {licence or '(none)'}"
        elif mime not in ALLOWED_MIME:
            hit.refused_reason = f"mime not a photograph or plate: {mime}"
        elif hit.width < 300 or hit.height < 300:
            hit.refused_reason = f"too small: {hit.width}x{hit.height}"
        else:
            hit.allowed = True
        hits.append(hit)
    return hits


def choose(hits: Iterable[Hit], per_query: int, seen_titles: set[str]) -> list[Hit]:
    """Keep the first ``per_query`` allowed hits whose title is new."""
    out: list[Hit] = []
    for hit in hits:
        if not hit.allowed or hit.title in seen_titles:
            continue
        seen_titles.add(hit.title)
        out.append(hit)
        if len(out) >= per_query:
            break
    return out


def safe_name(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", text).strip("_")[:120]


def fallback_queries(display_name: str, kind: str) -> list[str]:
    """Plain phrases for when the authored, specific queries find nothing.

    Commons full-text search rewards the obvious noun. An authored phrase
    such as "Hotpoint nickel plated electric kettle" can return zero files
    while "electric kettle 1920s" returns a page of them. The fallbacks are
    derived, not authored, and are recorded as fallbacks in provenance.
    """
    noun = re.sub(r"\(.*?\)", "", display_name or "").strip().lower()
    noun = re.sub(r"[^a-z0-9 ]+", " ", noun)
    noun = " ".join(noun.split()) or kind.replace("_", " ")
    return [f"{noun} 1920s", f"{noun} advertisement", f"{noun} photograph", noun]


@dataclass
class SpecimenReferences:
    specimen: str
    queries: list[str]
    downloaded: list[dict] = field(default_factory=list)
    refused: list[dict] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    fallbacks_used: list[str] = field(default_factory=list)


def fetch_specimen(specimen: str, queries: list[str], dest: Path, *,
                   per_query: int = 3, limit: int = 12, width: int = 800,
                   max_files: int = 8, min_files: int = 3,
                   fallbacks: list[str] | None = None,
                   fetch_json: Callable[[str], dict] = default_fetch_json,
                   fetch_bytes: Callable[[str], bytes] = default_fetch_bytes,
                   ) -> SpecimenReferences:
    """Download references for one specimen into ``dest`` and write provenance.

    Never overwrites a file it already wrote for the same Commons title, so a
    re-run only fills gaps. Refused hits are recorded with their reason so a
    reviewer can see what the search found and why it was not used. Stops
    after ``max_files`` files exist for the specimen; queries are ordered
    most-specific first, so the cap keeps the best-targeted results.
    """
    dest.mkdir(parents=True, exist_ok=True)
    result = SpecimenReferences(specimen=specimen, queries=list(queries))
    seen: set[str] = set()
    existing = _existing_provenance(dest)
    for title in existing:
        seen.add(title)
    # Authored queries first; the derived fallbacks only run if those left
    # the specimen sparse, and are marked so a reader can tell them apart.
    plan = [(query, False) for query in queries]
    plan += [(query, True) for query in (fallbacks or [])]
    for query, is_fallback in plan:
        have = len(existing) + len(result.downloaded)
        if have >= max_files:
            break
        if is_fallback and have >= min_files:
            break
        if is_fallback:
            result.fallbacks_used.append(query)
        try:
            payload = fetch_json(search_url(query, limit, width))
        except Exception as error:  # network is the one thing that may fail here
            result.errors.append(f"{query}: {error}")
            continue
        hits = parse_hits(payload, query)
        for hit in hits:
            if not hit.allowed:
                result.refused.append({"title": hit.title, "query": query,
                                       "reason": hit.refused_reason})
        for hit in choose(hits, per_query, seen):
            if len(existing) + len(result.downloaded) >= max_files:
                break
            record = hit.to_record()
            record["fallback_query"] = is_fallback
            file_name = f"{safe_name(hit.title.removeprefix('File:'))}"
            suffix = {"image/jpeg": ".jpg", "image/png": ".png",
                      "image/tiff": ".tif", "image/webp": ".webp"}.get(hit.mime, ".bin")
            if not file_name.lower().endswith(suffix):
                file_name += suffix
            path = dest / file_name
            try:
                data = fetch_bytes(hit.thumb_url or hit.url)
                path.write_bytes(data)
                record["file"] = path.name
                record["sha256"] = hashlib.sha256(data).hexdigest()
                record["bytes"] = len(data)
                result.downloaded.append(record)
            except Exception as error:
                result.errors.append(f"{hit.title}: {error}")
    # Merge with what an earlier run wrote so provenance never loses a file.
    merged = list(existing.values()) + result.downloaded
    (dest / "provenance.json").write_text(json.dumps({
        "schema": "orison.prop-reference.provenance.v1",
        "specimen": specimen,
        "queries": result.queries,
        "source": "Wikimedia Commons, thumbnails at requested width; "
                  "licences per file as reported by extmetadata",
        "downloaded": merged,
        "refused": result.refused,
        "errors": result.errors,
        "fallbacks_used": result.fallbacks_used,
    }, indent=1, ensure_ascii=False), encoding="utf-8")
    result.downloaded = merged
    return result


def _existing_provenance(dest: Path) -> dict[str, dict]:
    path = dest / "provenance.json"
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    out = {}
    for record in data.get("downloaded", []):
        if (dest / record.get("file", "")).exists():
            out[record["title"]] = record
    return out
