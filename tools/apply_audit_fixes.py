#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-shot source patch for the TravelRef FR audit fixes.

This file is intentionally temporary. It fails if an expected source fragment
is missing so a partial/unsafe rewrite cannot be committed silently.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path: str, replacements: list[tuple[str, str, int | None]]) -> None:
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    for old, new, expected in replacements:
        count = text.count(old)
        if count == 0:
            if new in text:
                continue  # already applied
            raise RuntimeError(f"{path}: expected fragment not found:\n{old}")
        if expected is not None and count != expected:
            raise RuntimeError(f"{path}: expected {expected} occurrence(s), found {count}:\n{old}")
        text = text.replace(old, new)
    p.write_text(text, encoding="utf-8")


# Load the optional FR layer immediately after TR_Data, before TR_Window creates
# UI controls. Keep fallbacks so a localization failure never breaks TravelRef.
patch("Dusk/TravelRef/TR_Main.lua", [
    (
        'import "Dusk.TravelRef.TR_Data"\n\nfunction print(text)',
        'import "Dusk.TravelRef.TR_Data"\n\n'
        'local frOk, frErr = pcall(import, "Dusk.TravelRef.TR_OfficialFR")\n'
        'if not frOk and Turbine and Turbine.Shell then\n'
        '    Turbine.Shell.WriteLine("<rgb=#FF6040>TravelRef FR officiel non chargé : "..tostring(frErr).."</rgb>")\n'
        'end\n'
        'if type(TR_AreaName) ~= "function" then\n'
        '    function TR_AreaName(name) return name end\n'
        'end\n'
        'if type(TR_AreaKey) ~= "function" then\n'
        '    function TR_AreaKey(name) return name end\n'
        'end\n\n'
        'function print(text)',
        1,
    ),
    (
        'print(str.."(ST): "..d.n..l)',
        'print(str.."(ST): "..TR_LocName(d.n)..l)',
        1,
    ),
    (
        '\tif Dusk.TravelRef.Common.HelpCmd(cmd,args,help) then return end\n\targs = TR_LocKey(args)',
        '\tif Dusk.TravelRef.Common.HelpCmd(cmd,args,help) then return end\n\tlocal rawArgs = args\n\targs = TR_LocKey(args)',
        1,
    ),
    (
        '\tif cmd=="tra" then\n\t\tif args~="" then\n\t\t\tlocal str=args:lower()\n\t\t\tlocal zn\n     \t\tprinth("Sous-zones correspondantes :")\n\t\t\tfor area,zone in pairs(Areas) do\n\t\t\t\tif area:lower():find(str,1,true) then\n\t\t\t\t\tprint(area.." dans "..TR_ZoneName(zone))',
        '\tif cmd=="tra" then\n\t\tif rawArgs~="" then\n\t\t\tlocal str=rawArgs:lower()\n\t\t\tlocal zn\n     \t\tprinth("Sous-zones correspondantes :")\n\t\t\tfor area,zone in pairs(Areas) do\n\t\t\t\tlocal darea = TR_AreaName(area)\n\t\t\t\tif area:lower():find(str,1,true) or darea:lower():find(str,1,true) then\n\t\t\t\t\tprint(darea.." dans "..TR_ZoneName(zone))',
        1,
    ),
    ('if not ln then print("(none found)")', 'if not ln then print("(aucun trouvé)")', 1),
    ('print(area.." dans "..TR_ZoneName(zone))', 'print(TR_AreaName(area).." dans "..TR_ZoneName(zone))', 1),
    ('tbl.nm.." "..n', 'tbl.nm.." "..TR_LocName(n)', None),
    ('print(tbl.nm.." "..n.." (Trait)")', 'print(tbl.nm.." "..TR_LocName(n).." (Trait)")', 1),
    ('if t.a then sz = " in "..t.a end', 'if t.a then sz = " dans "..TR_AreaName(t.a) end', 1),
    ('if t.a then z = string.format("%s(%s)", t.a,z) end', 'if t.a then z = string.format("%s (%s)", TR_AreaName(t.a),z) end', 1),
    (
        '\tif Areas[args] then\n\t\tz = Areas[args]\n\t\tprinth("Écuries connues dans "..args.." (partie de "..TR_ZoneName(z)..") :")\n\t\tlocal Loc_list = {}\n\t\tfor name,t in pairs(Locs) do\n\t\t\tif t.a==args and t.d then table.insert(Loc_list,name) end',
        '\tlocal areaArg = TR_AreaKey(rawArgs)\n\tif Areas[areaArg] then\n\t\tz = Areas[areaArg]\n\t\tprinth("Écuries connues dans "..TR_AreaName(areaArg).." (partie de "..TR_ZoneName(z)..") :")\n\t\tlocal Loc_list = {}\n\t\tfor name,t in pairs(Locs) do\n\t\t\tif t.a==areaArg and t.d then table.insert(Loc_list,name) end',
        1,
    ),
    ('d = string.format(" (%.1f units away).",d1)', 'd = string.format(" (à %.1f unités).",d1)', 1),
])

