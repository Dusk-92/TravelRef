#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-shot, guarded patcher for the final TravelRef FR audit fixes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path: str, old: str, new: str, expected: int = 1) -> None:
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count == 0 and new in text:
        return
    if count != expected:
        raise RuntimeError(f"{path}: expected {expected}, got {count}: {old!r}")
    p.write_text(text.replace(old, new), encoding="utf-8")


# TR_Main: accent-insensitive FR/EN searches, translated diagnostics and no
# accidental globals in destination/area/unload paths.
patch(
    "Dusk/TravelRef/TR_Main.lua",
    'if type(TR_AreaKey) ~= "function" then function TR_AreaKey(name) return name end end\n\nfunction print(text)',
    'if type(TR_AreaKey) ~= "function" then function TR_AreaKey(name) return name end end\n\n'
    'local function TR_SearchNorm(value)\n'
    '    value = tostring(value or "")\n'
    '    if type(noAccent) == "function" then value = noAccent(value) end\n'
    '    return string.lower(value)\n'
    'end\n\n'
    'function print(text)',
)
patch("Dusk/TravelRef/TR_Main.lua", 'printe("no loc for "..t)', 'printe("Aucun lieu défini pour "..t)')
patch("Dusk/TravelRef/TR_Main.lua", 'printe("Bad Loc for "..name)', 'printe("Coordonnées invalides pour "..TR_LocName(name))')
patch("Dusk/TravelRef/TR_Main.lua", 'local str=rawArgs:lower()', 'local str=TR_SearchNorm(rawArgs)', 1)
patch(
    "Dusk/TravelRef/TR_Main.lua",
    'if area:lower():find(str,1,true) or darea:lower():find(str,1,true) then',
    'if TR_SearchNorm(area):find(str,1,true) or TR_SearchNorm(darea):find(str,1,true) then',
)
patch(
    "Dusk/TravelRef/TR_Main.lua",
    'if cmd=="trf" then\n\t\tif args~="" then\n\t\t\tlocal str=args:lower()',
    'if cmd=="trf" then\n\t\tif rawArgs~="" then\n\t\t\tlocal str=TR_SearchNorm(rawArgs)',
)
patch(
    "Dusk/TravelRef/TR_Main.lua",
    '\t\t\tfor name,loc in pairs(Locs) do\n\t\t\t\tif name:lower():find(str,1,true) then\n\t\t\t\t\tprint(TR_LocName(name).." dans "..TR_ZoneName(loc.z))',
    '\t\t\tfor name,loc in pairs(Locs) do\n\t\t\t\tlocal dname = TR_LocName(name)\n\t\t\t\tif TR_SearchNorm(name):find(str,1,true) or TR_SearchNorm(dname):find(str,1,true) then\n\t\t\t\t\tprint(dname.." dans "..TR_ZoneName(loc.z))',
)
patch("Dusk/TravelRef/TR_Main.lua", 'print(loc.n.." @ "..loc.l)', 'print(TR_LocName(loc.n).." @ "..loc.l)')
patch("Dusk/TravelRef/TR_Main.lua", '\t\tdest = { }', '\t\tlocal dest = { }')
patch("Dusk/TravelRef/TR_Main.lua", '\t\tz = Areas[areaArg]', '\t\tlocal z = Areas[areaArg]')
patch("Dusk/TravelRef/TR_Main.lua", '\tpname = player:GetName()', '\tlocal pname = player:GetName()')

# TR_Window: remove accidental globals.
patch("Dusk/TravelRef/TR_Window.lua", '\t\t\tdt = { [MRD] = R_Dest[MRD] }', '\t\t\tlocal dt = { [MRD] = R_Dest[MRD] }')
patch("Dusk/TravelRef/TR_Window.lua", '\t\t\tw = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..Miles[tonumber(ix)])', '\t\t\tlocal w = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..Miles[tonumber(ix)])')

