-- Travel reference plugin by David Down
-- coding: utf-8 'ä
import "Turbine"
import "Turbine.Gameplay"
import "Dusk.TravelRef.Common"
import "Dusk.TravelRef.TR_Data"

local frOk, frErr = pcall(import, "Dusk.TravelRef.TR_OfficialFR")
if not frOk and Turbine and Turbine.Shell then
    Turbine.Shell.WriteLine("<rgb=#FF6040>TravelRef FR officiel non chargé : "..tostring(frErr).."</rgb>")
end
if type(TR_AreaName) ~= "function" then function TR_AreaName(name) return name end end
if type(TR_AreaKey) ~= "function" then function TR_AreaKey(name) return name end end

function print(text) Turbine.Shell.WriteLine("<rgb=#00FFFF>TR:</rgb> "..text) end
function printh(text) print("<rgb=#00FF00>"..text.."</rgb>") end
function printe(text) print("<rgb=#FF6040>Erreur : "..text.."</rgb>") end
function printf(fmt, ...) print(string.format(fmt, ...)) end

import "Dusk.TravelRef.Common.Help"
import "Dusk.TravelRef.Common.Sort"

local Coord = "^(%d+%.%d[NnSs]), ?(%d+%.%d[EeWw])$"
local RCoord = "^(%d) (%d+%.%d[NnSs]),(%d+%.%d[EeWw])$"
local Zloc = "^(.+): .+: (%d+%.%d[NS]), (%d+%.%d[EW])$"
xlink = "<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"
local S0 = ", <rgb=#E01000>Prérequis : abonné actuel ou ancien</rgb>"
local Color = {"880088","FF0000","FF8C00","FFFF00","FFFFFF","1E90FF","00CED1","009800","707070"}
local Character = Turbine.DataScope.Character
player = Turbine.Gameplay.LocalPlayer.GetInstance()
plevel = player:GetLevel()
Race = player:GetRace()
PC = player:GetClass()
TR_req = Dusk.TravelRef.Common.PluginDataLoad(Character,"Travel_req")
if type(TR_req) ~= "table" then TR_req = {S0=true} end
if not TR_req.NV then TR_req.NV = {} end
local TRv = "Travel Ref. "..Plugins["TravelRef"]:GetVersion()

TR_Opt = Dusk.TravelRef.Common.PluginDataLoad(Turbine.DataScope.Server,"TravelRef_Opt")
if not TR_Opt then
    TR_Opt = { SE=true }
	printh(TRv..", paramètres initialisés.")
else printh(TRv..", paramètres chargés.") end

function TR_Req( code,flag )
	local str = ""
	for s in string.gmatch(code,"%u%d+") do
		local c = string.sub(s,1,1)
		local txt = rType[c]..": "..Reqs[s]
		if flag and not TR_req[s] then
			str = str..", <rgb=#E01000>"..txt.."</rgb>"
		else str = str..", "..txt end
	end
	return str
end

import "Dusk.TravelRef.TR_Window"
import "Dusk.TravelRef.TR_Launcher"
Plugins.TravelRef.Open = function(sender,args)
	TR_window:SetVisible( true )
	TR_window:SetZOrder( 0 )
end

if TR_Opt and TR_Opt.auto then
	TR_window:SetPosition(TR_Opt.auto.x, TR_Opt.auto.y)
	TR_window:SetVisible( true )
end

local function distance(dy,dx) return math.sqrt(dy*dy+dx*dx) end

local function locV(str,neg)
    local nbr = tonumber(str:sub(1,-2))
    if neg:find(str:sub(-1)) then nbr = -nbr end
    return nbr
end

local function barter(name,s,lvl)
	local b,c = Barter[name],''
	if s=='L' then s = "Niveau="..lvl
	elseif s=='D' then s = "Prouesse"
	elseif b then
		local bn,l = "Troc : Intendant",b
		if type(b)=="table" then
			l = b.l
			if b.n then
				if not l then bn = b.n
				else bn = (s and 'Quête : ' or 'Troc : ')..b.n end
			end
			if b.id then
				c = ' '..string.format(xlink,b.id,b.c..' '..Coin[b.id])
			elseif b.c then 
				bn= 'Boutique : '..b.n
				c = ' '..b.c..'s'
			end
		end
		s = bn..(l and "@"..l or '')
	end
	return s and " ("..s..")"..c or ''