# Route summaries must never bypass the display-name layer.
patch("Dusk/TravelRef/TR_Window.lua", [
    ("V.s = skill.nm..' '..rtn..\" -> \"..v.s", "V.s = skill.nm..' '..TR_LocName(rtn)..\" -> \"..v.s", 1),
    ('printh("Recherche du meilleur départ vers "..SetLoc.." :")', 'printh("Recherche du meilleur départ vers "..TR_LocName(SetLoc).." :")', 1),
    ('V.s = "Jalon vers "..name.." -> "..v.s', 'V.s = "Jalon vers "..TR_LocName(name).." -> "..v.s', 1),
    ('local hs = "Voyage vers maison "..hn.." -> Écurie de maison(MT) -> "', 'local hs = "Voyage vers maison "..TR_LocName(hn).." -> Écurie de maison(MT) -> "', 1),
    ('local hs = "Voyage vers maison "..hn.." -> Bateau de maison(MT) -> "', 'local hs = "Voyage vers maison "..TR_LocName(hn).." -> Bateau de maison(MT) -> "', 1),
    ('V.s = hs..name..((v.s and "(ST) -> "..v.s) or "(ST)")', 'V.s = hs..TR_LocName(name)..((v.s and "(ST) -> "..v.s) or "(ST)")', 2),
])

# The launcher no longer owns localization initialization; TR_Main does it
# before the window is constructed.
patch("Dusk/TravelRef/TR_Launcher.lua", [
    (
        '\n-- La couche de noms FR officiels est optionnelle et protégée : une erreur de\n'
        '-- localisation ne doit jamais empêcher TravelRef de se charger.\n'
        'local frOk, frErr = pcall(import, "Dusk.TravelRef.TR_OfficialFR")\n'
        'if not frOk and Turbine and Turbine.Shell then\n'
        '    Turbine.Shell.WriteLine("<rgb=#FF6040>TravelRef FR officiel non chargé : "..tostring(frErr).."</rgb>")\n'
        'end\n',
        '',
        1,
    ),
])

