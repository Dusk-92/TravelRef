#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_exact(rel, old, new, expected=1):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8-sig")
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{rel}: expected {expected} occurrence(s), found {count}: {old!r}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def replace_regex(rel, pattern, repl, expected=1):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8-sig")
    text2, count = re.subn(pattern, repl, text, flags=re.S)
    if count != expected:
        raise SystemExit(f"{rel}: expected {expected} regex replacement(s), found {count}")
    path.write_text(text2, encoding="utf-8")


# TR_Main: finish the NV migration and locale-aware sorting in text commands.
main = "Dusk/TravelRef/TR_Main.lua"
replace_exact(
    main,
    "table.sort(Loc_list)",
    "table.sort(Loc_list, function(a,b) return TR_FrenchSort(TR_LocName(a),TR_LocName(b)) end)",
    expected=2,
)
replace_exact(
    main,
    "if TR_req[name] then str=\"<rgb=#E01000>\"..str..\"</rgb>\" end",
    "if TR_req.NV[name] then str=\"<rgb=#E01000>\"..str..\"</rgb>\" end",
    expected=2,
)
replace_exact(
    main,
    "table.sort(dest)",
    "table.sort(dest, function(a,b) return TR_FrenchSort(TR_LocName(a),TR_LocName(b)) end)",
)

coord_pattern = r'''    local y,x,d = args:match\(Coord\)\n    if y then\n.*?\n\t\treturn\n\tend\n\tDusk\.TravelRef\.Common\.Help\(help,args\)'''
coord_repl = '''    local y,x = args:match(Coord)
    if y then
        -- At command execution time TR_Robustness has replaced Loc_Find with
        -- the guarded implementation, so malformed rows are skipped safely.
        local d,ln = Loc_Find(nil, y, x, Locs)
        if not ln or not Locs[ln] then
            printe("Aucune écurie correspondant à ces coordonnées.")
            return
        end
        local t = Locs[ln]
        print("L’écurie la plus proche de "..args.." est "..d)
        TR_window.zoneMenu:SetText(TR_ZoneName(t.z))
        TR_window.locMenu:SetText(TR_LocName(ln))
        TR_window:SetVisible(true)
        return
    end
\tDusk.TravelRef.Common.Help(help,args)'''
replace_regex(main, coord_pattern, coord_repl)

# TR_Window: translate the last route diagnostic.
replace_exact(
    "Dusk/TravelRef/TR_Window.lua",
    'if not Locs[loc] then printe("Nul loc, "..loc) return end',
    'if not Locs[loc] then printe("Lieu de route introuvable : "..TR_LocName(loc)) return end',
)

# Official FR layer: reverse mappings for zones and areas must reject ambiguity
# exactly like the location reverse mapping already does.
official = "Dusk/TravelRef/TR_OfficialFR.lua"
replace_exact(
    official,
'''        TR_ZoneEN = {}
        for en,fr in pairs(TR_ZoneFR) do
            if TR_ZoneEN[fr] == nil then TR_ZoneEN[fr] = en end
        end''',
'''        TR_ZoneEN = {}
        local ambiguousZone = {}
        for en,fr in pairs(TR_ZoneFR) do
            local previous = TR_ZoneEN[fr]
            if previous == nil then
                TR_ZoneEN[fr] = en
            elseif previous ~= en then
                ambiguousZone[fr] = true
            end
        end
        for fr in pairs(ambiguousZone) do TR_ZoneEN[fr] = nil end''',
)
replace_exact(
    official,
'''        TR_AreaFR = {}
        TR_AreaEN = {}
        for area in pairs(Areas) do
            local key = OfficialNorm(area)
            local fr = CleanOfficial((key and OfficialArea[key]) or area)
            TR_AreaFR[area] = fr
            if TR_AreaEN[fr] == nil then TR_AreaEN[fr] = area end
        end''',
'''        TR_AreaFR = {}
        TR_AreaEN = {}
        local ambiguousArea = {}
        for area in pairs(Areas) do
            local key = OfficialNorm(area)
            local fr = CleanOfficial((key and OfficialArea[key]) or area)
            TR_AreaFR[area] = fr
            local previous = TR_AreaEN[fr]
            if previous == nil then
                TR_AreaEN[fr] = area
            elseif previous ~= area then
                ambiguousArea[fr] = true
            end
        end
        for fr in pairs(ambiguousArea) do TR_AreaEN[fr] = nil end''',
)

