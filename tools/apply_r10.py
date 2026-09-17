#!/usr/bin/env python3
from pathlib import Path

ROOT = Path('.')

def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding='utf-8-sig')
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {n}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')
    print('patched', path)

# Historical TR_Data transcription mistakes that Lua silently accepted.
data_fixes = {
    '["Andrath"] = { c=1500, t=161, l=-10, st=2500, t=14 },': '["Andrath"] = { c=15, t=161, l=-10, s=25, st=14 },',
    '["Herne"] = { c=1500, t=418, l=-10, st=2500, t=30 },': '["Herne"] = { c=15, t=418, l=-10, s=25, st=30 },',
    '["Mossward"] = { st=500, t=23, S0=true },': '["Mossward"] = { s=5, st=23, S0=true },',
    '["Caranost"] = { c=15, t=222, l=-10, st=25, t=35 },': '["Caranost"] = { c=15, t=222, l=-10, s=25, st=35 },',
    '["Herne"] = { c=15, t=380, l=-10, st=25, t=26 },': '["Herne"] = { c=15, t=380, l=-10, s=25, st=26 },',
    '["Scurloc Farm"] = { c=15, t=295, l=-10, st=25, t=21 },': '["Scurloc Farm"] = { c=15, t=295, l=-10, s=25, st=21 },',
    '["Lintrev"] = { c=1, t=242, s=450, st=21 },': '["Lintrev"] = { c=1, t=242, s=5, st=21 },',
    '["Lintrev"] = { c=1, t=48, s=450, st=25 },': '["Lintrev"] = { c=1, t=48, s=5, st=25 },',
    '["Herne"] = { c=15, t=412, l=-10, st=25, t=33 },': '["Herne"] = { c=15, t=412, l=-10, s=25, st=33 },',
    '["Lintrev"] = { c=1, t=175, s=450, st=30 },': '["Lintrev"] = { c=1, t=175, s=5, st=30 },',
    '["Lhan Garan"] = { c=1, t=175, s=5, st=330 },': '["Lhan Garan"] = { c=1, t=175, s=5, st=33 },',
    '["Lhan Garan"] = { c=1, t=323, st=5, t=33 },': '["Lhan Garan"] = { c=1, t=323, s=5, st=33 },',
    '["Ost Guruth"] = { c=15, t=128, l=-15, c=25, t=27 },': '["Ost Guruth"] = { c=15, t=128, l=-15, s=25, st=27 },',
    '["Galtrev"] = { c=25, st=158, l=-65, s=35, st=18 },': '["Galtrev"] = { c=25, t=158, l=-65, s=35, st=18 },',
    '["Calembel(KG)"] = { c=120, t=170, l=130, s=180, st=224 },': '["Calembel(KG)"] = { c=120, t=170, l=130, s=180, st=24 },',
    '["Ethring(KG)"] = { c=120, t=456, l=130, s=180, st24 },': '["Ethring(KG)"] = { c=120, t=456, l=130, s=180, st=24 },',
    '["Ingaruma"] = { l=-150, t=113, l=-150, s=192, st=16 },': '["Ingaruma"] = { l=-150, t=113, s=192, st=16 },',
    '["Hanamíku"] = { l=-150, t=113, l=-150, s=192, st=15 },': '["Hanamíku"] = { l=-150, t=113, s=192, st=15 },',
}
for old,new in data_fixes.items():
    replace_once('Dusk/TravelRef/TR_Data.lua', old, new)

