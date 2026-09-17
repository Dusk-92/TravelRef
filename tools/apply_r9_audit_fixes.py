#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8-sig")


def write(rel, text):
    (ROOT / rel).write_text(text, encoding="utf-8")


def replace_exact(rel, old, new, expected=1):
    text = read(rel)
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{rel}: expected {expected} occurrence(s), found {count}: {old!r}")
    write(rel, text.replace(old, new))


def replace_regex(rel, pattern, repl, expected=1):
    text = read(rel)
    text2, count = re.subn(pattern, repl, text, flags=re.S)
    if count != expected:
        raise SystemExit(f"{rel}: expected {expected} regex replacement(s), found {count}")
    write(rel, text2)


# Pure routing rules: executable in CI without the LOTRO Turbine runtime.
write("Dusk/TravelRef/TR_RouteRules.lua", '''-- TravelRef pure routing rules.
-- coding: utf-8 'ä
-- This module intentionally has no Turbine dependency so it can be unit-tested.

-- A requirement string before a comma applies to swift travel; codes after a
-- comma also gate the normal route. Examples:
--   R29,Q6 -> swift needs R29 + Q6; normal needs Q6
--   ,Q7    -> both swift and normal need Q7
--   R29    -> swift needs R29; normal has no extra requirement
function TR_RequirementCodesMet(code, req, normalOnly)
    if type(code) ~= "string" or code == "" then return true end
    req = type(req) == "table" and req or {}

    if normalOnly then
        local comma = string.find(code, ",", 1, true)
        if not comma then return true end
        code = string.sub(code, comma + 1)
    end

    for requirement in string.gmatch(code, "%u%d+") do
        if not req[requirement] then return false end
    end
    return true
end

-- Keep route calculation and destination display on exactly the same discount
-- rules, including the special R17/R18 stacking and the global S2 reduction.
function TR_DiscountRate(code, req, discounts)
    req = type(req) == "table" and req or {}
    discounts = type(discounts) == "table" and discounts or {}

    local rate = 1
    if code and req[code] then rate = discounts[code] or 1 end
    if code == "R17" and req.R18 then rate = rate - 0.1 end
    if req.S2 then rate = rate * 0.8 end
    return rate
end
''')

write("tools/test_route_rules.lua", '''dofile("Dusk/TravelRef/TR_RouteRules.lua")

local function check(value, message)
    if not value then error(message, 2) end
end

-- Mixed requirement: reputation is for swift, quest also gates normal travel.
check(TR_RequirementCodesMet("R29,Q6", {R29=true,Q6=true}, false), "swift R29,Q6 should pass with both")
check(not TR_RequirementCodesMet("R29,Q6", {Q6=true}, false), "swift R29,Q6 must require R29")
check(TR_RequirementCodesMet("R29,Q6", {Q6=true}, true), "normal R29,Q6 should require only Q6")
check(not TR_RequirementCodesMet("R29,Q6", {R29=true}, true), "normal R29,Q6 must require Q6")

-- Leading comma means a requirement shared by normal and swift travel.
check(TR_RequirementCodesMet(",Q7", {Q7=true}, true), "normal ,Q7 should pass with Q7")
check(not TR_RequirementCodesMet(",Q7", {}, true), "normal ,Q7 must require Q7")

-- No comma: no extra requirement on the normal route.
check(TR_RequirementCodesMet("R29", {}, true), "normal R29 should not require the swift reputation")
check(not TR_RequirementCodesMet("R29", {}, false), "swift R29 must require R29")

-- Discount behavior shared by display and route calculation.
local discounts = {R17=.9, R23=.75}
check(math.abs(TR_DiscountRate("R23", {R23=true}, discounts) - .75) < 0.000001, "R23 discount")
check(math.abs(TR_DiscountRate("R23", {R23=true,S2=true}, discounts) - .60) < 0.000001, "R23 + S2 discount")
check(math.abs(TR_DiscountRate("R17", {R17=true,R18=true}, discounts) - .80) < 0.000001, "R17 + R18 discount")
check(math.abs(TR_DiscountRate("UNKNOWN", {UNKNOWN=true}, discounts) - 1) < 0.000001, "unknown discount must be safe")

print("TravelRef route-rule tests OK")
''')