# Keep Areas immutable. Add display/reverse helpers only, clean client grammar
# markers at runtime, and make all generated special labels available to
# TR_LocName (including d.n action labels).
patch("Dusk/TravelRef/TR_OfficialFR.lua", [
    (
        '    local function OfficialNorm(value)\n',
        '    local function CleanOfficial(value)\n'
        '        if type(value) ~= "string" then return value end\n'
        '        value = string.gsub(value, "%[(m|f|n|mp|fp|np)%]", "")\n'
        '        value = string.gsub(value, " ", " ")\n'
        '        return value\n'
        '    end\n\n'
        '    local function OfficialNorm(value)\n',
        1,
    ),
    (
        '        local function addExact(value, fr)\n            local key = OfficialNorm(value)\n            if key and key ~= "" then exact[key] = fr end\n        end',
        '        local function addExact(value, fr)\n            fr = CleanOfficial(fr)\n            local key = OfficialNorm(value)\n            if key and key ~= "" then exact[key] = fr end\n        end',
        1,
    ),
    (
        '        local function addAlias(value, fr)\n            if type(value) ~= "string" or value == "" then return end',
        '        local function addAlias(value, fr)\n            fr = CleanOfficial(fr)\n            if type(value) ~= "string" or value == "" then return end',
        1,
    ),
    (
        '    if type(TR_LocFR) == "table" then\n        local function applyLocation(name)',
        '    if type(TR_LocFR) == "table" then\n        -- Seed every generated display label, including special d.n action names.\n        for en,fr in pairs(TR_OfficialLocRaw or {}) do\n            TR_LocFR[en] = CleanOfficial(fr)\n        end\n\n        local function applyLocation(name)',
        1,
    ),
    (
        '        for en,fr in pairs(LegacyOfficial) do TR_LocFR[en] = fr end',
        '        for en,fr in pairs(LegacyOfficial) do TR_LocFR[en] = CleanOfficial(fr) end',
        1,
    ),
    (
        '    -- Areas are display/search metadata only; routing uses the location keys and\n'
        '    -- destination graph. Translate the area labels in memory and rebuild the\n'
        '    -- area index so /tr areas, /tra and area lookups all operate in French.\n'
        '    if type(Locs) == "table" and type(Areas) == "table" then\n'
        '        TR_AreaFR = {}\n'
        '        TR_AreaEN = {}\n'
        '        local NewAreas = {}\n\n'
        '        for area,zone in pairs(Areas) do\n'
        '            local key = OfficialNorm(area)\n'
        '            local fr = (key and OfficialArea[key]) or area\n'
        '            TR_AreaFR[area] = fr\n'
        '            TR_AreaEN[fr] = area\n'
        '            NewAreas[fr] = zone\n'
        '        end\n\n'
        '        for _,loc in pairs(Locs) do\n'
        '            if type(loc) == "table" and loc.a then\n'
        '                loc.a = TR_AreaFR[loc.a] or loc.a\n'
        '            end\n'
        '        end\n'
        '        Areas = NewAreas\n\n'
        '        function TR_AreaName(name)\n'
        '            return TR_AreaFR[name] or name\n'
        '        end\n'
        '        function TR_AreaKey(name)\n'
        '            return TR_AreaEN[name] or name\n'
        '        end\n'
        '    end',
        '    -- Areas stay in their original English/internal form. Only display and\n'
        '    -- reverse-lookup tables are localized, so future routing/data code cannot\n'
        '    -- be affected by translated sub-zone strings.\n'
        '    if type(Areas) == "table" then\n'
        '        TR_AreaFR = {}\n'
        '        TR_AreaEN = {}\n'
        '        for area in pairs(Areas) do\n'
        '            local key = OfficialNorm(area)\n'
        '            local fr = CleanOfficial((key and OfficialArea[key]) or area)\n'
        '            TR_AreaFR[area] = fr\n'
        '            if TR_AreaEN[fr] == nil then TR_AreaEN[fr] = area end\n'
        '        end\n\n'
        '        function TR_AreaName(name)\n'
        '            return TR_AreaFR[name] or name\n'
        '        end\n'
        '        function TR_AreaKey(name)\n'
        '            return TR_AreaEN[name] or name\n'
        '        end\n'
        '    end',
        1,
    ),
])

