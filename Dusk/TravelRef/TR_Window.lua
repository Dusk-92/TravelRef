-- Travel window handler

import "Turbine.UI.Lotro"
import "Dusk.TravelRef.Common"
import "Dusk.TravelRef.Common.DropMenu"
import "Dusk.TravelRef.Common.ScrollMenu"
import "Dusk.TravelRef.Common.ToolTip"

local labelFont = Turbine.UI.Lotro.Font.TrajanPro14
local foreColor = Turbine.UI.Color( 0.9, 0.9, 0 )
local backColor = Turbine.UI.Color( 0, 0, 0 )
local greyColor = Turbine.UI.Color( 0.4, 0.4, 0.4 )
local Red = Turbine.UI.Color( 1, 0, 0 )
local Green = Turbine.UI.Color( 0, 1, 0 )
local Alias = Turbine.UI.Lotro.ShortcutType.Alias
local Button = Turbine.UI.Lotro.Button
local CheckBox = Turbine.UI.Lotro.CheckBox
local DropMenu = Dusk.TravelRef.Common.DropMenu
local ScrollMenu = Dusk.TravelRef.Common.ScrollMenu
local Item = Turbine.UI.Lotro.ShortcutType.Item
local Label = Turbine.UI.Label
local Skill = Turbine.UI.Lotro.ShortcutType.Skill
local TextBox = Turbine.UI.Lotro.TextBox
local Left = Turbine.UI.ContentAlignment.MiddleLeft
local Center = Turbine.UI.ContentAlignment.MiddleCenter
local Right = Turbine.UI.ContentAlignment.MiddleRight
local Quickslot = Turbine.UI.Lotro.Quickslot
local Qsize = 36
local SetLoc, NoReq, SetEnd, SetFind, MRD, Blank, gmsw
Ms_list = {"1","2","3","4","5","6","7","8","9","10","11"}

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

function Req(dv)
	if NoReq then return true end
	if not (TR_req.S0 or dv.S0) then return end
	return TR_RequirementCodesMet(dv.r, TR_req, false)
end

local function Action(tbl)
	local code = tbl.r==Race and tbl.rd or tbl.d
	if not code then return nil end
	return Turbine.UI.Lotro.Shortcut(Skill,"0x700"..code)
end

local function Find_Loc(name,tbl,noprint)
	local loc = tbl[name]
	if loc then
		local aname = loc.n or name
		local act = loc.j and "Voyage vers" or tbl.nm
		if TR_req[tbl.tb] and TR_req[tbl.tb][aname] then
			if noprint then return true end
			print("Trouvé : "..act.." "..TR_LocName(aname))
     		TR_window.Slot:SetShortcut(Action(loc))
			return true
		end
	end
end

local function Find_Dest(loc,noprint)
	if Find_Loc(loc,Guide,noprint) then return true
	elseif Find_Loc(loc,Muster,noprint) then return true
	elseif Find_Loc(loc,Sail,noprint) then return true
	elseif Find_Loc(loc,Return,noprint) then return true end
	for ix,name in pairs(TR_req.MS) do
		if name==loc then
			if noprint then return true end
			print("Jalon trouvé vers "..TR_LocName(name))
			local w = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..Miles[tonumber(ix)])
			TR_window.Slot:SetShortcut(w)
			return true
		end
	end
end