replace_once('Dusk/TravelRef/TR_Data.lua', '''Areas = { }
for n,t in pairs(Locs) do
	if t.a then Areas[t.a] = t.z end
end''', '''-- Preserve every zone associated with a sub-area.  Several historical area
-- names legitimately occur in more than one zone; a single Areas[area]=zone
-- assignment depended on pairs() order and was therefore nondeterministic.
AreaZones = { }
for _,t in pairs(Locs) do
	if t.a then
		if not AreaZones[t.a] then AreaZones[t.a] = { } end
		AreaZones[t.a][t.z] = true
	end
end
-- Compatibility view for old code/addons: choose a deterministic zone while
-- AreaZones remains the authoritative many-to-many mapping.
Areas = { }
for area,zoneSet in pairs(AreaZones) do
	local zoneList = { }
	for zone in pairs(zoneSet) do table.insert(zoneList,zone) end
	table.sort(zoneList)
	Areas[area] = zoneList[1]
end''')

# Route rules: retain the historical generic 10% discount for known requirement
# codes (notably Q8) while keeping arbitrary unknown codes safe.
replace_once('Dusk/TravelRef/TR_RouteRules.lua', '''function TR_DiscountRate(code, req, discounts)
    req = type(req) == "table" and req or {}
    discounts = type(discounts) == "table" and discounts or {}

    local rate = 1
    if code and req[code] then rate = discounts[code] or 1 end
    if code == "R17" and req.R18 then rate = rate - 0.1 end
    if req.S2 then rate = rate * 0.8 end
    return rate
end''', '''function TR_DiscountRate(code, req, discounts, requirements)
    req = type(req) == "table" and req or {}
    discounts = type(discounts) == "table" and discounts or {}
    requirements = type(requirements) == "table" and requirements or {}

    local rate = 1
    if code and req[code] then
        if discounts[code] then rate = discounts[code]
        elseif requirements[code] then rate = 0.9 end
    end
    if code == "R17" and req.R18 then rate = rate - 0.1 end
    if req.S2 then rate = rate * 0.8 end
    return rate
end''')

# Main window/search/save robustness.
replace_once('Dusk/TravelRef/TR_Main.lua', 'if not TR_Opt then\n    TR_Opt = { SE=true }', 'if type(TR_Opt) ~= "table" then\n    TR_Opt = { SE=true }')
replace_once('Dusk/TravelRef/TR_Main.lua', 'local tdr = TR_DiscountRate(td, TR_req, TD_list)', 'local tdr = TR_DiscountRate(td, TR_req, TD_list, Reqs)')
replace_once('Dusk/TravelRef/TR_Main.lua', '''function TR_FrenchSort(a,b)
    local na, nb = TR_SearchNorm(a), TR_SearchNorm(b)
    if na == nb then return tostring(a) < tostring(b) end
    return na < nb
end''', '''function TR_FrenchSort(a,b)
    local na, nb = TR_SearchNorm(a), TR_SearchNorm(b)
    if na == nb then return tostring(a) < tostring(b) end
    return na < nb
end

local function TR_AreaZoneList(area)
    local list = {}
    local set = type(AreaZones) == "table" and AreaZones[area] or nil
    if type(set) == "table" then
        for zone in pairs(set) do table.insert(list,zone) end
    elseif type(Areas) == "table" and Areas[area] then
        table.insert(list,Areas[area])
    end
    table.sort(list,function(a,b) return TR_FrenchSort(TR_ZoneName(a),TR_ZoneName(b)) end)
    return list
end''')
replace_once('Dusk/TravelRef/TR_Main.lua', '''	if cmd=="tra" then
		if rawArgs~="" then
			local str=TR_SearchNorm(rawArgs)
			local zn
     		printh("Sous-zones correspondantes :")
			for area,zone in pairs(Areas) do
				local darea = TR_AreaName(area)
				if TR_SearchNorm(area):find(str,1,true) or TR_SearchNorm(darea):find(str,1,true) then
					print(darea.." dans "..TR_ZoneName(zone))
					if zn then zn = true
					else zn = zone end
				end
			end
			if not zn then print("(aucune trouvée)")
			elseif zn ~= true then
				TR_window.zoneMenu:SetText( TR_ZoneName(zn) )
			end
		else printe("Aucun nom de sous-zone.") end
		return
	end''', '''	if cmd=="tra" then
		if rawArgs~="" then
			local str=TR_SearchNorm(rawArgs)
			local matchedZones, matches = {}, 0
     		printh("Sous-zones correspondantes :")
			local source = type(AreaZones)=="table" and AreaZones or Areas
			for area in pairs(source) do
				local darea = TR_AreaName(area)
				if TR_SearchNorm(area):find(str,1,true) or TR_SearchNorm(darea):find(str,1,true) then
					for _,zone in ipairs(TR_AreaZoneList(area)) do
						print(darea.." dans "..TR_ZoneName(zone))
						matchedZones[zone] = true
						matches = matches + 1
					end
				end
			end
			if matches==0 then print("(aucune trouvée)")
			else
				local only,count
				for zone in pairs(matchedZones) do only,count = zone,(count or 0)+1 end
				if count==1 then TR_window.zoneMenu:SetText(TR_ZoneName(only)) end
			end
		else printe("Aucun nom de sous-zone.") end
		return
	end''')