end

function TR_lvl( lvl,pl )
	if pl>=lvl then return ", Niv. min : "..lvl end
	return ", <rgb=#E01000>Niv. min : "..lvl.."</rgb>"
end

function TR_Time( secs )
	if not secs then return "" end
	local min = math.floor(secs/60)
	secs = secs - min*60
	return string.format(", Temps=%d:%02d",min,secs)
end

local function d2(n)
	return math.floor(n*100+.5)/100
end

function TR_Dest( name,d,pl,flag,td )
	local tdr = TR_req[td] and TD_list[td] or 1
	if td=="R17" and TR_req.R18 then tdr = tdr-0.1 end -- special case
	if not Locs[name] then
		printe("Entrée de lieu manquante : '"..TR_LocName(name).."'.")
		return
	end
	local n = Locs[name].n -- alternate name?
	local dname = TR_LocName(n or name)
	local markname = TR_LocName(name)
	if TR_req[name] then markname="<rgb=#E01000>"..markname.."</rgb>" end
	local str,l,c,t = dname, d.l, d.c, d.t
	if l and (l<0 or not d.s) then
		if l<0 then l = -l end
		if TR_Opt.Hal and pl<l then 
			if not Turbine.UI.Control.IsShiftKeyDown() then return end
		end
		str = str..TR_lvl(l,pl)
	end
	if TR_req.S2 then tdr = tdr*0.8 end -- Global 20% discount?
	local dr = d.r
	if dr and dr:find(",") then -- req for c
		local i = dr:find(",")
		str=str..TR_Req(dr:sub(i+1),flag)
--		dr = dr:sub(1,i-1)
	end
	if d.n then -- special named instant travel
		l = d.nl and '('..d.nl..')' or ""
		print(str.."(ST): "..TR_LocName(d.n)..l)
		return
	end
	if d.s then
		if d.c and pl<=Max_lvl then print(str..", Coût="..d2(c*tdr).."a"..TR_Time(t)) end
		str,c,t = markname.."(ST)", d.s, d.st
		if l then 
			local hal = TR_Opt.Hal and not Turbine.UI.Control.IsShiftKeyDown()
			if hal and pl<l then return end
			str=str..TR_lvl(l,pl) 
		end
		if dr then str=str..TR_Req(dr,flag) end
		if not TR_req.S0 and not d.S0 then str=str..S0 end
	end
	if c then print(str..", Coût="..d2(c*tdr).."a"..TR_Time(t)) end
	if d.mt then
		str=markname.."(MT)"
		if dr then str=str..TR_Req(dr,flag) end
		print(str..TR_Time(d.mt))
	end
end

function Loc_Find(r, y, x, locs, flg)
	local d1,y1,x1,ln = 999,locV(y,"Ss"), locV(x,"Ww"), ''
	local y2,x2,d,c,name,tbl
	for loc,t in pairs(locs) do
		if flg then name = t; tbl = Locs[t]
		else name = loc; tbl = t; end
		if not tbl then printe("no loc for "..t) end
		if (flg or tbl.d) and tbl.r==r or not r then
			local y0,x0 = tbl.l:match(Coord)
			if not y0 then printe("Bad Loc for "..name) return end
			y2,x2 = locV(y0,"Ss"), locV(x0,"Ww")
			d = distance(y1-y2,x1-x2)
			if d<d1 then d1 = d; ln = r and name or tbl.n; c = tbl.l end
		end
	end
	return string.format("%s @ %s (à %.1f unités).",TR_LocName(ln),c,d1), ln
end