local function Find_Route(Start,End,pl,ss,ht)
	local ix,loc,list,via = 0,'',{Start}, { [Start]={t=3,c=0,n=0,i=0} }
	while loc do
		ix = ix+1; loc = list[ix]
		if not loc then break end
    	if not Locs[loc] then printe("Lieu de route introuvable : "..TR_LocName(loc)) return end
		local v,d,td = via[loc], Locs[loc].d, Locs[loc].td
    	if not d then return end
		if MRD and loc:sub(-3)=="(R)" then 
		--	print(loc.."->"..MRD)
			td = 1
			local dt = { [MRD] = R_Dest[MRD] }
			for n,t in pairs(d) do dt[n] = t end
			d = dt
		else
            td = TR_DiscountRate(td, TR_req, TD_list, Reqs)
        end
		for dest,dv in pairs(d) do
			if not Locs[dest] then printe("Destination manquante="..TR_LocName(dest).." @ "..TR_LocName(loc))
			elseif Locs[dest].d and not TR_req.NV[dest] then
				local l,c,t,s = dv.l, dv.c
				if l and l<0 then l = -l end
				if dv.s and (not l or pl>=l) and Req(dv) then
					s,c,t = true, dv.s, dv.st or 20
				elseif c and (not l or dv.l>0 or pl>=l) and
						(NoReq or TR_RequirementCodesMet(dv.r, TR_req, true)) then
					t = dv.t or 60
				elseif dv.mt then
					c,t,s = 0,dv.mt,false
				end
				if t then
					t,c = v.t+t+5, v.c+c*td
					if not via[dest] then
						table.insert(list,dest)
						via[dest] = {t=t, c=c, n=v.n+1, s=s, p=loc, i=#list}
					elseif t+ss*c < via[dest].t+ss*via[dest].c then
						local vi = via[dest].i
						via[dest] = {t=t, c=c, n=v.n+1, s=s, p=loc, i=vi}
						if ix>vi then ix = vi-1 break end
					end
				end
			end
		end
	end
	local v = via[End]
	if not v then return end
	local V = {n=v.n, c=v.c, t=v.t}
	local str,p,s = TR_LocName(End), v.p
	if v.s==false then str = str.."(MT)"
	elseif v.s then str = str.."(ST)" end
	while p do
		v = via[p]
		s = v.s and "(ST)" or v.s==false and "(MT)" or ""
		if v.p or not ht then str = TR_LocName(p)..s.." -> "..str end
		p = v.p
	end
	V.s = str
  return V
end

-- Find a route between start and end locations
function TR_Route(End,pl,ss)
	local Start = SetLoc
	if Start==End then printe("Choisis une destination différente du départ.") return end
	if SetEnd then Start,End = End,Start end
	printh("Recherche d’un itinéraire entre "..TR_LocName(Start).." et "..TR_LocName(End).." :")
	local v = Find_Route(Start,End,pl,ss)
	if not v then printe("Aucun itinéraire utilisable trouvé.") return end
	print(string.format("Itinéraire en %d étapes, coût=%s argent%s",v.n,v.c,TR_Time(v.t)))
	print(v.s)
end

-- Check a Return/Guide/Muster/Sail starting point
function TR_RGM(tbl,skill,pl,ss,V)
  for name,rtt in pairs(skill) do
	if type(rtt)=="table" then
		local rtn = rtt.n or name
		local route = rtt.p or name
		if tbl[rtn] then
		  local v = Find_Route(route,SetLoc,pl,ss)
		  if v then
			local t = v.t+rtt.t+skill.it -- induction time
			if (not V) or t+ss*v.c <= V.t+ss*V.c then
				V = v
				V.s = skill.nm..' '..TR_LocName(rtn).." -> "..v.s
				V.t = t
				V.n = V.n+1
				V.a = Action(rtt)
			end
		  end
		end
	end
  end
  return V
end

-- Check Mission Recruiter locations
function TR_MR(Start,pl,ss)
	if pl<20 then return end
	local V
	for name,t in pairs(R_Dest) do
		local tbl = Locs[name]
	--	print(name..'@'..tbl.l.." in "..tbl.z)
		local v = Find_Route(name,SetLoc,pl,ss)
		if v then
			v.t = v.t + t.st+1
			if (not V) or v.t+ss*v.c < V.t+ss*V.c then
				V = v
				MRD = name
			end
		end
	end
	return V
end

-- Find best start location and route to end location
function TR_Start(Start,pl,ss)
	printh("Recherche du meilleur départ vers "..TR_LocName(SetLoc).." :")
	local V
	if Start and Start~=SetLoc then
		V = Find_Route(Start,SetLoc,pl,ss)
	end
	if not TR_window.skipMs:IsChecked() then
		if next(TR_req.MS) then
			for ix,name in pairs(TR_req.MS) do
				local v = Find_Route(name,SetLoc,pl,ss)
				if v then
					v.t = v.t + Locs[name].t+15 -- extra time for Ms
					if (not V) or v.t+ss*v.c < V.t+ss*V.c then
						V = v
						V.s = "Jalon vers "..TR_LocName(name).." -> "..v.s
						V.n = V.n+1
						V.a = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..Miles[tonumber(ix)])
					end
				end
			end
		else print("Attention : aucun jalon n’a été défini.") end
	end
	local tbl = TR_req.GT or TR_req.MT or TR_req.ST
	if tbl then
		local skill = TR_req.GT and Guide or TR_req.MT and Muster or Sail
    	V = TR_RGM(tbl,skill,pl,ss,V)
	end
	local rt = TR_req.RT
  	if rt and next(rt) then
    	V = TR_RGM(rt,Return,pl,ss,V)
	elseif plevel>30 then
		print("Attention : aucun lieu de Retour n’a été défini.")
	end
	if TR_req.house and House[TR_req.house] then
		local hn,ht,v = TR_req.house,tonumber(TR_req.htime) or 20
		local ha = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[hn])
		local hs = "Voyage vers maison "..TR_LocName(hn).." -> Écurie de maison(MT) -> "
--		print("type(.d)="..type(Locs[Hs].d))
		for name,dt in pairs(Locs[Hs].d) do
			if (not dt.l or pl>= dt.l) and Req(dt) and not TR_req.NV[name] then
				if name==SetLoc then
					v = {t=0, c=dt.s, n=0}
				else v = Find_Route(name,SetLoc,pl,ss,true) end
				if v  then
					v.t = v.t + 12 + ht + dt.st -- add time to get there
					if (not V) or v.t+ss*v.c < V.t+ss*V.c then
						V = v
						V.s = hs..TR_LocName(name)..((v.s and "(ST) -> "..v.s) or "(ST)")
						V.n = V.n+3
						V.a = ha
					end
				end
			end
		end
		if TR_req.dock then
			local hs = "Voyage vers maison "..TR_LocName(hn).." -> Bateau de maison(MT) -> "
			local ht = tonumber(TR_req.dtime) or 20
			for name,dt in pairs(Locs[Dm].d) do
				if (not dt.l or pl>= dt.l) and Req(dt) and not TR_req.NV[name] then
					if name==SetLoc then
						v = {t=0, c=dt.s, n=0}
					else v = Find_Route(name,SetLoc,pl,ss,true) end
					if v  then
						v.t = v.t + 12 + ht + dt.st -- add time to get there
						if (not V) or v.t+ss*v.c < V.t+ss*V.c then
							V = v
							V.s = hs..TR_LocName(name)..((v.s and "(ST) -> "..v.s) or "(ST)")
							V.n = V.n+3
							V.a = ha
						end
					end
				end
			end
		end
	end
	if not V then printe("Aucun itinéraire utilisable trouvé.") return end
	print(string.format("Itinéraire en %d étapes, coût=%s argent%s",V.n,V.c,TR_Time(V.t)))
	print(V.s)
	return V.a