# Main: load the pure rules before the UI and use the shared discount helper.
main = "Dusk/TravelRef/TR_Main.lua"
replace_exact(
    main,
    'import "Dusk.TravelRef.TR_Data"\n\nlocal frOk',
    'import "Dusk.TravelRef.TR_Data"\nimport "Dusk.TravelRef.TR_RouteRules"\n\nlocal frOk',
)
replace_exact(
    main,
    'if not TR_req.NV then TR_req.NV = {} end',
    'if type(TR_req.NV) ~= "table" then TR_req.NV = {} end',
)
replace_exact(
    main,
    'local tdr = TR_req[td] and TD_list[td] or 1\n\tif td=="R17" and TR_req.R18 then tdr = tdr-0.1 end -- special case',
    'local tdr = TR_DiscountRate(td, TR_req, TD_list)',
)
replace_exact(
    main,
    '\tif TR_req.S2 then tdr = tdr*0.8 end -- Global 20% discount?\n',
    '',
)

# Window: route semantics, translated skill lists, immediate persistence, house UI.
window = "Dusk/TravelRef/TR_Window.lua"
replace_exact(
    window,
'''function Req(dv)
\tif not (TR_req.S0 or dv.S0 or NoReq) then return end
\tlocal code = dv.r
\tif not code or NoReq then return true end
\tfor s in string.gmatch(code,"%u%d+") do
\t\tif not TR_req[s] then return false end
\tend
\treturn true
end''',
'''function Req(dv)
\tif NoReq then return true end
\tif not (TR_req.S0 or dv.S0) then return end
\treturn TR_RequirementCodesMet(dv.r, TR_req, false)
end''',
)
replace_exact(
    window,
'''\t\telse
            local tdCode = td
            td = tdCode and TR_req[tdCode] and (TD_list[tdCode] or 1) or 1
            if tdCode=="R17" and TR_req.R18 then td = td-0.1 end
            if TR_req.S2 then td = td*0.8 end
        end''',
'''\t\telse
            td = TR_DiscountRate(td, TR_req, TD_list)
        end''',
)
replace_exact(
    window,
'''\t\t\t\telseif c and (not l or dv.l>0 or pl>=l) and
\t\t\t\t\t\tnot (dv.r and dv.r:sub(1,1)==',' and not Req(dv)) then''',
'''\t\t\t\telseif c and (not l or dv.l>0 or pl>=l) and
\t\t\t\t\t\t(NoReq or TR_RequirementCodesMet(dv.r, TR_req, true)) then''',
)
replace_exact(
    window,
'''\t\treq[code] = v or nil
\t\tprint(str..(tb and title.." "..code or Reqs[code]) )''',
'''\t\treq[code] = v or nil
\t\tDusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
\t\tprint(str..(tb and title.." "..TR_LocName(code) or Reqs[code]) )''',
)
replace_exact(
    window,
'''\t\ttable.sort(list, function(a, b)
\t\t\tlocal an = skill[a].n or a
\t\t\tlocal bn = skill[b].n or b
\t\t\treturn an<bn
\t\t\tend)''',
'''\t\ttable.sort(list, function(a, b)
\t\t\tlocal an = skill[a].n or a
\t\t\tlocal bn = skill[b].n or b
\t\t\treturn TR_FrenchSort(TR_LocName(an),TR_LocName(bn))
\t\t\tend)''',
)
replace_exact(
    window,
    "\t\tlocal text = ' '..(skill and code or TR_Req(n) or Reqs[n])",
    "\t\tlocal text = ' '..(skill and TR_LocName(code) or TR_Req(n) or Reqs[n])",
)
replace_exact(
    window,
    'if not TR_req.MS then TR_req.MS = {} end',
    'if type(TR_req.MS) ~= "table" then TR_req.MS = {} end',
)