function TR_Find( args, locs, flg )
	local reg,y,x = args:match(Zloc)
	if y then
		local r = Region[reg]
		if not r then print("Région inconnue : "..reg) return end
		local d,ln = Loc_Find(r, y, x, locs, flg)
		local w = flg and "de recruteur de mission " or ""
		print("L’écurie "..w.."la plus proche est "..d)
		TR_window.zoneMenu:SetText( TR_ZoneName(Locs[ln].z) )
		TR_window.locMenu:SetText( TR_LocName(ln) )
	else printe("Aucune donnée de lieu dans cette instance.") end
end

TR_Command = Turbine.ShellCommand()
function TR_Command:GetShortHelp() return Dusk.TravelRef.Common.Help(help,"??") end
function TR_Command:GetHelp() return Dusk.TravelRef.Common.Help(help,"help") end

function TR_Command:Execute( cmd,args,lvl,flag )
	if Dusk.TravelRef.Common.HelpCmd(cmd,args,help) then return end
	local rawArgs = args
	args = TR_LocKey(args)
	if cmd=="trl" then
		TR_Find( args, Locs )
		return
	end
	if cmd=="tra" then
		if rawArgs~="" then
			local str=rawArgs:lower()
			local zn
      		printh("Sous-zones correspondantes :")
			for area,zone in pairs(Areas) do
				local darea = TR_AreaName(area)
				if area:lower():find(str,1,true) or darea:lower():find(str,1,true) then
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
	end
	if cmd=="trc" then
		local r,y,x = args:match(RCoord)
		if r then r = tonumber(r) end
		if not r or r<1 or r>5 then printe("Région/position invalide.") return end
		local d = Loc_Find(r, y, x, Locs)
		print("Écurie la plus proche : "..d)
		return
	end
	if cmd=="trf" then
		if args~="" then
			local str=args:lower()
			local ln
      		printh("Lieux correspondants :")
			for name,loc in pairs(Locs) do
				if name:lower():find(str,1,true) then
					print(TR_LocName(name).." dans "..TR_ZoneName(loc.z))
					if ln then ln = true
					else ln = name end
				end
			end
			if not ln then print("(aucun trouvé)")
			elseif ln ~= true then
				TR_window.zoneMenu:SetText( TR_ZoneName(Locs[ln].z) )
				TR_window.locMenu:SetText( TR_LocName(ln) )
			end
		else printe("Aucun nom de lieu.") end
		return
	end
	if cmd=="trv" then
		if args=="" then
			printh("Écuries non visitées :")
			for name,nv in pairs(TR_req) do
				if nv and Locs[name] then
					print(TR_LocName(name).." dans "..TR_ZoneName(Locs[name].z))
				end
			end
			return
		end
		if Locs[args] then
			TR_req[args] = not TR_req[args]
			Dusk.TravelRef.Common.PluginDataSave(Character,"Travel_req",TR_req)
			local str = TR_req[args] and "Non " or ""
			print(str.."visité : "..TR_LocName(args))
			return
		end
		local reg,y,x = args:match(Zloc)
		if not reg then printe("Lieu inconnu") return end
		local locs = Vaults[reg]
		if not locs then printe("Aucun coffre trouvé.") return end
		local d = Loc_Find(nil, y, x, locs)
		print("Coffre le plus proche : "..d)
		return
	end
	if cmd=="trr" then
		if args=="" then
			printh("Écuries des recruteurs :")
			for ix,name in ipairs(R_Locs) do
				local loc = Locs[name]
				print(TR_LocName(name).." @ "..loc.l.." dans "..TR_ZoneName(loc.z))
			end
		else TR_Find( args, R_Locs, true ) end
		return
	end
	if args=="mr" then
		printh("Destinations des recruteurs de mission :")
		for name,dest in Sort(R_Dest) do
			local loc = Locs[name]
			print(TR_LocName(name).." dans "..TR_ZoneName(loc.z)..TR_Time(dest.st))
		end
		return
	end
	if args=="zones" then
		local cz,czt = Turbine.UI.Control.IsShiftKeyDown(),{}
		if cz then printh("Zones adaptées à l’XP :")
		else printh("Zones disposant d’écuries :") end
		for i,name in ipairs(zones) do
			local lvl = Zlvl[name]
			local str = tostring(lvl+7)
			if plevel<lvl then str = "<rgb=#FF6040>"..str.."</rgb>"
			elseif plevel<lvl+18 then 
				str = "<rgb=#00FF00>"..str.."</rgb>" 
				if cz then table.insert(czt,name) end
			end
			if not cz then print(TR_ZoneName(name).." ("..Zones[name]..") = "..str..'+') end
		end
		if cz then
			table.sort(czt, function(a,b) return Zlvl[a]<Zlvl[b] end )
			for i,name in ipairs(czt) do
				print(TR_ZoneName(name).." = "..(Zlvl[name]+7))
			end
		end
		return
	end
	if args=="areas" then
		printh("Sous-zones connues avec des écuries :")
		for area,zone in Sort(Areas) do
			print(TR_AreaName(area).." dans "..TR_ZoneName(zone))
		end
		return
	end
	if args=="rt" then
		printh("Destinations de Retour pouvant être apprises :")
		local nr = 0
		local rt = TR_req.RT
		for name,t in pairs(Return) do
			if type(t)=="table" then
				local n= t.n or name
				if t.t and not rt[n] and t.tl<=plevel and (t.id or (t.r and t.r==Race)) then
					local s= (t.r==Race and " (Trait)") or barter(name,t.j)
					local id= t.id or t.d or t.rd
					local skill = t.j and "Voyage" or "Retour"
					print(string.format(xlink,id,skill.." vers "..TR_LocName(n))..s)
					nr = nr+1
				end
			end
		end
		if not rt["Ost Guruth"] then print(OG); nr = nr+1 end
		if nr==0 then print("(Aucune)") end
		return
	end
	if args=="gms" then
    	local tbl
		if PC==162 then tbl = Guide
    	elseif PC==194 then tbl = Muster
    	elseif PC==216 then tbl = Sail
		else printe("Il faut être Chasseur, Sentinelle ou Marin.") return end
		local rq = TR_req[tbl.tb]
		printh("Destinations "..tbl.nm.." pouvant être apprises :")
		local nr = 0
		for name,t in pairs(tbl) do
			if type(t)=="table" then
				local n,s= t.n or name
				local known = rq and rq[n]
				local id = t.id
				if t.q then id=t.q; s='Q'
				elseif #id<5 then
					s = id
					id = t.d
				end
				if t.id and t.tl<=plevel and not known then
					nr = nr+1
					s = barter(name,s,t.tl)
					print(string.format(xlink,id,tbl.nm.." "..TR_LocName(n))..s)
				end
			end
		end
		if nr==0 then print("(Aucune)") end
		return
	end
	local tbl = Travel[args]
	if tbl then
		printh("Destinations "..tbl.nm.." :")
		for name,t in pairs(tbl) do
			if type(t)=="table" then
				local n,s= t.n or name
				local id = t.id
				if t.q then id=t.q; s='Q'
				elseif t.r then print(tbl.nm.." "..TR_LocName(n).." (Trait)")
				elseif t.k then print(OG)
				elseif #id<5 then
					s = id
					id = t.d
				end
				if t.id then
					if t.j then s = " (Prouesse)"
					else s = barter(name,s,t.tl) end
					print(string.format(xlink,id,tbl.nm.." "..TR_LocName(n))..s)
				end
			end
		end
		return
	end
    if args=="ms" then
    	local cnt,tb = 0, TR_req.MS
    	print("Réglages actuels des jalons :")
    	for ix,ms in ipairs(Ms_list) do
    		if tb[ms] then
    			cnt = cnt+1
    			print("#"..ms.." : retour vers "..TR_LocName(tb[ms]))
    		end
    	end
    	if cnt==0 then print("(Aucun défini)") end
    	return
    end
	if args=="vaults" then
        local zone = TR_ZoneKey(TR_window.zoneMenu:GetText())
		if zone=="" then printe("Aucune zone sélectionnée.") return end
		printh("Coffres connus dans "..TR_ZoneName(zone).." :")
		local n = 0
		for reg,t in pairs(Vaults) do
			for ix,loc in ipairs(t) do
				if loc.z==zone then
					print(loc.n.." @ "..loc.l)
					n = n+1
				end
			end
		end
		if n==0 then print("(Aucun)") end
		return
	end
	-- Test for missing destinations
	if args=="dest" then
		printh("Destinations non définies :")
		for name,l in pairs(Locs) do
			if l.d then
				for dest in pairs(l.d) do
					if not Locs[dest] then
						print( name.."->"..dest )
					end
				end
			end
		end
		return
	end
	-- Test for missing swift travel times
	if args=="st" then
		printh("Destinations sans temps de trajet :")
		for name,l in pairs(Locs) do
			if l.d and l.r==nil then
				for dest,t in pairs(l.d) do
					if t.s and not t.st then
						TR_Dest( name.."->"..dest,t,66,true )
					end
				end
			end
		end
		return
	end
	local zoneArg = TR_ZoneKey(args)
	if Zones[zoneArg] then
		args = zoneArg
		printh("Écuries connues dans "..TR_ZoneName(args).." :")
		local Loc_list = {}
		for name,t in pairs(Locs) do
			if t.z==args and t.d then table.insert(Loc_list,name) end
		end
		table.sort(Loc_list)
		for ix,name in ipairs(Loc_list) do
				local sz,str = "",TR_LocName(name)
				if TR_req[name] then str="<rgb=#E01000>"..str.."</rgb>" end
				local t = Locs[name]
				if t.a then sz = " dans "..TR_AreaName(t.a) end
				local ql = t.ql
				if ql then
					local ld,cs = (plevel-ql)/2+4, Color[9]
					for i,cc in ipairs(Color) do
						if ld<i then cs = Color[i] break end
					end
					sz = sz..", QL=<rgb=#"..cs..">"..ql.."</rgb>"
				end
				print(str.." @ "..t.l..sz)
		end
		return
	end
	local t = Locs[args]
	if t then
		if not t.d then
			local l= t.l and " @ "..t.l or ""
			print(TR_LocName(args).." est seulement une destination dans "..TR_ZoneName(t.z)..l)
			return
		end
		if not lvl then lvl = plevel end
		local z, td = TR_ZoneName(t.z), t.td 
		if t.r then
			if t.a then z = string.format("%s (%s)", TR_AreaName(t.a),z) end
			print(string.format("<rgb=#00FF00>%s @ %s dans %s - destinations :</rgb>",TR_LocName(args),t.l,z))
		elseif args==Hs then printh("Destinations de voyage depuis l’écurie de maison :")
		else printh("Destinations de voyage en bateau depuis la maison :") end
		dest = { }
		for name in pairs(t.d) do
			table.insert(dest,name)
		end
		if args:sub(-3)=="(R)" then
			for name in pairs(R_Dest) do
				table.insert(dest,name)
			end
		end
		table.sort(dest)
		for i,name in ipairs(dest) do
			local tbl = t.d[name] or R_Dest[name]
			TR_Dest( name,tbl,lvl,flag or false,td )
		end
		return
	end
	local areaArg = TR_AreaKey(rawArgs)
	if Areas[areaArg] then
		z = Areas[areaArg]
		printh("Écuries connues dans "..TR_AreaName(areaArg).." (partie de "..TR_ZoneName(z)..") :")
		local Loc_list = {}
		for name,t in pairs(Locs) do
			if t.a==areaArg and t.d then table.insert(Loc_list,name) end
		end
		table.sort(Loc_list)
		for ix,name in ipairs(Loc_list) do
			local str = TR_LocName(name)
			if TR_req[name] then str="<rgb=#E01000>"..str.."</rgb>" end
			print(str.." @ "..Locs[name].l)
		end
		return
	end
    local y,x,d = args:match(Coord)
    if y then
		local d1,y1,x1,ln = 999,locV(y,"Ss"), locV(x,"Ww")
		for loc,t in pairs(Locs) do
			if t.d then
				y,x = t.l:match(Coord)
				local y2,x2 = locV(y,"Ss"), locV(x,"Ww")
				d = distance(y1-y2,x1-x2)
				if d<d1 then d1 = d; ln = loc end
			end
		end
		d = string.format(" (à %.1f unités).",d1)
		local t = Locs[ln]
		print("L’écurie la plus proche de "..args.." est "..TR_LocName(ln).." @ "..t.l..d)
		TR_window.zoneMenu:SetText( TR_ZoneName(t.z) )
		TR_window.locMenu:SetText( TR_LocName(ln) )
		TR_window:SetVisible( true )
		return
	end
	Dusk.TravelRef.Common.Help(help,args)