end

TR_Window = class( Turbine.UI.Lotro.Window )

function TR_Window:AddField(control, text, pos, size)
	local field = control()
	field:SetParent( self )
	if text then field:SetText( text ) end
	field:SetPosition( pos.x,pos.y )
	field:SetSize( size.x,size.y )
	if control==Button or control==DropMenu or
		control==ScrollMenu or not text then return field end
	field:SetFont( labelFont )
	field:SetBackColor( backColor )
	field:SetForeColor( foreColor )
	field:SetTextAlignment( Center )
	return field
end

---- This is the main Travel Location window
function TR_Window:Constructor()
	Turbine.UI.Lotro.Window.Constructor( self )

	self:SetText( "Travel Ref. FR" )
	self:SetSize( 250,465 )
	-- Position the window near the top and to left of center of the screen.
	local pos = TR_Opt.pos1 or
				{ x=Turbine.UI.Display.GetWidth()/5, y=self:GetHeight()/2 }
	self:SetPosition( pos.x, pos.y )

	-- Fond noir pour éviter le halo / les lueurs bleutées du skin par défaut de LOTRO
	self.bg = Turbine.UI.Control()
	self.bg:SetParent( self )
	self.bg:SetPosition( 9, 36 )
	self.bg:SetSize( self:GetWidth() - 18, self:GetHeight() - 45 )
	self.bg:SetBackColor( Turbine.UI.Color( 1, 0, 0, 0 ) )
	self.bg:SetMouseVisible( false )

	self:AddField(Label, "Niveau:", {x=15,y=40}, {x=55,y=16} )
	self.level = self:AddField(TextBox, "", {x=60,y=40}, {x=30,y=15} )
	self.level:SetText(plevel)
	Dusk.TravelRef.Common.ToolTip(self.level,-5,-18,"Niveau maximal utilisé pour calculer l’itinéraire.",250)

	self:AddField(Label, "Sec/argent:", {x=100,y=40}, {x=85,y=16} )
	self.secs = self:AddField(TextBox, "10", {x=181,y=41}, {x=24,y=15} )
	Dusk.TravelRef.Common.ToolTip(self.secs,-5,-18,"Pondération temps / coût pour choisir l’itinéraire.",280)
	if TR_req.secs then self.secs:SetText(TR_req.secs) end

	-- Zone label and menu
	self:AddField(Label, "Zone:", {x=20,y=65}, {x=45,y=16} )
	self.zoneMenu = self:AddField(ScrollMenu, "", {x=90,y=63}, {x=145,y=20} )
	Dusk.TravelRef.Common.ToolTip(self.zoneMenu,2,-20,"Maj : afficher toutes les zones.",200)
	local action = function()
		self.locMenu:SetText( "" )
		self.visit:SetForeColor( greyColor )
		self.visit:SetEnabled(false)
		self.visit:SetChecked(false)
	end
	self.zoneMenu.MenuBox.Click = function() 
		local zlist,color = {},{}
		local all = self:IsShiftKeyDown()
		for i,name in ipairs(zones) do
			local dname = TR_ZoneName(name)
			if plevel>=Zlvl[name] then 
				if not all then table.insert(zlist,dname) end
			elseif all then color[dname] = Red end
		end
		if all then
			zlist = {}
			for i,name in ipairs(zones) do table.insert(zlist,TR_ZoneName(name)) end
		end
		table.sort(zlist, TR_FrenchSort)
		self.zoneMenu:BuildMenu(zlist,30,print,action,nil,color) 
	end

	-- Location label and menu
	self:AddField(Label, "Lieu:", {x=20,y=90}, {x=60,y=16} )
	self.locMenu = self:AddField(ScrollMenu, "", {x=90,y=88}, {x=145,y=20} )
	local action = function(args)
		self.visit:SetEnabled(false)
		local key = TR_LocKey(args)
		self.visit:SetChecked(TR_req.NV[key])
		self.visit:SetForeColor( foreColor )
		self.visit:SetEnabled(true)
	end
	self.locMenu.MenuBox.Click = function()
        local zone = TR_ZoneKey(self.zoneMenu:GetText())
		if zone~="" then
			local Loc_list,color = {},{}
			for name,t in pairs(Locs) do
				if t.z==zone and t.d then
					local dname = TR_LocName(name)
					table.insert(Loc_list,dname)
					if Find_Dest(name,true) then color[dname]=Green end
				end
			end
			table.sort(Loc_list, TR_FrenchSort)
			--self.locMenu:BuildMenu(Loc_list,action,nil,print)
			self.locMenu:BuildMenu(Loc_list,25,print,action,nil,color)
		else printe("Sélectionne une zone.") end
	end

	-- Milestone button and menu
	self.msButton = self:AddField(Button, "Définir le jalon", {x=15,y=113}, {x=170,y=20} )
	self.msButton.Click = function( sender,args )
        local loc,ms = TR_LocKey(self.locMenu:GetText()), self.msMenu:GetText()
        local str = " effacé."
		if loc ~= "" then
        	if not Locs[loc].t then printe("Aucun jalon défini pour ce lieu.") return end
        	local ml =  Locs[loc].ml
        	if ml and plevel<ml then printe("Jalon au-dessus du niveau du personnage.") return end
			str = " défini sur "..TR_LocName(loc)
        else loc = nil end
        TR_req.MS[ms] = loc
        print("Jalon #"..ms..str)
		Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
	end
	self:AddField(Label, "#", {x=185,y=113}, {x=15,y=20} )
	self.msMenu = self:AddField(ScrollMenu, "1", {x=197,y=112}, {x=40,y=20} )
	self.msMenu.MenuBox.Click = function() 
		self.msMenu:BuildMenu(Ms_list,11,print) 
	end

	-- Zones button
	self.zonesButton = self:AddField(Button, "Zones", {x=15,y=140}, {x=90,y=20} )
	Dusk.TravelRef.Common.ToolTip(self.zonesButton,2,-20,"Maj : zones adaptées à ton niveau.",210)
	self.zonesButton.Click = function( sender,args )
        TR_Command:Execute("tr","zones")
	end

	-- Locations button
	self.locationsButton = self:AddField(Button, "Lieux", {x=115,y=139}, {x=120,y=20} )
	self.locationsButton.Click = function( sender,args )
        local zone = TR_ZoneKey(self.zoneMenu:GetText())
		if zone=="" then printe("Sélectionne une zone.")
        else TR_Command:Execute("tr",zone) end
	end

	-- Areas button
	self.areasButton = self:AddField(Button, "Sous-zones", {x=15,y=165}, {x=80,y=20} )
	self.areasButton.Click = function( sender,args )
        TR_Command:Execute("tr","areas")
	end

	-- Destinations button
	self.destButton = self:AddField(Button, "Destinations", {x=105,y=165}, {x=130,y=20} )
	Dusk.TravelRef.Common.ToolTip(self.destButton,2,-20,"Maj : tout afficher.",150)
	self.destButton.Click = function( sender,args )
        local loc = TR_LocKey(self.locMenu:GetText())
		if loc~="" then
			local lvl = self.level:GetText()
			if lvl then lvl = tonumber(lvl) end
            if lvl and lvl>0 and lvl<=Max_lvl then
				TR_Command:Execute("tr",loc,lvl,true)
            else print("Erreur, niveau invalide : "..(lvl or "?")) end
        else print("Sélectionne un lieu.") end
	end

	-- Destinations label and menu
	self:AddField(Label, "Dest:", {x=25,y=195}, {x=45,y=16} )
	self.destMenu = self:AddField(ScrollMenu, "", {x=70,y=193}, {x=145,y=20} )
	local action = function(dest)
		dest = TR_LocKey(dest)
        local loc = TR_LocKey(self.locMenu:GetText())
		local tbl = Locs[loc].d[dest] or R_Dest[dest]
		TR_Dest( dest, tbl, plevel )
		if Locs[dest].n then dest = Locs[dest].n end
		self.zoneMenu:SetText( TR_ZoneName(Locs[dest].z) )
		self.locMenu:SetText( TR_LocName(dest) )
		self.visit:SetChecked(TR_req.NV[dest] or false)
		self.destMenu:SetText( '' )
	end
	self.destMenu.MenuBox.Click = function()
        local loc = TR_LocKey(self.locMenu:GetText())
		if loc~="" then
			local list,color = {},{}
			for name,t in pairs(Locs[loc].d) do
				if not Locs[name] then
					printe("Lieu manquant : "..TR_LocName(name))
				elseif Locs[name].d or Locs[name].n then
					local dname = TR_LocName(name)
					table.insert(list,dname)
					local l = t.l
					if l and l<0 then l=-l end
					if l and l>plevel then color[dname] = Red end
				end
			end
			if loc:sub(-3)=="(R)" then
				for name in pairs(R_Dest) do
					table.insert(list,TR_LocName(name))
				end
			end
			table.sort(list, TR_FrenchSort)
			self.destMenu:BuildMenu(list,15,print,action,nil,color)
		else print("Sélectionne un lieu.") end
	end

	-- Start/End button
	self.startButton = self:AddField(Button, "Définir départ", {x=15,y=220}, {x=105,y=20} )
	self.startButton.Click = function( sender,args )
        local loc = TR_LocKey(self.locMenu:GetText())
		if loc~="" then
			SetLoc = loc
			local w = SetEnd and "Arrivée" or "Départ"
			print(w.." défini sur "..TR_LocName(SetLoc))
			if SetEnd then
				MRD = nil
				if Find_Dest(loc) then return end
				TR_MR(nil,plevel,1) -- Find best MR dest
			end
			self.Slot:SetShortcut(Blank)
        else print("Sélectionne un lieu.") end
	end

	-- End check box
	local box = self:AddField(CheckBox, "", {x=122,y=222}, {x=25,y=16} )
	Dusk.TravelRef.Common.ToolTip(box,-9,-20,"Coché : le bouton définit l’arrivée au lieu du départ.",300)
	if TR_Opt and TR_Opt.SE then 
		SetEnd = true
		self.startButton:SetText( "Définir arrivée" )
		box:SetChecked(true)
	end
	box.CheckedChanged = function( sender,args )
		SetEnd = sender:IsChecked()
		self.startButton:SetText( SetEnd and "Définir arrivée" or "Définir départ" )
		print((SetEnd and "Activé : " or "Désactivé : ").."définir l’arrivée.")
	end

	-- Find Route button
	self.routeButton = self:AddField(Button, "Itinéraire", {x=145,y=220}, {x=90,y=20} )
	self.routeButton.Click = function( sender,args )
		local l = self.level:GetText()
		if l then l = tonumber(l) end
		local ss = self.secs:GetText()
		if ss then ss = tonumber(ss) end
        local loc = TR_LocKey(self.locMenu:GetText())
		if not SetLoc then print("Définis d’abord un départ ou une arrivée.")
		elseif loc=="" then print("Sélectionne le lieu cible.")
		elseif TR_req.NV[loc] then printe(TR_LocName(loc).." n’a pas encore été visité.")
		elseif not l or l<1 or l>Max_lvl then printe("Niveau invalide : "..(l or "?"))
		elseif not ss or ss<0 or ss>99 then printe("Valeur secondes invalide.")
        else TR_Route(loc,l,ss) end
	end

	-- No Requirements check box
	local box = self:AddField(CheckBox, "Sans préreq.", {x=25,y=250}, {x=90,y=16} )
	Dusk.TravelRef.Common.ToolTip(box,-2,-20,"Ignorer les prérequis de voyage.",210)
	box.CheckedChanged = function( sender,args )
		NoReq = sender:IsChecked()
		print((NoReq and "Activé" or "Désactivé").." : ignorer les prérequis.")
	end

	-- Not Visit check box
	self.visit = self:AddField(CheckBox, "Non visité", {x=125,y=250}, {x=95,y=16} )
	self.visit:SetForeColor( greyColor )
	self.visit:SetEnabled(false)
	Dusk.TravelRef.Common.ToolTip(self.visit,-9,-20,"Marquer/démarquer cette écurie comme visitée.",280)
	self.visit.CheckedChanged = function( sender,args )
        local loc = TR_LocKey(self.locMenu:GetText())
		TR_req.NV[loc] = sender:IsChecked() or nil
		Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
		if sender:IsEnabled() then
			print((sender:IsChecked() and "Marqué non visité : " or "Marqué visité : ")..TR_LocName(loc))
		end
	end

	-- Find Nearest button
	self.nearestButton = self:AddField(Button, "Écurie la plus proche", {x=15,y=275}, {x=150,y=20} )
	local slot = Turbine.UI.Lotro.Quickslot()
	slot:SetParent( self.nearestButton )
    slot:SetPosition( 2,2 )
    slot:SetSize( 99, 15 )
    slot:SetShortcut(Turbine.UI.Lotro.Shortcut( Alias, "/trl ;loc" ))
    slot:SetAllowDrop( false )

	-- Find check box
	local box = self:AddField(CheckBox, "Recr.", {x=175,y=277}, {x=55,y=16} )
	Dusk.TravelRef.Common.ToolTip(box,-9,-20,"Chercher les écuries des recruteurs de mission.",280)
	box.CheckedChanged = function( sender,args )
		SetFind = sender:IsChecked()
		print((SetFind and "Activé" or "Désactivé").." : recherche des recruteurs")
		slot:SetShortcut(Turbine.UI.Lotro.Shortcut( Alias, SetFind and "/trr ;loc" or "/trl ;loc" ))
	end

	-- Find Best Start button
	self.findButton = self:AddField(Button, "Meilleur départ", {x=40,y=305}, {x=120,y=20} )
	self.findButton.Click = function( sender,args )
		local l = self.level:GetText()
		if l then l = tonumber(l) end
		local ss = self.secs:GetText()
		if ss then ss = tonumber(ss) end
        local loc = TR_LocKey(self.locMenu:GetText())
		if not l or l<1 or l>Max_lvl then printe("Niveau invalide : "..(l or "?"))
		elseif not ss or ss<0 or ss>99 then printe("Valeur secondes invalide.")
		elseif TR_req.NV[loc] then printe(TR_LocName(loc).." n’a pas encore été visité.")
		elseif SetLoc and SetEnd then
			self.Slot:SetShortcut(TR_Start(loc,l,ss))
		else print("Définis d’abord une arrivée.") end
	end

	-- Create a Quickslot
	self.Slot = self:AddField(Quickslot, nil, {x=175,y=305}, {x=Qsize,y=Qsize} )
	self.Slot:SetBackColor( Turbine.UI.Color( 0.2, 0.2, 0.2 ) )
	Blank = self.Slot:GetShortcut()

	-- Skip Milestones check box
	self.skipMs = self:AddField(CheckBox, "Ignorer les jalons", {x=40,y=330}, {x=135,y=16} )
	Dusk.TravelRef.Common.ToolTip(self.skipMs,-2,-20,"Ne pas utiliser les jalons disponibles.",230)
	self.skipMs.CheckedChanged = function( sender,args )
		print(sender:IsChecked() and "Jalons ignorés." or "Jalons utilisés.")
	end

	-- Requirements button
	self.requirementsButton = self:AddField(Button, "Prérequis", {x=25,y=355}, {x=105,y=20} )
	self.requirementsButton.Click = function( sender,args )
        TRW_Command:Execute("trw","tr")
	end

	-- Discounts button
	self.discButton = self:AddField(Button, "Réductions", {x=135,y=355}, {x=85,y=20} )
	self.discButton.Click = function( sender,args )
        TRW_Command:Execute("trw","td")
	end

	-- Return to button
	self.returnButton = self:AddField(Button, "Retour", {x=15,y=380}, {x=70,y=20} )
	Dusk.TravelRef.Common.ToolTip(self.returnButton,2,-20,"Maj : compétences pouvant être apprises.",250)
	self.returnButton.Click = function( sender,args )
		if sender:IsShiftKeyDown() then
			TR_Command:Execute("tr","rt")
		else TRW_Command:Execute("trw","rt") end
	end

	-- Guide/Muster/Sail button
	self.gmsButton = self:AddField(Button, "Guide/Ralliement/Bateau", {x=90,y=380}, {x=145,y=20} )
	Dusk.TravelRef.Common.ToolTip(self.gmsButton,-2,-20,"Maj : compétences pouvant être apprises.",250)
	self.gmsButton.Click = function( sender,args )
		if sender:IsShiftKeyDown() then
			TR_Command:Execute("tr","gms")
		else TRW_Command:Execute("trw","gms") end
	end

	-- Find Nearest vault button
	self.findvButton = self:AddField(Button, "Coffre le plus proche", {x=15,y=405}, {x=150,y=20} )
	local slot = Turbine.UI.Lotro.Quickslot()
	slot:SetParent( self.findvButton )
    slot:SetPosition( 2,2 )
    slot:SetSize( 99, 15 )
    slot:SetShortcut(Turbine.UI.Lotro.Shortcut( Alias, "/trv ;loc" ))
    slot:SetAllowDrop( false )

	-- Find vaults in zone
	self.vaultButton = self:AddField(Button, "Coffres", {x=170,y=405}, {x=65,y=20} )
	local slot = Turbine.UI.Lotro.Quickslot()
	slot:SetParent( self.vaultButton )
    slot:SetPosition( 2,2 )
    slot:SetSize( 99, 15 )
    slot:SetShortcut(Turbine.UI.Lotro.Shortcut( Alias, "/tr vaults" ))
    slot:SetAllowDrop( false )

	-- Set House Travel button
	self.htButton = self:AddField(Button, "Voyage maison", {x=55,y=430}, {x=140,y=20} )
	self.htButton.Click = function( sender,args )
        TRW_Command:Execute("trw","ht")
	end

