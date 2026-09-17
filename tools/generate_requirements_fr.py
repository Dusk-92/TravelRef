#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate official French TravelRef requirement labels.

Deed/quest titles are joined EN->FR by identical LOTRO localization IDs.
Reputation fallbacks are composed only from the official localized standing
name and official localized faction name from lore/factions.xml.
"""
from __future__ import annotations

import difflib
import html
import re
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Dusk" / "TravelRef" / "TR_Data.lua"
OUT = ROOT / "Dusk" / "TravelRef" / "TR_OfficialFR_Requirements.lua"
REPORT = ROOT / "tools" / "TR_RequirementsFR_Audit.txt"
LABEL_BASE = "https://raw.githubusercontent.com/LotroCompanion/lotro-data/master/lore/labels"
FACTIONS_URL = "https://raw.githubusercontent.com/LotroCompanion/lotro-data/master/lore/factions.xml"
TITLE_SOURCES = ["deeds.xml", "quests.xml"]
GRAMMAR = re.compile(r"\[(?:m|f|n|mp|fp|np)\]", re.I)
PLAYER_MACRO = re.compile(r"\$\{PLAYERNAME:([^|{}]+)\|([^{}]+)\}")

# Historical TravelRef faction spellings/abbreviations -> current official EN.
FACTION_ALIASES = {
    "Lossoth": "Lossoth of Forochel",
    "Algraig": "Algraig, Men of Enedwaith",
    "Entwash Vale": "Men of the Entwash Vale",
    "Grey Mountains Exp.": "Grey Mountains Expedition",
    "Habanakka of Thrain": "Haban'akkâ of Thraïn",
    "Reclaimers of the Mtn-Hold": "Reclaimers of the Mountain-hold",
    "Minas Tirith": "Defenders of Minas Tirith",
}

# TravelRef predates a terminology change for the Host of the West standing.
# The current client calls the same standing "Honoured".
RANK_ALIASES = {
    "esteemed": "Honoured",
}

# Historical epic quest titles no longer present verbatim in the current data
# files. These are verified French LOTRO/Tolkien titles retained explicitly so
# TravelRef never falls back to an English prerequisite label.
LEGACY_QUEST_FR = {
    "Q1": "Le défi de la pierre",
    "Q4": "Au cœur du danger",
    "Q5": "La vingt et unième salle",
    "Q7": "Les Aigles arrivent !",
    "Q8": "La même que vous",
    "Q10": "La paix rétablie",
}


def clean(value: str) -> str:
    return GRAMMAR.sub("", html.unescape(value).replace("\u00a0", " ")).strip()


def readable(value: str) -> str:
    value = clean(value)
    def repl(match: re.Match[str]) -> str:
        a = clean(match.group(1))
        b = clean(match.group(2))
        return a if a == b else f"{a} / {b}"
    return PLAYER_MACRO.sub(repl, value)


def norm(value: str) -> str:
    value = clean(value).replace("œ", "oe").replace("Œ", "OE").replace("æ", "ae").replace("Æ", "AE")
    value = unicodedata.normalize("NFKD", value).lower()
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    return "".join(ch for ch in value if ch.isalnum())


def fetch_xml(url: str, timeout: int = 120) -> ET.Element:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return ET.fromstring(response.read())


def fetch_labels(lang: str, filename: str) -> dict[str, str]:
    root = fetch_xml(f"{LABEL_BASE}/{lang}/{filename}")
    return {
        node.attrib["key"]: clean(node.attrib.get("value", ""))
        for node in root.findall("label")
        if node.attrib.get("key") and node.attrib.get("value")
    }


def extract_reqs(text: str) -> dict[str, str]:
    start = text.index("Reqs = {")
    end = text.index("\n\t}", start)
    block = text[start:end]
    return {
        m.group(1): m.group(2)
        for m in re.finditer(r'^\s*([DQR]\d+)\s*=\s*"([^"]+)"', block, re.M)
    }


def title_candidates(code: str, value: str) -> list[str]:
    out = [value]
    def add(v: str) -> None:
        v = v.strip()
        if v and v not in out:
            out.append(v)
    if code.startswith("Q"):
        m = re.match(r"^(?:V\d+;B\d+;Ch\s*[\d.]+|BBM;Ch\s*[\d.]+):\s*(.+)$", value)
        if m:
            add(m.group(1))
    for v in list(out):
        add(v.replace(" (Int.)", " (Intermediate)"))
        add(v.replace(" (Adv.)", " (Advanced)"))
    return out


def pick_title(rows: list[tuple[str, str, str, str]]) -> tuple[str, str, str] | None:
    if not rows:
        return None
    # Prefer a display-ready official label rather than a PLAYERNAME macro.
    plain = [row for row in rows if "${PLAYERNAME:" not in row[3]]
    candidates = plain or rows
    rendered = {readable(row[3]) for row in candidates}
    if len(rendered) != 1:
        return None
    row = sorted(candidates, key=lambda r: (r[0], r[1]))[0]
    return readable(row[3]), row[2], f"{row[0]}:{row[1]}"


def faction_name_candidates(value: str) -> set[str]:
    values = {value.strip(), FACTION_ALIASES.get(value, value).strip()}
    out = set()
    for item in values:
        out.add(norm(item))
        if item.lower().startswith("the "):
            out.add(norm(item[4:]))
        else:
            out.add(norm("The " + item))
    return {v for v in out if v}


def find_faction(old_name: str, factions: list[dict]) -> tuple[dict, str] | None:
    wanted = faction_name_candidates(old_name)
    exact = []
    for faction in factions:
        fn = faction_name_candidates(faction["en"])
        if wanted & fn:
            exact.append(faction)
    if len(exact) == 1:
        return exact[0], "exact/alias"
    if len(exact) > 1:
        return None

    target = norm(FACTION_ALIASES.get(old_name, old_name))
    scored = []
    for faction in factions:
        score = difflib.SequenceMatcher(None, target, norm(faction["en"])).ratio()
        scored.append((score, faction))
    scored.sort(key=lambda item: item[0], reverse=True)
    if not scored:
        return None
    best_score, best = scored[0]
    second = scored[1][0] if len(scored) > 1 else 0.0
    if best_score >= 0.78 and best_score - second >= 0.08:
        return best, f"fuzzy {best_score:.3f}"
    return None


def parse_rep(value: str) -> tuple[str, str] | None:
    match = re.match(r"^(Acq\.|Friend|Ally|Kindred|Respected|Esteemed|Fabaral)\s+(?:to|with|in|of)\s+(.+)$", value, re.I)
    if not match:
        return None
    rank = match.group(1)
    rank = {"acq.": "Acquaintance", **RANK_ALIASES}.get(rank.lower(), rank)
    return rank, match.group(2).strip()


def lua_quote(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def main() -> None:
    reqs = extract_reqs(DATA.read_text(encoding="utf-8-sig"))

    # Exact official deed/quest title index.
    title_index: dict[str, list[tuple[str, str, str, str]]] = defaultdict(list)
    loaded = []
    for filename in TITLE_SOURCES:
        en = fetch_labels("en", filename)
        fr = fetch_labels("fr", filename)
        paired = 0
        for key, en_value in en.items():
            fr_value = fr.get(key)
            if not fr_value:
                continue
            paired += 1
            title_index[norm(en_value)].append((filename, key, en_value, fr_value))
        loaded.append((filename, paired))

    # Faction/standing data. The structured file tells us which localized rank
    # key belongs to each faction, including non-standard reputation ladders.
    faction_en = fetch_labels("en", "factions.xml")
    faction_fr = fetch_labels("fr", "factions.xml")
    faction_root = fetch_xml(FACTIONS_URL)
    factions = []
    for node in faction_root.findall("faction"):
        fid = node.attrib.get("id")
        en_name = faction_en.get(fid) or node.attrib.get("name")
        fr_name = faction_fr.get(fid)
        if not fid or not en_name or not fr_name:
            continue
        levels = []
        for level in node.findall("level"):
            label_key = level.attrib.get("name")
            if not label_key:
                continue
            en_rank = faction_en.get(label_key)
            fr_rank = faction_fr.get(label_key)
            if en_rank and fr_rank:
                levels.append((clean(en_rank), readable(fr_rank), level.attrib.get("key", "")))
        factions.append({"id": fid, "en": clean(en_name), "fr": clean(fr_name), "levels": levels})

    matches: dict[str, tuple[str, str]] = {}
    unresolved: dict[str, str] = {}
    details = []

    for code, old in sorted(reqs.items()):
        direct = None
        for candidate in title_candidates(code, old):
            direct = pick_title(title_index.get(norm(candidate), []))
            if direct:
                break
        if direct:
            fr, official_en, source = direct
            matches[code] = (fr, f"official title {source}; EN={official_en}")
            details.append((code, old, fr, matches[code][1]))
            continue

        rep = parse_rep(old) if code.startswith("R") else None
        if rep:
            wanted_rank, old_faction = rep
            found_faction = find_faction(old_faction, factions)
            if found_faction:
                faction, method = found_faction
                rank_rows = [row for row in faction["levels"] if norm(row[0]) == norm(wanted_rank)]
                rank_values = {row[1] for row in rank_rows}
                if len(rank_values) == 1:
                    rank_fr = next(iter(rank_values))
                    fr = f"{rank_fr} — {clean(faction['fr'])}"
                    source = f"official faction {faction['id']} ({method}); EN rank={wanted_rank}; EN faction={faction['en']}"
                    matches[code] = (fr, source)
                    details.append((code, old, fr, source))
                    continue

        legacy = LEGACY_QUEST_FR.get(code)
        if legacy:
            source = "verified historical French LOTRO/Tolkien quest title"
            matches[code] = (legacy, source)
            details.append((code, old, legacy, source))
            continue

        unresolved[code] = old

    lines = [
        "-- AUTO-GENERATED. Do not edit by hand.",
        "-- coding: utf-8 'ä",
        "-- Requirement labels are sourced from official LOTRO EN/FR localization IDs.",
        "-- Reputation fallbacks combine an official localized standing with an official localized faction.",
        "",
        "TR_OfficialReqFR = TR_OfficialReqFR or {}",
    ]
    for code, (fr, source) in sorted(matches.items()):
        lines.append(f"TR_OfficialReqFR[{lua_quote(code)}] = {lua_quote(fr)} -- {source}")
    lines += [
        "",
        "if type(Reqs) == \"table\" then",
        "    for code,fr in pairs(TR_OfficialReqFR) do Reqs[code] = fr end",
        "end",
    ]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    report = [
        "TravelRef official French requirement audit",
        "===========================================",
        "",
    ]
    report += [f"- {name}: {count} paired EN/FR labels" for name, count in loaded]
    report += [
        f"- factions.xml: {len(factions)} localized factions with structured standing data",
        "",
        f"Requirements extracted: {len(reqs)}",
        f"Matched officially: {len(matches)}",
        f"Unmatched: {len(unresolved)}",
        "",
        "MATCHED:",
    ]
    for code, old, fr, source in details:
        report.append(f"- {code}: {old} => {fr} [{source}]")
    report += ["", "UNMATCHED:"]
    for code, old in sorted(unresolved.items()):
        report.append(f"- {code}: {old}")
    REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")

    print(f"Matched {len(matches)}/{len(reqs)} requirements; unmatched {len(unresolved)}")
    print(f"Generated {OUT.relative_to(ROOT)}")
    print(f"Audit report: {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