# Requirements generator: remove the last fuzzy faction match and make the
# audit terminology precise about current-data vs historical verified titles.
gen = "tools/generate_requirements_fr.py"
replace_exact(
    gen,
'    "Entwash Vale": "Men of the Entwash Vale",\n',
'    "Entwash Vale": "Men of the Entwash Vale",\n    "Men of Entwash Vale": "Men of the Entwash Vale",\n',
)
replace_exact(
    gen,
'''        "-- Requirement labels are sourced from official LOTRO EN/FR localization IDs.",
        "-- Reputation fallbacks combine an official localized standing with an official localized faction.",''',
'''        "-- Requirement labels use current official LOTRO EN/FR IDs where available.",
        "-- Verified historical French titles are explicit overrides for retired labels.",
        "-- Reputation fallbacks combine an official localized standing with an official localized faction.",''',
)
replace_exact(
    gen,
'''    report = [
        "TravelRef official French requirement audit",
        "===========================================",
        "",
    ]''',
'''    historical_count = sum("verified historical" in source for _, source in matches.values())
    fuzzy_count = sum("(fuzzy " in source for _, source in matches.values())
    current_count = len(matches) - historical_count

    report = [
        "TravelRef French requirement audit",
        "==================================",
        "",
    ]''',
)
replace_exact(
    gen,
'''        f"Requirements extracted: {len(reqs)}",
        f"Matched officially: {len(matches)}",
        f"Unmatched: {len(unresolved)}",''',
'''        f"Requirements extracted: {len(reqs)}",
        f"Matched/verified French: {len(matches)}",
        f"Current official-data matches: {current_count}",
        f"Verified historical overrides: {historical_count}",
        f"Fuzzy faction matches: {fuzzy_count}",
        f"Unmatched: {len(unresolved)}",''',
)

# Metadata/documentation: r8 records these audit fixes.
replace_exact(
    "Dusk/TravelRef.plugin",
    "<Version>3.3.2-FR-r7</Version>",
    "<Version>3.3.2-FR-r8</Version>",
)
replace_exact(
    "Dusk/TravelRef.plugin",
    "<Description>TravelRef 3.3.2 FR r7 : cohérence des écuries non visitées, coûts de routage corrigés, voyage maison fiabilisé et tri français.</Description>",
    "<Description>TravelRef 3.3.2 FR r8 : affichage non visité unifié, tris FR complets, coordonnées robustes et couverture FR vérifiée.</Description>",
)

notes = "Dusk/TravelRef/TR_FR_NOTES.txt"
replace_exact(
    notes,
'''Correctifs FR r7
----------------''',
'''Correctifs FR r8
----------------
- Les listes /tr <zone> et /tr <sous-zone> utilisent désormais TR_req.NV pour l’état non visité.
- Les listes texte de lieux et destinations sont triées sur leurs libellés français, sans modifier les clés internes.
- La recherche directe par coordonnées réutilise Loc_Find sécurisé et ignore proprement les lignes malformées.
- Les tables inverses FR -> clé interne des zones et sous-zones rejettent maintenant les collisions ambiguës.
- Le dernier diagnostic anglais du routeur a été francisé.
- La validation CI des prérequis est dynamique et contrôle l’absence des anciennes régressions NV/tri.
- Les 77 prérequis ont un libellé FR vérifié ; les anciens titres retirés des données courantes restent identifiés comme overrides historiques.
- L’ancien rapprochement flou « Men of Entwash Vale » est remplacé par un alias explicite vers la faction officielle.

Correctifs FR r7
----------------''',
)
replace_exact(
    notes,
"- Les anciens titres dont aucune correspondance sûre n’est disponible restent en anglais plutôt que d’être traduits au hasard.",
"- Les anciens titres absents des tables actuelles sont conservés via des correspondances françaises historiques vérifiées.",
)

print("r8 audit fixes applied")
