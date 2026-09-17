#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Temporary one-shot patcher for the TravelRef FR audit fixes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str, expected: int = 1) -> None:
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count == 0 and new in text:
        return
    if count != expected:
        raise RuntimeError(f"{path}: expected {expected} occurrence(s), got {count}: {old!r}")
    p.write_text(text.replace(old, new), encoding="utf-8")


# --- TR_Main.lua -----------------------------------------------------------
P = "Dusk/TravelRef/TR_Main.lua"
replace(
    P,
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
)
replace(P, 'print(str.."(ST): "..d.n..l)', 'print(str.."(ST): "..TR_LocName(d.n)..l)')
replace(
    P,
    '\tif Dusk.TravelRef.Common.HelpCmd(cmd,args,help) then return end\n\targs = TR_LocKey(args)',
    '\tif Dusk.TravelRef.Common.HelpCmd(cmd,args,help) then return end\n\tlocal rawArgs = args\n\targs = TR_LocKey(args)',
)
replace(
    P,
    '\tif cmd=="tra" then\n\t\tif args~="" then\n\t\t\tlocal str=args:lower()\n\t\t\tlocal zn\n     \t\tprinth("Sous-zones correspondantes :")\n\t\t\tfor area,zone in pairs(Areas) do\n\t\t\t\tif area:lower():find(str,1,true) then\n\t\t\t\t\tprint(area.." dans "..TR_ZoneName(zone))',
    '\tif cmd=="tra" then\n\t\tif rawArgs~="" then\n\t\t\tlocal str=rawArgs:lower()\n\t\t\tlocal zn\n     \t\tprinth("Sous-zones correspondantes :")\n\t\t\tfor area,zone in pairs(Areas) do\n\t\t\t\tlocal darea = TR_AreaName(area)\n\t\t\t\tif area:lower():find(str,1,true) or darea:lower():find(str,1,true) then\n\t\t\t\t\tprint(darea.." dans "..TR_ZoneName(zone))',
)
replace(P, 'if not ln then print("(none found)")', 'if not ln then print("(aucun trouvé)")')
replace(P, 'print(area.." dans "..TR_ZoneName(zone))', 'print(TR_AreaName(area).." dans "..TR_ZoneName(zone))')
replace(
    P,
    'print(string.format(xlink,id,tbl.nm.." "..n)..s)',
    'print(string.format(xlink,id,tbl.nm.." "..TR_LocName(n))..s)',
    expected=2,
)
replace(P, 'elseif t.r then print(tbl.nm.." "..n.." (Trait)")', 'elseif t.r then print(tbl.nm.." "..TR_LocName(n).." (Trait)")')
replace(P, 'if t.a then sz = " in "..t.a end', 'if t.a then sz = " dans "..TR_AreaName(t.a) end')
replace(P, 'if t.a then z = string.format("%s(%s)", t.a,z) end', 'if t.a then z = string.format("%s (%s)", TR_AreaName(t.a),z) end')
replace(
    P,
    '\tif Areas[args] then\n\t\tz = Areas[args]\n\t\tprinth("Écuries connues dans "..args.." (partie de "..TR_ZoneName(z)..") :")\n\t\tlocal Loc_list = {}\n\t\tfor name,t in pairs(Locs) do\n\t\t\tif t.a==args and t.d then table.insert(Loc_list,name) end',
    '\tlocal areaArg = TR_AreaKey(rawArgs)\n\tif Areas[areaArg] then\n\t\tz = Areas[areaArg]\n\t\tprinth("Écuries connues dans "..TR_AreaName(areaArg).." (partie de "..TR_ZoneName(z)..") :")\n\t\tlocal Loc_list = {}\n\t\tfor name,t in pairs(Locs) do\n\t\t\tif t.a==areaArg and t.d then table.insert(Loc_list,name) end',
)
replace(P, 'd = string.format(" (%.1f units away).",d1)', 'd = string.format(" (à %.1f unités).",d1)')

