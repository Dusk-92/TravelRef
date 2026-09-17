#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_exact(path, old, new, expected=1):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} occurrence(s), found {count}: {old!r}")
    p.write_text(text.replace(old, new), encoding="utf-8")

# --- TR_Main.lua -----------------------------------------------------------
main = "Dusk/TravelRef/TR_Main.lua"
replace_exact(
    main,
    'if not TR_req.NV then TR_req.NV = {} end',
    '''if not TR_req.NV then TR_req.NV = {} end
-- r7: migrate the historical top-level "not visited" flags into the single
-- NV table used by the UI and route finder.
local TR_nvMigrated = false
for name in pairs(Locs or {}) do
    if TR_req[name] ~= nil then
        if TR_req[name] then TR_req.NV[name] = true end
        TR_req[name] = nil
        TR_nvMigrated = true
    end
end
if TR_nvMigrated then
    Dusk.TravelRef.Common.PluginDataSave(Character,"Travel_req",TR_req)
end'''
)
replace_exact(main, 'if TR_req[name] then markname="<rgb=#E01000>"..markname.."</rgb>" end',
                    'if TR_req.NV[name] then markname="<rgb=#E01000>"..markname.."</rgb>" end')
replace_exact(main, 'for name,nv in pairs(TR_req) do', 'for name,nv in pairs(TR_req.NV) do')
replace_exact(main, 'TR_req[args] = not TR_req[args]', 'TR_req.NV[args] = not TR_req.NV[args]')
replace_exact(main, 'local str = TR_req[args] and "Non " or ""', 'local str = TR_req.NV[args] and "Non " or ""')
replace_exact(
    main,
    '''local function TR_SearchNorm(value)
    value = tostring(value or "")
    if type(noAccent) == "function" then value = noAccent(value) end
    return string.lower(value)
end''',
    '''local function TR_SearchNorm(value)
    value = tostring(value or "")
    if type(noAccent) == "function" then value = noAccent(value) end
    return string.lower(value)
end

-- Locale-friendly display sorting.  Internal keys stay untouched.
function TR_FrenchSort(a,b)
    local na, nb = TR_SearchNorm(a), TR_SearchNorm(b)
    if na == nb then return tostring(a) < tostring(b) end
    return na < nb
end'''
)
replace_exact(
    main,
    'for area,zone in Sort(Areas) do',
    'for area,zone in Sort(Areas, function(a,b) return TR_FrenchSort(TR_AreaName(a),TR_AreaName(b)) end) do'
)

# --- TR_Window.lua ---------------------------------------------------------
window = "Dusk/TravelRef/TR_Window.lua"
replace_exact(
    window,
    'else td = td and TR_req[td] and 0.9 or 1 end',
    '''else
            local tdCode = td
            td = tdCode and TR_req[tdCode] and (TD_list[tdCode] or 1) or 1
            if tdCode=="R17" and TR_req.R18 then td = td-0.1 end
            if TR_req.S2 then td = td*0.8 end
        end'''
)
replace_exact(window, 'table.sort(zlist)', 'table.sort(zlist, TR_FrenchSort)')
replace_exact(window, 'table.sort(Loc_list)', 'table.sort(Loc_list, TR_FrenchSort)')
replace_exact(window, 'table.sort(list)\n\t\t\tself.destMenu:BuildMenu', 'table.sort(list, TR_FrenchSort)\n\t\t\tself.destMenu:BuildMenu')
replace_exact(window, 'self.visit:SetChecked(TR_req[dest])', 'self.visit:SetChecked(TR_req.NV[dest] or false)')
replace_exact(window, 'local name,time,dtime,Skiff = None, 20, 20', 'local name,time,dtime,Skiff = None, 20, TR_req.dtime or 20')
replace_exact(window, 'local dtime = tonumber(self.time:GetText())', 'local dtime = tonumber(self.dtime:GetText())')
replace_exact(window, '\n\tl = 0\n\tfor ix,n in ipairs(list) do', '\n\tlocal l = 0\n\tfor ix,n in ipairs(list) do')
replace_exact(window, '\n\tbox = self:AddField(CheckBox, "Maître du quai"', '\n\tlocal box = self:AddField(CheckBox, "Maître du quai"')

# --- Manifest --------------------------------------------------------------
manifest = "Dusk/TravelRef.plugin"
replace_exact(manifest, '<Version>3.3.2-FR-r6</Version>', '<Version>3.3.2-FR-r7</Version>')
replace_exact(
    manifest,
    'TravelRef 3.3.2 FR r6 : interface et recherches françaises, noms officiels LOTRO, routage conservé sur les clés internes et robustesse renforcée.',
    'TravelRef 3.3.2 FR r7 : cohérence des écuries non visitées, coûts de routage corrigés, voyage maison fiabilisé et tri français.'
)

# --- Notes -----------------------------------------------------------------
notes = "Dusk/TravelRef/TR_FR_NOTES.txt"
replace_exact(
    notes,
    'Correctifs FR r5\n----------------',
    '''Correctifs FR r7
----------------
- Unification du statut « non visité » dans TR_req.NV, avec migration des anciennes sauvegardes.
- Correction du bouton/menu « Non visité » et de la commande /trv pour utiliser la même donnée.
- Calcul des réductions de coût du routeur aligné sur l’affichage des destinations (TD_list, R17/R18, S2).
- Correction du champ « Temps vers quai » : lecture de dtime et restauration de la valeur sauvegardée.
- Tri des listes de zones, lieux, destinations et sous-zones selon les libellés français normalisés.
- Suppression de deux nouvelles variables globales accidentelles dans les fenêtres.
- Validation continue renforcée après l’audit r6.

Correctifs FR r6
----------------
- Ajout d’un point d’entrée r6 et d’une couche de robustesse chargée après le plugin principal.
- Loc_Find/TR_Find ignorent proprement les données absentes ou malformées sans interrompre TravelRef.
- Normalisation de recherche complétée pour œ/Œ et æ/Æ.
- Les collisions de noms FR vers plusieurs clés internes ne sont plus résolues arbitrairement.
- La validation de couverture FR est devenue dynamique au lieu de dépendre de compteurs figés.

Correctifs FR r5
----------------'''
)

print("r7 audit fixes applied")