end

Turbine.Shell.AddCommand( "tr;tra;trv;trl;trf;trr;trc;tr?",TR_Command )

Plugins.TravelRef.Unload = function(sender,args)
	pname = player:GetName()
	if pname:sub(1,1)=="~" then return end -- session play?
    -- Sauvegarde explicitement la position de l’icône avant les autres réglages.
    if TR_Launcher and TR_Launcher.SavePosition then TR_Launcher.SavePosition() end
    Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Server,"TravelRef_Opt",TR_Opt)
    print(TRv..", paramètres enregistrés.")
end

-- Options panel
import "Dusk.TravelRef.Common.Options"
if not TR_Opt.scale then TR_Opt.scale = 1 end
OP,YP = Dusk.TravelRef.Common.Options_Init(print,TR_Opt,TR_window,"TravelRef_Opt",TR_HTwindow)

local SE = Dusk.TravelRef.Common.Options_Box(OP,YP," Définir l’arrivée par défaut")
if TR_Opt.SE then SE:SetChecked(true) end
SE.CheckedChanged = function( sender, args )
	TR_Opt.SE = sender:IsChecked()
	print((TR_Opt.SE and "Activé" or "Désactivé").." : définir l’arrivée par défaut.")
end

local Hal = Dusk.TravelRef.Common.Options_Box(OP,YP+20," Masquer au-dessus du niveau")
if TR_Opt.Hal then Hal:SetChecked(true) end
Hal.CheckedChanged = function( sender, args )
	TR_Opt.Hal = sender:IsChecked()
	print((TR_Opt.Hal and "Activé" or "Désactivé").." : masquer au-dessus du niveau.")