# --- TR_Window.lua ---------------------------------------------------------
P = "Dusk/TravelRef/TR_Window.lua"
replace(P, "V.s = skill.nm..' '..rtn..\" -> \"..v.s", "V.s = skill.nm..' '..TR_LocName(rtn)..\" -> \"..v.s")
replace(P, 'printh("Recherche du meilleur départ vers "..SetLoc.." :")', 'printh("Recherche du meilleur départ vers "..TR_LocName(SetLoc).." :")')
replace(P, 'V.s = "Jalon vers "..name.." -> "..v.s', 'V.s = "Jalon vers "..TR_LocName(name).." -> "..v.s')
replace(P, 'local hs = "Voyage vers maison "..hn.." -> Écurie de maison(MT) -> "', 'local hs = "Voyage vers maison "..TR_LocName(hn).." -> Écurie de maison(MT) -> "')
replace(P, 'local hs = "Voyage vers maison "..hn.." -> Bateau de maison(MT) -> "', 'local hs = "Voyage vers maison "..TR_LocName(hn).." -> Bateau de maison(MT) -> "')
replace(P, 'V.s = hs..name..((v.s and "(ST) -> "..v.s) or "(ST)")', 'V.s = hs..TR_LocName(name)..((v.s and "(ST) -> "..v.s) or "(ST)")', expected=2)

# --- TR_Launcher.lua -------------------------------------------------------
P = "Dusk/TravelRef/TR_Launcher.lua"
replace(
    P,
    '\n-- La couche de noms FR officiels est optionnelle et protégée : une erreur de\n'
    '-- localisation ne doit jamais empêcher TravelRef de se charger.\n'
    'local frOk, frErr = pcall(import, "Dusk.TravelRef.TR_OfficialFR")\n'
    'if not frOk and Turbine and Turbine.Shell then\n'
    '    Turbine.Shell.WriteLine("<rgb=#FF6040>TravelRef FR officiel non chargé : "..tostring(frErr).."</rgb>")\n'
    'end\n',
    '',
)

# --- TR_OfficialFR.lua -----------------------------------------------------
P = "Dusk/TravelRef/TR_OfficialFR.lua"
replace(
    P,
    '    local function OfficialNorm(value)\n',
    '    local function CleanOfficial(value)\n'
    '        if type(value) ~= "string" then return value end\n'
    '        value = string.gsub(value, "%[[%a]+%]", "")\n'
    '        value = string.gsub(value, "\\194\\160", " ")\n'
    '        return value\n'
    '    end\n\n'
    '    local function OfficialNorm(value)\n',
)
replace(
    P,
    '        local function addExact(value, fr)\n            local key = OfficialNorm(value)\n            if key and key ~= "" then exact[key] = fr end\n        end',
    '        local function addExact(value, fr)\n            fr = CleanOfficial(fr)\n            local key = OfficialNorm(value)\n            if key and key ~= "" then exact[key] = fr end\n        end',
)
replace(
    P,
    '        local function addAlias(value, fr)\n            if type(value) ~= "string" or value == "" then return end',
    '        local function addAlias(value, fr)\n            fr = CleanOfficial(fr)\n            if type(value) ~= "string" or value == "" then return end',
)
replace(
    P,
    '    if type(TR_LocFR) == "table" then\n        local function applyLocation(name)',
    '    if type(TR_LocFR) == "table" then\n'
    '        -- Include generated special action labels (d.n), not only Locs keys.\n'
    '        for en,fr in pairs(TR_OfficialLocRaw or {}) do\n'
    '            TR_LocFR[en] = CleanOfficial(fr)\n'
    '        end\n\n'
    '        local function applyLocation(name)',
)
replace(P, '        for en,fr in pairs(LegacyOfficial) do TR_LocFR[en] = fr end', '        for en,fr in pairs(LegacyOfficial) do TR_LocFR[en] = CleanOfficial(fr) end')
replace(
    P,
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
    '    -- Keep internal area keys immutable; localize display/reverse lookup only.\n'
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
)