end

TR_window = TR_Window()
TR_RWindow = class( Turbine.UI.Lotro.Window )

-- code=req/dest, line=vpos, title=r/g/m, tb=req table, tl=level
function TR_RWindow:AddBox(code,line,col,title,tb,text)
	local box = Turbine.UI.Lotro.CheckBox()
	local req = tb and TR_req[tb] or TR_req
	local width = self:GetWidth()-50
	box:SetParent( self )
	local x = 30
	if col==2 then x = 50+width end
	box:SetPosition( x,20+20*line )
	box:SetSize( width,20 )
	box:SetBackColor( backColor )
	box:SetTextAlignment( Left )
	box:SetForeColor( foreColor )
	box:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
	box:SetText( text )
	box.code = code
	if req[code] then box:SetChecked(true) end
	box.CheckedChanged = function( sender,args )
		local v = sender:IsChecked()
		local str = v and "Activé : " or "Désactivé : "
		req[code] = v or nil
		Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
		print(str..(tb and title.." "..TR_LocName(code) or Reqs[code]) )
	end
	return box
end

local function code_sort(a,b)
	local a1,b1 = string.sub(a,1,1), string.sub(b,1,1)
	if a1==b1 then return Reqs[a]<Reqs[b]
	else return a1<b1 end
end

function TR_RWindow:Constructor(list,width,title)
	Turbine.UI.Lotro.Window.Constructor( self )
	local col,skill,tb = 1
	if not title then -- return/guide/muster/sail?
		skill = list
		tb = skill.tb
		if type(TR_req[tb]) ~= "table" then TR_req[tb] = {} end
		list = {}
		for name,tbl in pairs(skill) do
			if #name>2 then
				local tl = tbl.tl
				local usable = tbl.d or (tbl.r==Race and tbl.rd)
				if usable and (plevel>=tl or tbl.r==Race) then
					table.insert(list,name)
				end
			end
		end
		if #list==0 then gmsw = false; return end
		table.sort(list, function(a, b)
			local an = skill[a].n or a
			local bn = skill[b].n or b
			return TR_FrenchSort(TR_LocName(an),TR_LocName(bn))
			end)
		title = skill.nm
	end
	local rows = #list
	if skill and rows>34 then rows = math.floor((rows+1)/2) end

	self:SetSize( width,60+20*rows )
	-- Position the window near the top and to left of center of the screen.
	local pos = { x=Turbine.UI.Display.GetWidth()/3+10, y=self:GetHeight()/3 }
	self:SetPosition( pos.x, pos.y )
	self:SetText( title )

	-- Create a checkbox and add it to the window.
	local l = 0
	for ix,n in ipairs(list) do
		local tbl = skill and skill[n]
		local code = tbl and tbl.n or n
		local text = ' '..(skill and TR_LocName(code) or TR_Req(n) or Reqs[n])
		l = l+1
		if l==rows+1 then col,l = 2, 1 end
		self:AddBox(code,l,col,title,tb,text)
	end
	if col==2 then width = width*1.85 end
 	self:SetSize( width,60+20*rows )