replace_once('Dusk/TravelRef/TR_Main.lua', '''	if args=="areas" then
		printh("Sous-zones connues avec des écuries :")
		for area,zone in Sort(Areas, function(a,b) return TR_FrenchSort(TR_AreaName(a),TR_AreaName(b)) end) do
			print(TR_AreaName(area).." dans "..TR_ZoneName(zone))
		end
		return
	end''', '''	if args=="areas" then
		printh("Sous-zones connues avec des écuries :")
		local source = type(AreaZones)=="table" and AreaZones or Areas
		for area in Sort(source, function(a,b) return TR_FrenchSort(TR_AreaName(a),TR_AreaName(b)) end) do
			for _,zone in ipairs(TR_AreaZoneList(area)) do
				print(TR_AreaName(area).." dans "..TR_ZoneName(zone))
			end
		end
		return
	end''')
replace_once('Dusk/TravelRef/TR_Main.lua', '''	local areaArg = TR_AreaKey(rawArgs)
	if Areas[areaArg] then
		local z = Areas[areaArg]
		printh("Écuries connues dans "..TR_AreaName(areaArg).." (partie de "..TR_ZoneName(z)..") :")
		local Loc_list = {}
		for name,t in pairs(Locs) do
			if t.a==areaArg and t.d then table.insert(Loc_list,name) end
		end
		table.sort(Loc_list, function(a,b) return TR_FrenchSort(TR_LocName(a),TR_LocName(b)) end)
		for ix,name in ipairs(Loc_list) do
			local str = TR_LocName(name)
			if TR_req.NV[name] then str="<rgb=#E01000>"..str.."</rgb>" end
			print(str.." @ "..Locs[name].l)
		end
		return
	end''', '''	local areaArg = TR_AreaKey(rawArgs)
	local areaZones = TR_AreaZoneList(areaArg)
	if #areaZones>0 then
		printh("Écuries connues dans "..TR_AreaName(areaArg).." :")
		local Loc_list = {}
		for name,t in pairs(Locs) do
			if t.a==areaArg and t.d then table.insert(Loc_list,name) end
		end
		table.sort(Loc_list, function(a,b) return TR_FrenchSort(TR_LocName(a),TR_LocName(b)) end)
		for _,name in ipairs(Loc_list) do
			local str = TR_LocName(name)
			if TR_req.NV[name] then str="<rgb=#E01000>"..str.."</rgb>" end
			print(str.." @ "..Locs[name].l.." dans "..TR_ZoneName(Locs[name].z))
		end
		return
	end''')