# --- Generator -------------------------------------------------------------
P = "tools/generate_official_fr.py"
replace(
    P,
    'EAGLE_SUFFIX_RE = re.compile(r"\\s*-\\s*Eagle\\s*$", re.IGNORECASE)\n',
    'EAGLE_SUFFIX_RE = re.compile(r"\\s*-\\s*Eagle\\s*$", re.IGNORECASE)\n'
    'GRAMMAR_MARKER_RE = re.compile(r"\\[(?:m|f|n|mp|fp|np)\\]", re.IGNORECASE)\n\n'
    'VERIFIED_FR_OVERRIDES = {\n'
    '    "Blazon of the Great Alliance": "Blason de la Grande Alliance",\n'
    '    "Blazon of the Last Alliance": "Blason de la dernière Alliance",\n'
    '}\n',
)
replace(
    P,
    '\ndef fetch_labels(lang: str, filename: str) -> dict[str, str]:\n',
    '\ndef clean_label(value: str) -> str:\n'
    '    value = html.unescape(value).replace("\\u00a0", " ").strip()\n'
    '    return GRAMMAR_MARKER_RE.sub("", value).strip()\n\n\n'
    'def fetch_labels(lang: str, filename: str) -> dict[str, str]:\n',
)
replace(P, '        node.attrib["key"]: html.unescape(node.attrib.get("value", "")).strip()\n', '        node.attrib["key"]: clean_label(node.attrib.get("value", ""))\n')
replace(
    P,
    '    for name in sorted(locations):\n        result = match(name)\n        if result:\n            loc_matches[name] = result\n        else:\n            unresolved.append(name)',
    '    verified_override_count = 0\n'
    '    for name in sorted(locations):\n'
    '        result = match(name)\n'
    '        if result:\n'
    '            loc_matches[name] = result\n'
    '        else:\n'
    '            base = strip_internal_suffix(name)\n'
    '            manual_fr = VERIFIED_FR_OVERRIDES.get(base)\n'
    '            if manual_fr:\n'
    '                loc_matches[name] = (manual_fr, base, "verified legacy override")\n'
    '                verified_override_count += 1\n'
    '            else:\n'
    '                unresolved.append(name)',
)
replace(
    P,
    '        "-- English and French values are joined by identical localization IDs.",',
    '        "-- Automatic EN/FR values are joined by identical localization IDs.",\n'
    '        "-- Verified legacy-only overrides are documented by the generator.",',
)
replace(
    P,
    '        f"Unmatched location/destination names: {len(unresolved)}",\n',
    '        f"Unmatched location/destination names: {len(unresolved)}",\n'
    '        f"Verified legacy overrides: {verified_override_count}",\n',
)

# --- Generator workflow ----------------------------------------------------
P = ".github/workflows/generate-official-fr.yml"
replace(
    P,
    '      - "tools/generate_official_fr.py"\n      - ".github/workflows/generate-official-fr.yml"',
    '      - "tools/generate_official_fr.py"\n      - "Dusk/TravelRef/TR_Data.lua"\n      - ".github/workflows/generate-official-fr.yml"',
)

# --- Metadata --------------------------------------------------------------
P = "Dusk/TravelRef.plugin"
replace(P, '<Version>3.3.2-FR-r2</Version>', '<Version>3.3.2-FR-r4</Version>')
replace(
    P,
    '<Description>Version française corrigée de TravelRef 3.3.2 : interface traduite et noms de régions LOTRO FR, avec calcul d’itinéraires entre écuries et icône flottante au style Homeopatix.</Description>',
    '<Description>TravelRef 3.3.2 FR r4 : interface française, noms officiels LOTRO des lieux/zones/sous-zones, routage conservé sur les clés internes et icône flottante.</Description>',
)
replace("Dusk/TravelRef.plugincompendium", '<Version>3.3.2</Version>', '<Version>3.3.2-FR-r4</Version>')

# --- Release notes ---------------------------------------------------------
p = ROOT / "Dusk/TravelRef/TR_FR_NOTES.txt"
text = p.read_text(encoding="utf-8")
if "Correctifs FR r4\n----------------\n" not in text:
    marker = "Correctifs FR r3\n----------------\n"
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
    p.write_text(text.replace(marker, block + marker, 1), encoding="utf-8")

print("TravelRef audit fixes v2 applied successfully.")
