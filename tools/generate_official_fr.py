#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate TravelRef official French labels from LotroCompanion/lotro-data.

English and French labels are always joined by the SAME LOTRO localization key.
Only names actually used by TravelRef's travel-location database are emitted;
internal route keys remain untouched.
"""

from __future__ import annotations

import html
import re
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TR_DATA = ROOT / "Dusk" / "TravelRef" / "TR_Data.lua"
OUT = ROOT / "Dusk" / "TravelRef" / "TR_OfficialFR_Auto.lua"
REPORT = ROOT / "tools" / "TR_OfficialFR_Audit.txt"

BASE = "https://raw.githubusercontent.com/LotroCompanion/lotro-data/master/lore/labels"
# Priority matters: TravelRef is a travel addon, so travel UI labels win over
# generic landmark/area/map labels when both exist.
SOURCES = [
    ("travelsMap.xml", 0),
    ("travelsWeb.xml", 1),
    ("dungeons.xml", 2),
    ("landmarks.xml", 3),
    ("geoAreas.xml", 4),
    ("parchmentMaps.xml", 5),
]

INTERNAL_SUFFIX_RE = re.compile(r"\(([A-Z]+)\)$")
TRAVEL_SUFFIX_RE = re.compile(
    r"\s*-\s*(?:Swift(?: Travel)?|Boat Travel|Rapid Travel|Travel)\s*$",
    re.IGNORECASE,
)
PAREN_SUFFIX_RE = re.compile(r"\s*\([^()]+\)\s*$")
ACTION_PREFIX_RE = re.compile(r"^(?:To|Travel to|Boat to)\s+", re.IGNORECASE)
EAGLE_SUFFIX_RE = re.compile(r"\s*-\s*Eagle\s*$", re.IGNORECASE)

# Old TravelRef spellings/typos which cannot safely be recovered by mere
# accent/punctuation normalization. Values are current official EN labels.
LEGACY_EN_ALIASES = {
    "Aethir": "Aerthir",
    "Bloody Eagle Tavern": "The Bloody Eagle Tavern",
    "Echad Dunnan": "Echad Dúnann",
    "Falathorn Homesteads": "Falathlorn Homesteads",
    "Hall Under the Mtn": "Hall Under the Mountain",
    "Sudultirh Outpost": "Sudulthurkh Outpost",
    "The Vinyards of Lorien": "The Vineyards of Lórien",
    "To Mins Tirith, Before the Battle": "Minas Tirith (before battle)",
    "Great River": "The Great River",
    "West Rohan": "Western Rohan",
    "East Gondor": "Eastern Gondor",
    "West Gondor": "Western Gondor",
    "Valley of Ikorbad": "Valley of Ikorbân",
}


def fetch_labels(lang: str, filename: str) -> dict[str, str]:
    url = f"{BASE}/{lang}/{filename}"
    with urllib.request.urlopen(url, timeout=45) as response:
        payload = response.read()
    root = ET.fromstring(payload)
    return {
        node.attrib["key"]: html.unescape(node.attrib.get("value", "")).strip()
        for node in root.findall("label")
        if node.attrib.get("key") and node.attrib.get("value")
    }


def deaccent(value: str) -> str:
    value = value.replace("œ", "oe").replace("Œ", "OE")
    value = value.replace("æ", "ae").replace("Æ", "AE")
    value = unicodedata.normalize("NFKD", value)
    return "".join(ch for ch in value if not unicodedata.combining(ch))


def norm(value: str) -> str:
    value = deaccent(value).lower()
    return "".join(ch for ch in value if ch.isalnum())


def strip_internal_suffix(value: str) -> str:
    return INTERNAL_SUFFIX_RE.sub("", value).strip()


def official_aliases(value: str) -> set[str]:
    """Conservative aliases for historical TravelRef naming differences."""
    values = {value.strip()}

    no_travel = TRAVEL_SUFFIX_RE.sub("", value).strip()
    values.add(no_travel)

    for item in list(values):
        values.add(PAREN_SUFFIX_RE.sub("", item).strip())

    for item in list(values):
        if item.lower().startswith("the "):
            values.add(item[4:].strip())

    for item in list(values):
        values.add(re.sub(r",\s+the\s+.+$", "", item, flags=re.I).strip())

    return {item for item in values if item}


def travelref_candidates(value: str) -> list[str]:
    """Return safe official-name candidates for TravelRef action-style keys."""
    values = [value.strip()]

    def add(item: str) -> None:
        item = item.strip()
        if item and item not in values:
            values.append(item)

    # TravelRef sometimes stores an action as the destination key.
    for item in list(values):
        add(ACTION_PREFIX_RE.sub("", item))
        add(EAGLE_SUFFIX_RE.sub("", item))

    # Apply the two transforms together as well (e.g. action + transport tag).
    for item in list(values):
        add(EAGLE_SUFFIX_RE.sub("", ACTION_PREFIX_RE.sub("", item)))

    # Old TravelRef wording vs current map/resource wording.
    for item in list(values):
        add(re.sub(r"\bHousing\b", "Homesteads", item, flags=re.I))
        add(re.sub(r",\s*After the Battle$", " (after battle)", item, flags=re.I))
        add(re.sub(r",\s*Before the Battle$", " (before battle)", item, flags=re.I))

    # Article variants are common between TravelRef and current LOTRO labels.
    for item in list(values):
        if item.lower().startswith("the "):
            add(item[4:])
        else:
            add("The " + item)

    return values


def section(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise RuntimeError(f"Missing section start: {start_marker}")
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise RuntimeError(f"Missing section end: {end_marker}")
    return text[start:end]


def extract_travelref_names(text: str) -> tuple[set[str], set[str], set[str]]:
    """Extract only real travel nodes/destinations, zones and areas.

    This intentionally ignores Barter, Return metadata, NPC names, item IDs,
    etc. The previous broad audit counted those as false-positive 'places'.
    """
    r_dest = section(text, "R_Dest = {", "R_Locs = {")
    locs = section(text, "Locs = {", "\nrType =")
    travel_text = r_dest + "\n" + locs

    bracket_keys = set(re.findall(r'\["((?:\\.|[^"\\])*)"\]\s*=', travel_text))
    # In Locs, n= is an alternate display/location name, not a barter NPC.
    named = set(re.findall(r'\bn\s*=\s*"((?:\\.|[^"\\])*)"', locs))
    zones = set(re.findall(r'\bz\s*=\s*"((?:\\.|[^"\\])*)"', locs))
    areas = set(re.findall(r'\ba\s*=\s*"((?:\\.|[^"\\])*)"', locs))

    def clean(items: set[str]) -> set[str]:
        out = set()
        for item in items:
            item = item.replace('\\"', '"').replace('\\\\', '\\').strip()
            if item:
                out.add(item)
        return out

    return clean(bracket_keys | named), clean(zones), clean(areas)


def choose(records: list[tuple[int, int, str, str, str]]) -> tuple[str, str, str] | None:
    """Pick highest-priority, then most exact, unambiguous official label."""
    if not records:
        return None
    best_rank = min((row[0], row[1]) for row in records)
    best = [row for row in records if (row[0], row[1]) == best_rank]
    french = {row[3] for row in best}
    if len(french) != 1:
        return None
    row = sorted(best, key=lambda r: (len(r[2]), r[2]))[0]
    return row[3], row[2], row[4]


def lua_quote(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def main() -> None:
    data = TR_DATA.read_text(encoding="utf-8-sig")
    locations, zones, areas = extract_travelref_names(data)

    exact: dict[str, list[tuple[int, str, str, str]]] = defaultdict(list)
    aliases: dict[str, list[tuple[int, str, str, str]]] = defaultdict(list)

    loaded_sources = []
    for filename, priority in SOURCES:
        en = fetch_labels("en", filename)
        fr = fetch_labels("fr", filename)
        count = 0
        for key, en_value in en.items():
            fr_value = fr.get(key)
            if not fr_value:
                continue
            count += 1
            record = (priority, en_value, fr_value, filename)
            exact[norm(en_value)].append(record)
            for alias in official_aliases(en_value):
                aliases[norm(alias)].append(record)
        loaded_sources.append((filename, count))

    def match(name: str):
        base = strip_internal_suffix(name)
        search_names = []
        legacy = LEGACY_EN_ALIASES.get(base)
        if legacy:
            search_names.extend(travelref_candidates(legacy))
        for candidate in travelref_candidates(base):
            if candidate not in search_names:
                search_names.append(candidate)

        for candidate in search_names:
            key = norm(candidate)
            records = []
            records += [(p, 0, en, fr, src) for p, en, fr, src in exact.get(key, [])]
            records += [(p, 1, en, fr, src) for p, en, fr, src in aliases.get(key, [])]
            result = choose(records)
            if result:
                return result
        return None

    loc_matches = {}
    zone_matches = {}
    area_matches = {}
    unresolved = []

    for name in sorted(locations):
        result = match(name)
        if result:
            loc_matches[name] = result
        else:
            unresolved.append(name)

    for name in sorted(zones):
        result = match(name)
        if result:
            zone_matches[name] = result

    for name in sorted(areas):
        result = match(name)
        if result:
            area_matches[name] = result

    lines = [
        "-- AUTO-GENERATED. Do not edit by hand.",
        "-- coding: utf-8 'ä",
        "-- Source: LotroCompanion/lotro-data official EN/FR localization tables.",
        "-- English and French values are joined by identical localization IDs.",
        "",
        "TR_OfficialLocRaw = TR_OfficialLocRaw or {}",
        "TR_OfficialZoneRaw = TR_OfficialZoneRaw or {}",
        "TR_OfficialAreaRaw = TR_OfficialAreaRaw or {}",
        "",
    ]

    # Suffix variants such as (B)/(R)/(KG) share the same display base, so emit
    # each base only once.
    emitted = set()
    for name, (fr, en_official, source) in sorted(loc_matches.items(), key=lambda x: x[0].lower()):
        base = strip_internal_suffix(name)
        if base in emitted:
            continue
        emitted.add(base)
        lines.append(
            f"TR_OfficialLocRaw[{lua_quote(base)}] = {lua_quote(fr)} -- {source}: {en_official}"
        )

    lines.append("")
    for name, (fr, en_official, source) in sorted(zone_matches.items(), key=lambda x: x[0].lower()):
        lines.append(
            f"TR_OfficialZoneRaw[{lua_quote(name)}] = {lua_quote(fr)} -- {source}: {en_official}"
        )

    lines.append("")
    for name, (fr, en_official, source) in sorted(area_matches.items(), key=lambda x: x[0].lower()):
        lines.append(
            f"TR_OfficialAreaRaw[{lua_quote(name)}] = {lua_quote(fr)} -- {source}: {en_official}"
        )

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    report = [
        "TravelRef official French localization audit",
        "===========================================",
        "",
        "Official sources loaded:",
    ]
    report += [f"- {name}: {count} paired EN/FR labels" for name, count in loaded_sources]
    report += [
        "",
        f"Real TravelRef location/destination names extracted: {len(locations)}",
        f"Matched location/destination names: {len(loc_matches)}",
        f"Unmatched location/destination names: {len(unresolved)}",
        f"Zone names extracted: {len(zones)} / matched: {len(zone_matches)}",
        f"Area names extracted: {len(areas)} / matched: {len(area_matches)}",
        "",
        "Unmatched real TravelRef location/destination names:",
    ]
    report += [f"- {name}" for name in sorted(unresolved, key=str.lower)]
    REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")

    print(f"Generated {OUT.relative_to(ROOT)} with {len(emitted)} unique location mappings")
    print(f"Matched {len(loc_matches)}/{len(locations)} TravelRef location/destination names")
    print(f"Matched {len(zone_matches)}/{len(zones)} zones and {len(area_matches)}/{len(areas)} areas")
    print(f"Audit report: {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