# French-only presentation for house-travel choices while retaining English
# keys in saved data and the House action table.
replace_exact(
    window,
    'Ms_list = {"1","2","3","4","5","6","7","8","9","10","11"}\n',
'''Ms_list = {"1","2","3","4","5","6","7","8","9","10","11"}

local HouseDisplay = {
    [None] = "<aucune>",
    ["Personal"] = "Maison personnelle",
    ["Kinship"] = "Maison de confrérie",
    ["Premium"] = "Maison premium",
    ["Kinship Member's"] = "Maison d’un membre de confrérie",
}
local HouseReverse = {}
for key,label in pairs(HouseDisplay) do HouseReverse[label] = key end
local function HouseName(key) return HouseDisplay[key] or key end
local function HouseKey(label) return HouseReverse[label] or label end
local HouseMenuFR = { HouseName(None) }
local HouseRest = {}
for key in pairs(House) do table.insert(HouseRest, HouseName(key)) end
table.sort(HouseRest, TR_FrenchSort)
for _,label in ipairs(HouseRest) do table.insert(HouseMenuFR, label) end
''',
)
replace_exact(
    window,
'''\tlocal name,time,dtime,Skiff = None, 20, TR_req.dtime or 20
\tif TR_req.house then 
\t\tname = TR_req.house
\t\ttime = tostring(TR_req.htime)
\t\tself.Slot:SetShortcut(Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[name]))
\tend''',
'''\tlocal name,time,dtime,Skiff = HouseName(None), 20, TR_req.dtime or 20
\tif TR_req.house and House[TR_req.house] then
\t\tname = HouseName(TR_req.house)
\t\ttime = tostring(tonumber(TR_req.htime) or 20)
\t\tself.Slot:SetShortcut(Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[TR_req.house]))
\tend''',
)
replace_exact(
    window,
'''\tlocal action = function(args)
\t\tself.saveButton:SetEnabled( true )
\t\tlocal dest = Blank
\t\tif args~=None then
\t\t\tdest = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[args])
\t\tend
\t\tself.Slot:SetShortcut(dest)
\tend
\tself.houseMenu.Menu.Click = function() 
\t\tself.houseMenu:BuildMenu(house,action,nil,print)
\tend''',
'''\tlocal action = function(args)
\t\tself.saveButton:SetEnabled( true )
\t\tlocal dest = Blank
\t\tlocal key = HouseKey(args)
\t\tif key~=None and House[key] then
\t\t\tdest = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[key])
\t\tend
\t\tself.Slot:SetShortcut(dest)
\tend
\tself.houseMenu.Menu.Click = function()
\t\tself.houseMenu:BuildMenu(HouseMenuFR,action,nil,print)
\tend''',
)
replace_exact(
    window,
'''        name = self.houseMenu:GetText()
\t\tif name~=None then
\t\t\tlocal time = tonumber(self.time:GetText())
\t\t\tif not time or time<4 then printe("Temps invalide.") return end
\t\t\tlocal dtime = tonumber(self.dtime:GetText())
\t\t\tif not dtime or dtime<4 then printe("Temps d’accès au quai invalide.") return end
\t\t\tTR_req.house = name
\t\t\tTR_req.htime = time
\t\t\tTR_req.dock = Skiff or nil
\t\t\tTR_req.dtime = dtime
\t\telse TR_req.house = nil end''',
'''        name = HouseKey(self.houseMenu:GetText())
\t\tif name~=None then
\t\t\tlocal time = tonumber(self.time:GetText())
\t\t\tif not time or time<4 then printe("Temps invalide.") return end
\t\t\tlocal dtime = tonumber(self.dtime:GetText())
\t\t\tif not dtime or dtime<4 then printe("Temps d’accès au quai invalide.") return end
\t\t\tTR_req.house = name
\t\t\tTR_req.htime = time
\t\t\tTR_req.dock = Skiff or nil
\t\t\tTR_req.dtime = dtime
\t\telse
\t\t\tTR_req.house = nil
\t\t\tTR_req.htime = nil
\t\t\tTR_req.dock = nil
\t\t\tTR_req.dtime = nil
\t\t\tSkiff = false
\t\tend''',
)

# Metadata/documentation.
replace_exact(
    "Dusk/TravelRef.plugin",
    "<Version>3.3.2-FR-r8</Version>",
    "<Version>3.3.2-FR-r9</Version>",
)
replace_exact(
    "Dusk/TravelRef.plugin",
    "<Description>TravelRef 3.3.2 FR r8 : affichage non visité unifié, tris FR complets, coordonnées robustes et couverture FR vérifiée.</Description>",
    "<Description>TravelRef 3.3.2 FR r9 : prérequis de routage corrigés, fenêtres de voyage francisées et sauvegardes fiabilisées.</Description>",
)
replace_exact(
    "Dusk/TravelRef/TR_FR_NOTES.txt",
    "Correctifs FR r8\n----------------",
'''Correctifs FR r9
----------------
- Correction du routage des exigences mixtes comme R29,Q6 : le voyage normal exige désormais Q6, tandis que le voyage rapide exige bien R29 + Q6.
- Ajout de règles de routage pures testées automatiquement en Lua 5.1 pour les prérequis et réductions.
- Calcul des réductions partagé entre l’affichage des destinations et le routeur afin d’éviter toute divergence future.
- Les fenêtres Retour/Guide/Ralliement/Navigation trient et affichent désormais les destinations avec leurs noms français.
- Les cases des prérequis et compétences sont sauvegardées immédiatement au clic, même si la fenêtre est ensuite masquée avec Échap.
- Le menu Voyage maison affiche des libellés français tout en conservant les clés internes anglaises dans les sauvegardes.
- Choisir « <aucune> » pour la maison nettoie aussi les anciens temps et l’option de quai devenus inutiles.
- Les tables NV/MS corrompues ou d’un ancien type sont réinitialisées proprement.

Correctifs FR r8
----------------''',
)

print("r9 audit fixes applied")
