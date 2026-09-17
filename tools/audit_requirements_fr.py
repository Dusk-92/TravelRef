#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations
import html
import re
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Dusk" / "TravelRef" / "TR_Data.lua"
REPORT = ROOT / "tools" / "TR_RequirementsFR_Audit.txt"
BASE = "https://raw.githubusercontent.com/LotroCompanion/lotro-data/master/lore/labels"
SOURCES = ["deeds.xml", "quests.xml"]
GRAMMAR = re.compile(r"\[(?:m|f|n|mp|fp|np)\]", re.I)


def clean(v):
    return GRAMMAR.sub("", html.unescape(v).replace("\u00a0", " ")).strip()


def norm(v):
    v = clean(v).replace("œ", "oe").replace("Œ", "OE").replace("æ", "ae").replace("Æ", "AE")
    v = unicodedata.normalize("NFKD", v).lower()
    v = "".join(ch for ch in v if not unicodedata.combining(ch))
    return "".join(ch for ch in v if ch.isalnum())


def fetch(lang, filename):
    url = f"{BASE}/{lang}/{filename}"
    with urllib.request.urlopen(url, timeout=120) as r:
        root = ET.fromstring(r.read())
    return {x.attrib["key"]: clean(x.attrib.get("value", "")) for x in root.findall("label") if x.attrib.get("key") and x.attrib.get("value")}


def extract_reqs(text):
    start = text.index("Reqs = {")
    end = text.index("\n\t}", start)
    block = text[start:end]
    return {m.group(1): m.group(2) for m in re.finditer(r'^\s*([DQR]\d+)\s*=\s*"([^"]+)"', block, re.M)}


def candidates(code, value):
    out = [value]
    def add(v):
        v = v.strip()
        if v and v not in out: out.append(v)
    if code.startswith("Q"):
        m = re.match(r"^(?:V\d+;B\d+;Ch\s*[\d.]+|BBM;Ch\s*[\d.]+):\s*(.+)$", value)
        if m: add(m.group(1))
    for v in list(out):
        add(v.replace(" (Int.)", " (Intermediate)"))
        add(v.replace(" (Adv.)", " (Advanced)"))
        add(v.replace("Acq. with ", "Acquaintance with "))
    return out


def main():
    reqs = extract_reqs(DATA.read_text(encoding="utf-8-sig"))
    index = defaultdict(list)
    counts = []
    for filename in SOURCES:
        en = fetch("en", filename)
        fr = fetch("fr", filename)
        paired = 0
        for key, ev in en.items():
            fv = fr.get(key)
            if not fv: continue
            paired += 1
            index[norm(ev)].append((filename, key, ev, fv))
        counts.append((filename, paired))

    matched = {}
    ambiguous = {}
    unmatched = {}
    for code, value in reqs.items():
        found = []
        for c in candidates(code, value):
            rows = index.get(norm(c), [])
            if rows:
                found = rows
                break
        french = {r[3] for r in found}
        if len(french) == 1:
            r = sorted(found, key=lambda x:(x[0],x[1]))[0]
            matched[code] = (value, r[3], r[0], r[1], r[2])
        elif found:
            ambiguous[code] = (value, found)
        else:
            unmatched[code] = value

    lines = ["TravelRef requirement localization audit", "========================================", ""]
    lines += [f"- {f}: {n} paired EN/FR labels" for f,n in counts]
    lines += ["", f"Requirements extracted: {len(reqs)}", f"Matched officially: {len(matched)}", f"Ambiguous: {len(ambiguous)}", f"Unmatched: {len(unmatched)}", "", "MATCHED:"]
    for code, (old, fr, src, key, official_en) in sorted(matched.items()):
        lines.append(f"- {code}: {old} => {fr} [{src} {key}; EN={official_en}]")
    lines += ["", "AMBIGUOUS:"]
    for code,(old,rows) in sorted(ambiguous.items()):
        lines.append(f"- {code}: {old}")
        for r in rows[:10]: lines.append(f"    {r[0]} {r[1]}: EN={r[2]} | FR={r[3]}")
    lines += ["", "UNMATCHED:"]
    for code, old in sorted(unmatched.items()): lines.append(f"- {code}: {old}")
    REPORT.write_text("\n".join(lines)+"\n", encoding="utf-8")
    print(f"Matched {len(matched)}/{len(reqs)}, ambiguous {len(ambiguous)}, unmatched {len(unmatched)}")

if __name__ == "__main__": main()