replace_once('Dusk/TravelRef/TR_Main.lua', '''if TR_Opt and TR_Opt.auto then
	TR_window:SetPosition(TR_Opt.auto.x, TR_Opt.auto.y)
	TR_window:SetVisible( true )
end''', '''if TR_Opt and TR_Opt.auto then
	if type(TR_Opt.auto)=="table" and tonumber(TR_Opt.auto.x) and tonumber(TR_Opt.auto.y) then
		TR_window:SetPosition(TR_Opt.auto.x, TR_Opt.auto.y)
	end
	TR_window:SetVisible( true )
end''')
replace_once('Dusk/TravelRef/TR_Main.lua', '''    if TR_Launcher and TR_Launcher.SavePosition then TR_Launcher.SavePosition() end
    Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Server,"TravelRef_Opt",TR_Opt)''', '''    if TR_Launcher and TR_Launcher.SavePosition then TR_Launcher.SavePosition() end
    if TR_window and TR_window.secs then
        TR_req.secs = TR_window.secs:GetText()
        Dusk.TravelRef.Common.PluginDataSave(Character,"Travel_req",TR_req)
    end
    Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Server,"TravelRef_Opt",TR_Opt)''')
replace_once('Dusk/TravelRef/TR_Main.lua', 'if not TR_Opt.scale then TR_Opt.scale = 1 end', 'if type(TR_Opt.scale) ~= "number" then TR_Opt.scale = 1 end')

# Runtime/UI behavior.
replace_once('Dusk/TravelRef/TR_Window.lua', '''local function Action(tbl)
	local code = tbl.r==Race and tbl.rd or tbl.d
	return Turbine.UI.Lotro.Shortcut(Skill,"0x700"..code)
end''', '''local function Action(tbl)
	local code = tbl.r==Race and tbl.rd or tbl.d
	if not code then return nil end
	return Turbine.UI.Lotro.Shortcut(Skill,"0x700"..code)
end''')
replace_once('Dusk/TravelRef/TR_Window.lua', 'td = TR_DiscountRate(td, TR_req, TD_list)', 'td = TR_DiscountRate(td, TR_req, TD_list, Reqs)')
replace_once('Dusk/TravelRef/TR_Window.lua', 'if TR_req.house then\n\t\tlocal hn,ht,v = TR_req.house,TR_req.htime', 'if TR_req.house and House[TR_req.house] then\n\t\tlocal hn,ht,v = TR_req.house,tonumber(TR_req.htime) or 20')
replace_once('Dusk/TravelRef/TR_Window.lua', 'local ht = TR_req.dtime', 'local ht = tonumber(TR_req.dtime) or 20')
replace_once('Dusk/TravelRef/TR_Window.lua', 'if not TR_req[tb] then TR_req[tb] = {} end', 'if type(TR_req[tb]) ~= "table" then TR_req[tb] = {} end')
replace_once('Dusk/TravelRef/TR_Window.lua', '''		for name,tbl in pairs(skill) do
			if #name>2 then 
				local tl = tbl.tl
				if plevel>=tl or tbl.r==Race then -- can it be learned?
					table.insert(list,name) 
				end
			end
		end''', '''		for name,tbl in pairs(skill) do
			if #name>2 then
				local tl = tbl.tl
				local usable = tbl.d or (tbl.r==Race and tbl.rd)
				if usable and (plevel>=tl or tbl.r==Race) then
					table.insert(list,name)
				end
			end
		end''')
replace_once('Dusk/TravelRef/TR_Window.lua', 'local pos = TR_Opt.pos2 or\n\t\t\t{ x=Turbine.UI.Display.GetWidth()/3+10, y=self:GetHeight()/2 }', 'local pos = type(TR_Opt.pos2)=="table" and TR_Opt.pos2 or\n\t\t\t{ x=Turbine.UI.Display.GetWidth()/3+10, y=self:GetHeight()/2 }')
replace_once('Dusk/TravelRef/TR_Window.lua', 'local name,time,dtime,Skiff = HouseName(None), 20, TR_req.dtime or 20', 'local name,time,dtime,Skiff = HouseName(None), 20, tonumber(TR_req.dtime) or 20, TR_req.dock and true or false')
replace_once('Dusk/TravelRef/TR_Window.lua', '''		TR_RTwindow:SetVisible( false )
		TR_HTwindow:SetVisible( false )
	end''', '''		TR_RTwindow:SetVisible( false )
		TR_HTwindow:SetVisible( false )
		if TR_GTwindow then TR_GTwindow:SetVisible(false) end
		if TR_MTwindow then TR_MTwindow:SetVisible(false) end
		if TR_STwindow then TR_STwindow:SetVisible(false) end
		TR_req.secs = TR_window.secs:GetText()
		Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
	end''')