end

function TR_RWindow:Closed()
	TR_req.secs = TR_window.secs:GetText()
	Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
	print("Paramètres de voyage enregistrés.")
end

-- Home Travel settings
TR_HTWindow = class( Turbine.UI.Lotro.Window )

function TR_HTWindow:AddField(control, text, pos, size)
	local field = control()
	field:SetParent( self )
	if text then field:SetText( text ) end
	field:SetPosition( pos.x,pos.y )
	field:SetSize( size.x,size.y )
	if control==Button or control==DropMenu or not text then return field end
	field:SetFont( labelFont )
	field:SetBackColor( backColor )
	field:SetForeColor( foreColor )
	field:SetTextAlignment( Center )
	return field
end


function TR_HTWindow:Constructor()
	Turbine.UI.Lotro.Window.Constructor( self )

	self:SetText( "Voyage maison" )
	self:SetSize( 250,275 )
	-- Position the window near the top and to left of center of the screen.
	local pos = type(TR_Opt.pos2)=="table" and TR_Opt.pos2 or
			{ x=Turbine.UI.Display.GetWidth()/3+10, y=self:GetHeight()/2 }
	self:SetPosition( pos.x, pos.y )
	if TR_Opt.scale and self.SetScale then self:SetScale(TR_Opt.scale) end

	-- Create a Quickslot
	self:AddField(Label, "Action:", {x=45,y=150}, {x=55,y=16} )
	self.Slot = self:AddField(Quickslot, nil, {x=110,y=140}, {x=Qsize,y=Qsize} )
	self.Slot:SetBackColor( Turbine.UI.Color( 0.2, 0.2, 0.2 ) )

	-- Home label and menu
	self:AddField(Label, "Choisis la meilleure écurie.", {x=25,y=35}, {x=200,y=16} )
	self:AddField(Label, "Maison:", {x=15,y=55}, {x=55,y=16} )
	local name,time,dtime,Skiff = HouseName(None), 20, tonumber(TR_req.dtime) or 20, TR_req.dock and true or false
	if TR_req.house and House[TR_req.house] then
		name = HouseName(TR_req.house)
		time = tostring(tonumber(TR_req.htime) or 20)
		self.Slot:SetShortcut(Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[TR_req.house]))
	end
	self.houseMenu = self:AddField(DropMenu, name, {x=70,y=53}, {x=150,y=20} )
	local action = function(args)
		self.saveButton:SetEnabled( true )
		local dest = Blank
		local key = HouseKey(args)
		if key~=None and House[key] then
			dest = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..House[key])
		end
		self.Slot:SetShortcut(dest)
	end
	self.houseMenu.Menu.Click = function()
		self.houseMenu:BuildMenu(HouseMenuFR,action,nil,print)
	end

	self:AddField(Label, "Temps vers écurie:", {x=20,y=84}, {x=125,y=16} )
	self.time = self:AddField(TextBox, time, {x=147,y=83}, {x=30,y=17} )

	-- Save button
	self.saveButton = self:AddField(Button, "Enregistrer", {x=20,y=110}, {x=100,y=20} )
	self.saveButton:SetEnabled( false )
	self.time.TextChanged = function()
		self.saveButton:SetEnabled( true )
	end
	self.saveButton.Click = function( sender,args )
		local name = HouseKey(self.houseMenu:GetText())
		if name~=None then
			local time = tonumber(self.time:GetText())
			if not time or time<4 then printe("Temps invalide.") return end
			local dtime = tonumber(self.dtime:GetText())
			if not dtime or dtime<4 then printe("Temps d’accès au quai invalide.") return end
			TR_req.house = name
			TR_req.htime = time
			TR_req.dock = Skiff or nil
			TR_req.dtime = dtime
		else
			TR_req.house = nil
			TR_req.htime = nil
			TR_req.dock = nil
			TR_req.dtime = nil
			Skiff = false
		end
		Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
		self.saveButton:SetEnabled( false )
		print("Paramètres de voyage enregistrés.")
	end

	-- List button
	self.listButton = self:AddField(Button, "Destinations", {x=130,y=110}, {x=100,y=20} )
	self.listButton.Click = function( sender,args )
		TR_Command:Execute("tr",Hs)
	end

	-- Dock-master check box
	local box = self:AddField(CheckBox, "Maître du quai", {x=45,y=190}, {x=120,y=16} )
	Dusk.TravelRef.Common.ToolTip(box,2,-20,"Utiliser l’esquif du maître du quai.",220)
	box.CheckedChanged = function( sender,args )
		Skiff = sender:IsChecked()
		print((Skiff and "Activé" or "Désactivé").." : maître du quai.")
		self.saveButton:SetEnabled( true )
	end
	box:SetChecked(TR_req.dock)

	self:AddField(Label, "Temps vers quai:", {x=40,y=211}, {x=125,y=16} )
	self.dtime = self:AddField(TextBox, dtime, {x=167,y=210}, {x=30,y=17} )
	self.dtime.TextChanged = function()
		self.saveButton:SetEnabled( true )
	end

	-- List button
	self.dlistButton = self:AddField(Button, "Quais", {x=70,y=235}, {x=100,y=20} )
	self.dlistButton.Click = function( sender,args )
		TR_Command:Execute("tr",Dm)
	end

	-- SetChecked above can fire CheckedChanged on some clients; the initial
	-- state is already loaded from TR_req and therefore is not a pending edit.
	self.saveButton:SetEnabled( false )