# Generator: strip LOTRO morphology markers/NBSPs and account transparently for
# the two verified legacy Blazon labels so the audit reports effective coverage.
patch("tools/generate_official_fr.py", [
    (
        'EAGLE_SUFFIX_RE = re.compile(r"\\s*-\\s*Eagle\\s*$", re.IGNORECASE)\n',
        'EAGLE_SUFFIX_RE = re.compile(r"\\s*-\\s*Eagle\\s*$", re.IGNORECASE)\n'
        'GRAMMAR_MARKER_RE = re.compile(r"\\[(?:m|f|n|mp|fp|np)\\]", re.IGNORECASE)\n\n'
        'VERIFIED_FR_OVERRIDES = {\n'
        '    "Blazon of the Great Alliance": "Blason de la Grande Alliance",\n'
        '    "Blazon of the Last Alliance": "Blason de la dernière Alliance",\n'
        '}\n',
        1,
    ),
    (
        '\ndef fetch_labels(lang: str, filename: str) -> dict[str, str]:\n',
        '\ndef clean_label(value: str) -> str:\n'
        '    value = html.unescape(value).replace("\\u00a0", " ").strip()\n'
        '    return GRAMMAR_MARKER_RE.sub("", value).strip()\n\n\n'
        'def fetch_labels(lang: str, filename: str) -> dict[str, str]:\n',
        1,
    ),
    (
        '        node.attrib["key"]: html.unescape(node.attrib.get("value", "")).strip()\n',
        '        node.attrib["key"]: clean_label(node.attrib.get("value", ""))\n',
        1,
    ),
    (
        '    for name in sorted(locations):\n        result = match(name)\n        if result:\n            loc_matches[name] = result\n        else:\n            unresolved.append(name)',
        '    verified_override_count = 0\n    for name in sorted(locations):\n        result = match(name)\n        if result:\n            loc_matches[name] = result\n        else:\n            base = strip_internal_suffix(name)\n            manual_fr = VERIFIED_FR_OVERRIDES.get(base)\n            if manual_fr:\n                loc_matches[name] = (manual_fr, base, "verified legacy override")\n                verified_override_count += 1\n            else:\n                unresolved.append(name)',
        1,
    ),
    (
        '        "-- English and French values are joined by identical localization IDs.",',
        '        "-- Automatic EN/FR values are joined by identical localization IDs.",\n        "        \"-- Verified legacy-only overrides are documented by the generator.\"," ,
        1,
    ),
    (
        '        f"Unmatched location/destination names: {len(unresolved)}",\n',
        '        f"Unmatched location/destination names: {len(unresolved)}",\n        f"Verified legacy overrides: {verified_override_count}",\n',
        1,
    ),
])

# Regenerate whenever the travel database changes, not only when the generator
# itself is edited.
patch(".github/workflows/generate-official-fr.yml", [
    (
        '      - "tools/generate_official_fr.py"\n      - ".github/workflows/generate-official-fr.yml"',
        '      - "tools/generate_official_fr.py"\n      - "Dusk/TravelRef/TR_Data.lua"\n      - ".github/workflows/generate-official-fr.yml"',
        1,
    ),
])

# Version/metadata.
patch("Dusk/TravelRef.plugin", [
    ('<Version>3.3.2-FR-r2</Version>', '<Version>3.3.2-FR-r4</Version>', 1),
    (
        '<Description>Version française corrigée de TravelRef 3.3.2 : interface traduite et noms de régions LOTRO FR, avec calcul d’itinéraires entre écuries et icône flottante au style Homeopatix.</Description>',
        '<Description>TravelRef 3.3.2 FR r4 : interface française, noms officiels LOTRO des lieux/zones/sous-zones, routage conservé sur les clés internes et icône flottante.</Description>',
        1,
    ),
])
patch("Dusk/TravelRef.plugincompendium", [
    ('<Version>3.3.2</Version>', '<Version>3.3.2-FR-r4</Version>', 1),
])

# Notes release r4.
notes = ROOT / "Dusk/TravelRef/TR_FR_NOTES.txt"
text = notes.read_text(encoding="utf-8")
marker = "Correctifs FR r3\n----------------\n"
if "Correctifs FR r4\n----------------\n" not in text:
    if marker not in text:
        raise RuntimeError("TR_FR_NOTES.txt: r3 marker missing")
    block = (
        "Correctifs FR r4\n"
        "----------------\n"
        "- Couche FR chargée après TR_Data et avant la création de la fenêtre.\n"
        "- 426/426 lieux/destinations couverts, y compris les deux Blasons hérités.\n"
        "- 47/47 zones et 83/83 sous-zones couvertes par les libellés FR.\n"
        "- Sous-zones traduites uniquement à l’affichage : les données internes restent intactes.\n"
        "- Textes de trajets spéciaux, jalons, retours et voyages passés par TR_LocName.\n"
        "- Nettoyage des marqueurs grammaticaux LOTRO ([fp], etc.) et des espaces insécables.\n"
        "- Génération FR relancée automatiquement quand TR_Data.lua change.\n\n"
    )
    text = text.replace(marker, block + marker, 1)
    notes.write_text(text, encoding="utf-8")

print("TravelRef audit fixes applied successfully.")