# TR_OfficialFR: optional noAccent, but all data modules must load completely;
# also discover future TravelRef zones even if the old manual TR_ZoneFR table
# has not yet been updated.
patch(
    "Dusk/TravelRef/TR_OfficialFR.lua",
    'local function TR_OfficialSafeImport(moduleName)\n    local ok = pcall(import, moduleName)\n    return ok\nend',
    'local function TR_OfficialSafeImport(moduleName, required)\n'
    '    local ok, err = pcall(import, moduleName)\n'
    '    if not ok and required then\n'
    '        error("échec import "..moduleName.." : "..tostring(err))\n'
    '    end\n'
    '    return ok, err\n'
    'end',
)
patch("Dusk/TravelRef/TR_OfficialFR.lua", 'TR_OfficialSafeImport("Dusk.TravelRef.Common.noAccent")', 'TR_OfficialSafeImport("Dusk.TravelRef.Common.noAccent", false)')
for module in (
    "Dusk.TravelRef.TR_OfficialFR_Data1",
    "Dusk.TravelRef.TR_OfficialFR_Data2",
    "Dusk.TravelRef.TR_OfficialFR_Data3",
    "Dusk.TravelRef.TR_OfficialFR_Data4",
    "Dusk.TravelRef.TR_OfficialFR_Data5",
    "Dusk.TravelRef.TR_OfficialFR_Auto",
):
    patch(
        "Dusk/TravelRef/TR_OfficialFR.lua",
        f'TR_OfficialSafeImport("{module}")',
        f'TR_OfficialSafeImport("{module}", true)',
    )
patch(
    "Dusk/TravelRef/TR_OfficialFR.lua",
    '    if type(TR_ZoneFR) == "table" then\n        for en in pairs(TR_ZoneFR) do\n            local lookup = ZoneAliases[en] or en\n            local key = OfficialNorm(lookup)\n            local fr = key and OfficialZone[key] or nil\n            if fr then TR_ZoneFR[en] = fr end\n        end\n        TR_ZoneEN = {}\n        for en,fr in pairs(TR_ZoneFR) do TR_ZoneEN[fr] = en end\n    end',
    '    if type(TR_ZoneFR) == "table" then\n'
    '        local function applyZone(en)\n'
    '            if type(en) ~= "string" then return end\n'
    '            local lookup = ZoneAliases[en] or en\n'
    '            local key = OfficialNorm(lookup)\n'
    '            local fr = key and OfficialZone[key] or nil\n'
    '            if fr then TR_ZoneFR[en] = CleanOfficial(fr)\n'
    '            elseif TR_ZoneFR[en] == nil then TR_ZoneFR[en] = en end\n'
    '        end\n'
    '        for en in pairs(TR_ZoneFR) do applyZone(en) end\n'
    '        if type(zones) == "table" then\n'
    '            for _,en in ipairs(zones) do applyZone(en) end\n'
    '        end\n'
    '        if type(Zones) == "table" then\n'
    '            for en in pairs(Zones) do applyZone(en) end\n'
    '        end\n'
    '        TR_ZoneEN = {}\n'
    '        for en,fr in pairs(TR_ZoneFR) do\n'
    '            if TR_ZoneEN[fr] == nil then TR_ZoneEN[fr] = en end\n'
    '        end\n'
    '    end',
)

# Bump the tested FR revision and document the final hardening pass.
patch("Dusk/TravelRef.plugin", '<Version>3.3.2-FR-r4</Version>', '<Version>3.3.2-FR-r5</Version>')
patch(
    "Dusk/TravelRef.plugin",
    '<Description>TravelRef 3.3.2 FR r4 : interface française, noms officiels LOTRO des lieux/zones/sous-zones, routage conservé sur les clés internes et icône flottante.</Description>',
    '<Description>TravelRef 3.3.2 FR r5 : interface et recherches françaises, noms officiels LOTRO, routage conservé sur les clés internes et validation automatique.</Description>',
)

notes = ROOT / "Dusk/TravelRef/TR_FR_NOTES.txt"
text = notes.read_text(encoding="utf-8")
if "Correctifs FR r5\n----------------\n" not in text:
    marker = "Correctifs FR r4\n----------------\n"
    if marker not in text:
        raise RuntimeError("TR_FR_NOTES.txt: r4 marker missing")
    block = (
        "Correctifs FR r5\n"
        "----------------\n"
        "- Recherche /trf et /tra sur les libellés français, avec tolérance aux accents.\n"
        "- Les futures zones TravelRef sont ajoutées dynamiquement à la couche d’affichage FR.\n"
        "- Les imports de données FR obligatoires signalent précisément le module en erreur.\n"
        "- Suppression de plusieurs variables globales accidentelles (dt, w, dest, z, pname).\n"
        "- Affichage FR des noms de coffres et traduction des diagnostics internes.\n"
        "- Validation Lua 5.1 et contrôles de couverture prévus dans GitHub Actions.\n\n"
    )
    notes.write_text(text.replace(marker, block + marker, 1), encoding="utf-8")

print("Final TravelRef audit fixes applied.")