end

TR_HTwindow = TR_HTWindow()

if type(TR_req.MS) ~= "table" then TR_req.MS = {} end
TR_Rwindow = TR_RWindow(Reqs_list,440,"Prérequis de voyage")
local TDL = {}
for r in pairs(TD_list) do table.insert(TDL,r) end
table.sort(TDL, function(a, b) return Reqs[a]<Reqs[b] end)
TR_Dwindow = TR_RWindow(TDL,400,"Réductions de voyage")
TR_RTwindow = TR_RWindow(Return,230)
if PC==162 then TR_GTwindow = TR_RWindow(Guide,230) end
if PC==194 then TR_MTwindow = TR_RWindow(Muster,230) end
if PC==216 then TR_STwindow = TR_RWindow(Sail,230) end

-- Keep every TravelRef window on the same user-selected scale.
function TR_ApplyScale(scale)
	scale = tonumber(scale) or 1
	local function apply(window)
		if window and window.SetScale then window:SetScale(scale) end
	end
	apply(TR_window)
	apply(TR_HTwindow)
	apply(TR_Rwindow)
	apply(TR_Dwindow)
	apply(TR_RTwindow)
	apply(TR_GTwindow)
	apply(TR_MTwindow)
	apply(TR_STwindow)
end
TR_ApplyScale(TR_Opt.scale)