# Post-load migration and coordinate lookup.
replace_once('Dusk/TravelRef/TR_Robustness.lua', '''if type(TR_req) == "table" and TR_req.dock and not tonumber(TR_req.dtime) then
    TR_req.dtime = 20
    Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
end''', '''if type(TR_req) == "table" then
    local changed = false
    if TR_req.house and (type(House) ~= "table" or not House[TR_req.house]) then
        TR_req.house,TR_req.htime,TR_req.dock,TR_req.dtime = nil,nil,nil,nil
        changed = true
    elseif TR_req.house and not tonumber(TR_req.htime) then
        TR_req.htime = 20
        changed = true
    end
    if TR_req.dock and not tonumber(TR_req.dtime) then
        TR_req.dtime = 20
        changed = true
    end
    if changed then
        Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
    end
end''')
replace_once('Dusk/TravelRef/TR_Robustness.lua', 'elseif (flg or tbl.d) and (not r or tbl.r == r) then', 'elseif (not r) or ((flg or tbl.d) and tbl.r == r) then')

# Area localization should use the authoritative multi-zone area map.
replace_once('Dusk/TravelRef/TR_OfficialFR.lua', '''    if type(Areas) == "table" then
        TR_AreaFR = {}
        TR_AreaEN = {}
        local ambiguousArea = {}
        for area in pairs(Areas) do''', '''    if type(Areas) == "table" then
        TR_AreaFR = {}
        TR_AreaEN = {}
        local ambiguousArea = {}
        local AreaSource = type(AreaZones)=="table" and AreaZones or Areas
        for area in pairs(AreaSource) do''')

# Remaining visible common-library English.
replace_once('Dusk/TravelRef/Common/DropMenu.lua', 'print( "Selected "..selected )', 'print( "Sélection : "..selected )')
replace_once('Dusk/TravelRef/Common/ScrollMenu.lua', 'print( "Selected "..selected )', 'print( "Sélection : "..selected )')
replace_once('Dusk/TravelRef/Common/Help.lua', 'printh("Possible command arguments:")', 'printh("Arguments de commande possibles :")')
replace_once('Dusk/TravelRef/Common/Help.lua', 'printh("Possible commands:")', 'printh("Commandes possibles :")')
replace_once('Dusk/TravelRef/Common/Help.lua', 'printh("Possible \'/"..arg.."\' arguments:")', 'printh("Arguments possibles pour \'/"..arg.."\' :")')
replace_once('Dusk/TravelRef/Common/Help.lua', 'else print("Enter \'"..pre.." ?\' for arguments, \'"..pre.."?\' for commands") end', 'else print("Entre \'"..pre.." ?\' pour les arguments et \'"..pre.."?\' pour les commandes.") end')

# Manifest + notes.
replace_once('Dusk/TravelRef.plugin', '<Version>3.3.2-FR-r9</Version>', '<Version>3.3.2-FR-r10</Version>')
replace_once('Dusk/TravelRef.plugin', 'TravelRef 3.3.2 FR r9', 'TravelRef 3.3.2 FR r10')
notes = Path('Dusk/TravelRef/TR_FR_NOTES.txt')
with notes.open('a', encoding='utf-8', newline='\n') as f:
    f.write('''\n\nCorrectifs FR r10 :\n- Audit de release permanent : données, routage, recherches de coordonnées et source Lua.\n- Correction de 18 anomalies historiques de TR_Data (champs dupliqués, valeurs décalées et st24).\n- Restauration de la réduction générique 10 % pour les anciens codes connus comme Q8.\n- Correction de /trv ;loc : les coffres peuvent de nouveau être trouvés par coordonnées.\n- Sous-zones multi-régions gérées via AreaZones sans dépendre de l’ordre de pairs().\n- Compétences raciales Retour filtrées pour éviter une action inexistante.\n- Sauvegardes maison/temps et options anciennes davantage sécurisées.\n- Aide et messages génériques restants traduits en français.\n''')