end

-- Help text
help = {
	pre = "tr",
	arg = {
		gms = "Lister les compétences Guide/Ralliement/Bateau apprenables.",
		rt = "Lister les compétences de Retour apprenables.",
		mr = "Lister les destinations des recruteurs de mission.",
		ms = "Lister les réglages des jalons.",
		zones = "Lister les zones avec écuries.",
		["<area>"] = "Lister les écuries de <area>.",
		["<coordinates>"] = "Afficher l’écurie la plus proche et la distance.",
		["<name>"] = "Afficher les infos du lieu et ses destinations.",
		["<zone>"] = "Lister les écuries de <zone>.",
	},
	cmd = {
		["tra <name>"] = "Chercher une sous-zone correspondante.",
		trf = "Chercher un nom d’écurie correspondant.",
		["trl ;loc"] = "Trouver l’écurie la plus proche.",
		trr = "Lister les écuries des recruteurs de mission.",
		["trr ;loc"] = "Trouver l’écurie de recruteur la plus proche.",
		trv = {
			[" "] = "Lister les écuries marquées non visitées.",
			["<name>"] = "Basculer l’état visité/non visité.",
			[";loc"] = "Trouver le coffre le plus proche.",
		},
		trw = {
			[" "] = "Ouvrir la fenêtre Travel Ref.",
			ht = "Ouvrir la fenêtre Voyage maison.",
			gm = "Ouvrir la fenêtre Guide/Ralliement.",
			rt = "Ouvrir la fenêtre Retour.",
			tr = "Ouvrir la fenêtre des prérequis de voyage.",
			td = "Ouvrir la fenêtre des réductions de voyage.",
		},
	},
}