-- Set Escape action
TR_window:SetWantsKeyEvents( true )
TR_window.KeyDown = function(sender, args)
	if( args.Action == Turbine.UI.Lotro.Action.Escape and not TR_Opt.esc ) then
		TR_window:SetVisible( false )
		TR_Rwindow:SetVisible( false )
		TR_Dwindow:SetVisible( false )
		TR_RTwindow:SetVisible( false )
		TR_HTwindow:SetVisible( false )
		if TR_GTwindow then TR_GTwindow:SetVisible(false) end
		if TR_MTwindow then TR_MTwindow:SetVisible(false) end
		if TR_STwindow then TR_STwindow:SetVisible(false) end
		TR_req.secs = TR_window.secs:GetText()
		Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character,"Travel_req",TR_req)
	end
end

TRW_Command = Turbine.ShellCommand()

function TRW_Command:Execute( cmd,args )
    if args=="tr" then TR_Rwindow:SetVisible(true) return end
    if args=="td" then TR_Dwindow:SetVisible(true) return end
    if args=="rt" then TR_RTwindow:SetVisible(true) return end
    if args=="gms" then
		if gmsw==false then printe("Niveau trop faible pour ces compétences.") return end
    	if PC==162 then TR_GTwindow:SetVisible(true) return end
    	if PC==194 then TR_MTwindow:SetVisible(true) return end
    	if PC==216 then TR_STwindow:SetVisible(true) return end
		printe("Uniquement pour Chasseurs, Sentinelles ou Marins.")
    end
    if args=="ht" then TR_HTwindow:SetVisible(true) return end
    if args=="?" then Dusk.TravelRef.Common.Help(help,cmd) return end
	if #args==5 and tonumber(args,16) then -- skill id?
		local act = Turbine.UI.Lotro.Shortcut(Skill,"0x700"..args)
		TR_window.Slot:SetShortcut(act)
		return
	end
	if #args>0 then Dusk.TravelRef.Common.Help(help,args) return end
	TR_window.level:SetText( plevel )
    TR_window:SetVisible( true )
end

Turbine.Shell.AddCommand( "trw",TRW_Command )
