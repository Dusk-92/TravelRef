#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate TravelRef official French labels from LotroCompanion/lotro-data.

The generator joins English and French LOTRO labels by the SAME localization
key. It then keeps only labels that can be matched to names actually present
in TravelRef's TR_Data.lua. Internal TravelRef keys are never modified.
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
# Priority matters: travel UI labels are the best semantic match for TravelRef.
SOURCES = [
    ("travelsMap.xml", 0),
    ("travelsWeb.xml", 1),
    ("dungeons.xml", 2),
    ("landmarks.xml", 3),
    ("geoAreas.xml", 4),
]

INTERNAL_SUFFIX_RE = re.compile(r"\(([A-Z]+)\)$")
TRAVEL_SUFFIX_RE = re.compile(
    r"\s*-\s*(?:Swift(?: Travel)?|Boat Travel|Rapid Travel|Travel)\s*$",
    re.IGNORECASE,
)
PAREN_SUFFIX_RE = re.compile(r"\s*\([^()]+\)\s*$")

# Known old TravelRef spellings/typos which cannot be recovered safely by
# accent/punctuation normalization alone. Values are official English labels.
LEGACY_EN_ALIASES = {
    "Sudultirh Outpost": "Sudulthurkh Outpost",
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

    # Some modern labels use ', the ...' as an explanatory qualifier.
    for item in list(values):
        values.add(re.sub(r",\s+the\s+.+$", "", item, flags=re.I).strip())

    return {item for item in values if item}


def extract_travelref_names(text: str) -> tuple[set[str], set[str], set[str]]:
    # Every bracket key catches locations and destinations in Locs/R_Dest.
    bracket_keys = set(re.findall(r'\["((?:\\.|[^"\\])*)"\]\s*=', text))
    # Explicit location-ish fields used elsewhere by TravelRef.
    named = set(re.findall(r'\bn\s*=\s*"((?:\\.|[^"\\])*)"', text))
    zones = set(re.findall(r'\bz\s*=\s*"((?:\\.|[^"\\])*)"', text))
    areas = set(re.findall(r'\ba\s*=\s*"((?:\\.|[^"\\])*)"', text))

    def clean(items: set[str]) -> set[str]:
        out = set()
        for item in items:
            item = item.replace('\\"', '"').replace('\\\\', '\\').strip()
            if item:
                out.add(item)
        return out

    locations = clean(bracket_keys | named)
    return locations, clean(zones), clean(areas)


def choose(records: list[tuple[int, str, str, str]]) -> tuple[str, str, str] | None:
    """Pick the highest-priority unambiguous FR label."""
    if not records:
        return None
    best_priority = min(row[0] for row in records)
    best = [row for row in records if row[0] == best_priority]
    french = {row[2] for row in best}
    if len(french) != 1:
        return None
    row = sorted(best, key=lambda r: (len(r[1]), r[1]))[0]
    return row[2], row[1], row[3]


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
        search_names = [base]
        if base.lower().startswith("the "):
            search_names.append(base[4:].strip())
        legacy = LEGACY_EN_ALIASES.get(base)
        if legacy:
            search_names.insert(0, legacy)

        # Exact official labels first.
        for candidate in search_names:
            result = choose(exact.get(norm(candidate), []))
            if result:
                return result
        # Then conservative aliases such as stripped travel/region qualifiers.
        for candidate in search_names:
            result = choose(aliases.get(norm(candidate), []))
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

    for name, (fr, en_official, source) in sorted(loc_matches.items(), key=lambda x: x[0].lower()):
        base = strip_internal_suffix(name)
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

    # The unresolved list intentionally includes non-location keys from the Lua
    # database too; it is an audit aid, not a claim that every line needs FR.
    report = [
        "TravelRef official French localization audit",
        "===========================================",
        "",
        "Official sources loaded:",
    ]
    report += [f"- {name}: {count} paired EN/FR labels" for name, count in loaded_sources]
    report += [
        "",
        f"TravelRef location-like names extracted: {len(locations)}",
        f"Matched location-like names: {len(loc_matches)}",
        f"Zone names extracted: {len(zones)} / matched: {len(zone_matches)}",
        f"Area names extracted: {len(areas)} / matched: {len(area_matches)}",
        "",
        "Unresolved extracted names (includes non-location database keys):",
    ]
    report += [f"- {name}" for name in sorted(unresolved, key=str.lower)]
    REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")

    print(f"Generated {OUT.relative_to(ROOT)} with {len(loc_matches)} location mappings")
    print(f"Matched {len(zone_matches)} zones and {len(area_matches)} areas")
    print(f"Audit report: {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