print('patched notes')

# Release audit: duplicate area names are valid; AreaZones must represent all of them.
replace_once('tools/release_audit.lua', '''for area,zone_set in pairs(area_zones) do
  local n, names = 0, {}
  for zone in pairs(zone_set) do n=n+1; names[#names+1]=zone end
  if n > 1 then
    table.sort(names)
    err("ambiguous internal area name "..area.." belongs to zones: "..table.concat(names,", "))
  end
end''', '''check(type(AreaZones)=="table","AreaZones is not a table")
local multi_zone_areas = 0
for area,zone_set in pairs(area_zones) do
  local published = type(AreaZones)=="table" and AreaZones[area] or nil
  if type(published)~="table" then
    err("AreaZones missing area: "..area)
  else
    local n = 0
    for zone in pairs(zone_set) do
      n=n+1
      if not published[zone] then err("AreaZones missing mapping: "..area.." -> "..zone) end
    end
    for zone in pairs(published) do
      if not zone_set[zone] then err("AreaZones has stale mapping: "..area.." -> "..zone) end
    end
    if n>1 then multi_zone_areas=multi_zone_areas+1 end
    if Areas[area] and not zone_set[Areas[area]] then err("Areas compatibility mapping invalid: "..area) end
  end
end''')
replace_once('tools/release_audit.lua', 'print(string.format("SPECIAL DATA: %d legacy generic discounts, %d hidden-region locations", legacy_discounts, hidden_regions))', 'print(string.format("SPECIAL DATA: %d legacy generic discounts, %d hidden-region locations, %d multi-zone areas", legacy_discounts, hidden_regions, multi_zone_areas))')

# Route unit tests now distinguish known legacy requirements from arbitrary codes.
p = Path('tools/test_route_rules.lua')
text = p.read_text(encoding='utf-8')
text = text.replace('local discounts = { R23=0.75, R17=0.9 }', 'local discounts = { R23=0.75, R17=0.9 }\nlocal requirements = { R23=true, R17=true, Q8=true }')
text = text.replace('TR_DiscountRate("R23", {R23=true}, discounts)', 'TR_DiscountRate("R23", {R23=true}, discounts, requirements)')
text = text.replace('TR_DiscountRate("R23", {R23=true,S2=true}, discounts)', 'TR_DiscountRate("R23", {R23=true,S2=true}, discounts, requirements)')
text = text.replace('TR_DiscountRate("R17", {R17=true,R18=true}, discounts)', 'TR_DiscountRate("R17", {R17=true,R18=true}, discounts, requirements)')
text = text.replace('TR_DiscountRate("UNKNOWN", {UNKNOWN=true}, discounts)', 'TR_DiscountRate("UNKNOWN", {UNKNOWN=true}, discounts, requirements)')
if 'legacy known discount' not in text:
    text = text.replace('check(TR_DiscountRate("UNKNOWN", {UNKNOWN=true}, discounts, requirements) == 1, "unknown discount fallback")', 'check(approx(TR_DiscountRate("Q8", {Q8=true}, discounts, requirements), 0.9), "legacy known discount")\ncheck(TR_DiscountRate("UNKNOWN", {UNKNOWN=true}, discounts, requirements) == 1, "unknown discount fallback")')
p.write_text(text, encoding='utf-8', newline='\n')
print('patched tools/test_route_rules.lua')
