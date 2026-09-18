-- Permanent release audit for TravelRef. Runs without LOTRO on Lua 5.1.
-- It validates data relationships and pure/runtime-safe behavior that syntax
-- checks and grep-based regression checks cannot cover.
local errors, warnings = {}, {}
local function err(msg) errors[#errors+1] = msg end
local function warn(msg) warnings[#warnings+1] = msg end
local function count(tbl) local n=0; for _ in pairs(tbl or {}) do n=n+1 end; return n end
local function check(value,msg) if not value then err(msg) end end
local function approx(a,b) return math.abs(a-b) < 0.000001 end

Turbine = {
  Gameplay = { Race = setmetatable({}, {
    __index = function(t,k) rawset(t,k,k); return k end
  }) },
  DataScope = { Character = 1 }
}

-- Enough runtime surface for the post-load robustness module to be exercised.
Dusk = { TravelRef = { Common = { PluginDataSave = function() end } } }
TR_req = {}
function printe() end
function print_tr() end
function TR_LocName(name) return name end

dofile("Dusk/TravelRef/TR_Data.lua")
dofile("Dusk/TravelRef/TR_RouteRules.lua")

local required_tables = {
  "Locs","Zones","Zlvl","zones","Areas","Reqs","Reqs_list","TD_list",
  "R_Dest","R_Locs","Vaults","House","Miles","Return","Guide","Muster",
  "Sail","Travel","Barter","Coin"
}
for _,name in ipairs(required_tables) do
  if type(_G[name]) ~= "table" then err(name.." is not a table") end
end

local function coord_ok(value)
  return type(value)=="string" and value:match("^%d+%.%d+[NnSs], ?%d+%.%d+[EeWw]$") ~= nil
end

local function req_codes_valid(text)
  if text == nil then return true end
  if type(text) ~= "string" then return false end
  local remainder = text:gsub("%u%d+",""):gsub(",",""):gsub("%s+","")
  return remainder == ""
end

local numeric_fields = {"c","s","l","t","st","mt"}
local nonnegative_fields = {c=true,s=true,t=true,st=true,mt=true}
local dest_count, swift_without_time, mixed_requirements = 0,0,0
local legacy_discounts, hidden_regions, metadata_edges = 0,0,0
-- These four t-only links deliberately describe the short physical transfer
-- between a normal stable and its co-located mission-recruiter node. They are
-- metadata, not ride edges, so the route engine must not treat them as travel.
local known_metadata_edges = {
  ["Gabilshathur -> Gabilshathur(R)"] = true,
  ["Gabilshathur(R) -> Gabilshathur"] = true,
  ["Thorin's Gate -> Thorin's Gate(R)"] = true,
  ["Thorin's Gate(R) -> Thorin's Gate"] = true,
}
local used_req = {}
local area_zones = {}

for name,loc in pairs(Locs or {}) do
  if type(name) ~= "string" or type(loc) ~= "table" then
    err("invalid Locs row: "..tostring(name))
  else
    if type(loc.z) ~= "string" then err("location without zone: "..name) end
    if loc.r ~= nil then
      if type(loc.r)~="number" or loc.r%1~=0 or math.abs(loc.r)<1 or math.abs(loc.r)>5 then
        err("invalid region on "..name..": "..tostring(loc.r))
      elseif loc.r < 0 then
        hidden_regions = hidden_regions + 1
      end
    end
    if loc.l ~= nil and not coord_ok(loc.l) then err("invalid coordinate on "..name..": "..tostring(loc.l)) end
    for _,f in ipairs({"t","ml","ql"}) do
      if loc[f] ~= nil and type(loc[f]) ~= "number" then err("non-numeric "..f.." on "..name) end
    end

    if loc.a then
      if type(loc.a) ~= "string" then
        err("non-string area on "..name)
      else
        area_zones[loc.a] = area_zones[loc.a] or {}
        area_zones[loc.a][loc.z] = true
      end
    end

    if loc.td then
      if type(loc.td) ~= "string" or type(Reqs[loc.td]) ~= "string" then
        err("unknown travel-discount requirement "..tostring(loc.td).." on "..name)
      elseif not TD_list[loc.td] then
        -- Historical TravelRef uses a generic 10% discount for requirement
        -- codes that predate TD_list (currently Q8 in Mordor Besieged).
        legacy_discounts = legacy_discounts + 1
      end
    end

    if loc.vr then
      if not req_codes_valid(loc.vr) then err("malformed location requirement on "..name..": "..tostring(loc.vr)) end
      for code in tostring(loc.vr):gmatch("%u%d+") do
        used_req[code] = true
        if not Reqs[code] then err("unknown location requirement "..code.." on "..name) end
      end
    end

    if loc.d ~= nil and type(loc.d) ~= "table" then
      err("destinations are not a table on "..name)
    elseif type(loc.d)=="table" then
      for dest,dv in pairs(loc.d) do
        dest_count = dest_count + 1
        if type(dest) ~= "string" or type(dv) ~= "table" then
          err("invalid destination row from "..name)
        else
          if not Locs[dest] then err("missing destination Locs entry: "..name.." -> "..dest) end
          for _,f in ipairs(numeric_fields) do
            if dv[f] ~= nil and type(dv[f]) ~= "number" then
              err("non-numeric "..f.." on "..name.." -> "..dest)
            elseif nonnegative_fields[f] and type(dv[f])=="number" and dv[f] < 0 then
              err("negative "..f.." on "..name.." -> "..dest)
            end
          end
          if dv.s ~= nil and dv.st == nil then
            swift_without_time = swift_without_time + 1
            warn("swift destination uses documented 20s fallback: "..name.." -> "..dest)
          end
          if dv.c==nil and dv.s==nil and dv.mt==nil and dv.n==nil then
            metadata_edges = metadata_edges + 1
            local edge = name.." -> "..dest
            if not (dv.t and known_metadata_edges[edge]) then
              warn("destination has no routable travel mode: "..edge)
            end
          end
          if dv.r ~= nil and not req_codes_valid(dv.r) then
            err("malformed destination requirements on "..name.." -> "..dest..": "..tostring(dv.r))
          end
          if type(dv.r)=="string" then
            if dv.r:find(",",1,true) then mixed_requirements = mixed_requirements + 1 end
            for code in dv.r:gmatch("%u%d+") do
              used_req[code] = true
              if not Reqs[code] then err("unknown destination requirement "..code.." on "..name.." -> "..dest) end
            end
          elseif dv.r ~= nil then
            err("non-string destination requirements on "..name.." -> "..dest)
          end
        end
      end
    end
  end
end

check(type(AreaZones)=="table","AreaZones is not a table")
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
end

local zone_seen = {}
for _,z in ipairs(zones or {}) do
  if zone_seen[z] then err("duplicate zone in zones list: "..tostring(z)) end
  zone_seen[z]=true
  if Zones[z] == nil then err("zones entry missing Zones mapping: "..tostring(z)) end
  if type(Zlvl[z]) ~= "number" then err("zones entry missing Zlvl: "..tostring(z)) end
end
for name,loc in pairs(Locs or {}) do
  if loc.z and loc.z ~= Hs and Zones[loc.z] == nil and type(loc.d)=="table" then
    err("routable location zone is not in Zones: "..name.." -> "..loc.z)
  end
end

local recruiter_seen = {}
for _,name in ipairs(R_Locs or {}) do
  if recruiter_seen[name] then err("duplicate R_Locs entry: "..tostring(name)) end
  recruiter_seen[name] = true
  if not Locs[name] then err("R_Locs missing Locs entry: "..tostring(name))
  elseif type(Locs[name].d) ~= "table" then warn("R_Locs entry has no destinations: "..name) end
end
for name,d in pairs(R_Dest or {}) do
  if not Locs[name] then err("R_Dest missing Locs entry: "..tostring(name)) end
  if type(d) ~= "table" then err("invalid R_Dest row: "..tostring(name))
  else
    for _,f in ipairs(numeric_fields) do
      if d[f] ~= nil and type(d[f]) ~= "number" then err("non-numeric recruiter "..f.." on "..name) end
    end
  end
end

for reg,list in pairs(Vaults or {}) do
  if type(list) ~= "table" then err("Vaults region not a table: "..tostring(reg))
  else
    for i,v in ipairs(list) do
      if type(v) ~= "table" or type(v.n)~="string" or type(v.z)~="string" or not coord_ok(v.l) then
        err("invalid vault row in "..tostring(reg).." #"..i)
      end
    end
  end
end

local req_seen = {}
for _,code in ipairs(Reqs_list or {}) do
  if req_seen[code] then err("duplicate Reqs_list code: "..tostring(code)) end
  req_seen[code]=true
  if type(Reqs[code]) ~= "string" then err("Reqs_list missing label: "..tostring(code)) end
end
for code,rate in pairs(TD_list or {}) do
  if type(rate)~="number" or rate<=0 or rate>1 then err("invalid discount rate "..tostring(code)) end
  if type(Reqs[code])~="string" then err("discount without requirement label: "..tostring(code)) end
end

local race_only = {}
local function audit_skill(label,tbl)
  if type(tbl.nm)~="string" or type(tbl.tb)~="string" or type(tbl.it)~="number" then err(label.." metadata invalid") end
  for name,row in pairs(tbl) do
    if type(row)=="table" then
      if type(row.tl)~="number" then err(label.." entry without numeric tl: "..name) end
      if type(row.t)~="number" then err(label.." entry without numeric travel time: "..name) end
      if row.n ~= nil and type(row.n)~="string" then err(label.." entry with invalid alternate name: "..name) end
      if row.p ~= nil and type(row.p)~="string" then err(label.." entry with invalid route name: "..name) end
      local route = row.p or name
      if not Locs[route] then err(label.." route start missing from Locs: "..name.." -> "..tostring(route)) end
      if row.d ~= nil and type(row.d)~="string" then err(label.." entry with invalid action code: "..name) end
      if row.rd ~= nil and type(row.rd)~="string" then err(label.." entry with invalid racial action code: "..name) end
      if row.id ~= nil and type(row.id)~="string" then err(label.." entry with invalid learn ID: "..name) end
      if row.r and row.rd and not row.d then race_only[#race_only+1] = label..":"..name end
      if not row.d and not row.rd then err(label.." entry without action code: "..name) end
    end
  end
end
for _,pair in ipairs({{"Return",Return},{"Guide",Guide},{"Muster",Muster},{"Sail",Sail}}) do audit_skill(pair[1],pair[2]) end

for k,v in pairs(House or {}) do
  if type(k)~="string" or type(v)~="string" then err("invalid House entry: "..tostring(k)) end
end
if not Locs[Hs] or type(Locs[Hs].d)~="table" then err("Homestead route table missing") end
if not Locs[Dm] or type(Locs[Dm].d)~="table" then err("Dock-master route table missing") end
for i=1,11 do if type(Miles[i])~="string" then err("missing milestone skill #"..i) end end

for name,b in pairs(Barter or {}) do
  if type(b)=="table" then
    if b.id and not Coin[b.id] then err("Barter currency name missing for "..name.." -> "..tostring(b.id)) end
    if b.id and type(b.c)~="number" then err("Barter amount missing/non-numeric for "..name) end
    if b.c and not b.id and not b.n then err("Store barter row missing display name: "..name) end
  elseif type(b)~="string" then
    err("invalid Barter row: "..tostring(name))
  end
end

-- Route-rule behavior. Keep legacy generic 10% discounts as well as modern
-- TD_list percentages, special R17/R18 stacking and the founder S2 reduction.
check(TR_RequirementCodesMet("R29,Q6",{R29=true,Q6=true},false),"route rule: swift mixed requirements")
check(not TR_RequirementCodesMet("R29,Q6",{Q6=true},false),"route rule: swift reputation requirement")
check(TR_RequirementCodesMet("R29,Q6",{Q6=true},true),"route rule: normal suffix requirement")
check(not TR_RequirementCodesMet("R29,Q6",{R29=true},true),"route rule: normal missing suffix requirement")
check(TR_RequirementCodesMet(",Q7",{Q7=true},true),"route rule: leading-comma normal requirement")
check(approx(TR_DiscountRate("R23",{R23=true,S2=true},TD_list,Reqs),0.60),"route rule: stacked R23 + S2 discount")
check(approx(TR_DiscountRate("R17",{R17=true,R18=true},TD_list,Reqs),0.80),"route rule: R17 + R18 discount")
check(approx(TR_DiscountRate("Q8",{Q8=true},TD_list,Reqs),0.90),"route rule: legacy Q8 generic discount")
check(TR_DiscountRate("UNKNOWN",{UNKNOWN=true},TD_list,Reqs)==1,"route rule: unknown discount fallback")

-- Execute the actual post-load coordinate implementation with LOTRO stubs.
-- This catches regressions in stable, recruiter and vault lookup semantics.
dofile("Dusk/TravelRef/TR_Robustness.lua")
do
  local first_reg, first_vault_list
  for reg,list in pairs(Vaults) do
    if #list>0 then first_reg,first_vault_list = reg,list; break end
  end
  if first_vault_list then
    local row = first_vault_list[1]
    local y,x = row.l:match("^(%d+%.%d+[NnSs]), ?(%d+%.%d+[EeWw])$")
    local _,name = Loc_Find(nil,y,x,first_vault_list,false)
    check(name==row.n,"coordinate lookup: vault lookup must return the nearest vault")
  else
    err("coordinate lookup: no vault test data")
  end

  local stable_name,stable
  for name,loc in pairs(Locs) do
    if loc.r and loc.r>0 and loc.d and coord_ok(loc.l) and loc.l:match("[Ww]$") then
      stable_name,stable=name,loc
      break
    end
  end
  if stable then
    local y,x = stable.l:match("^(%d+%.%d+[NnSs]), ?(%d+%.%d+[EeWw])$")
    local _,name = Loc_Find(stable.r,y,x,Locs,false)
    check(name~=nil and Locs[name]~=nil,"coordinate lookup: stable lookup must return a routable stable")
    local ox = x:gsub("[Ww]","o")
    local _,oname = Loc_Find(stable.r,y,ox,Locs,false)
    check(oname~=nil and Locs[oname]~=nil,"coordinate lookup: French Ouest suffix must be accepted")
  else
    err("coordinate lookup: no stable test data")
  end

  local recruiter_name = R_Locs[1]
  local recruiter = recruiter_name and Locs[recruiter_name]
  if recruiter and recruiter.r and coord_ok(recruiter.l) then
    local y,x = recruiter.l:match("^(%d+%.%d+[NnSs]), ?(%d+%.%d+[EeWw])$")
    local _,name = Loc_Find(recruiter.r,y,x,R_Locs,true)
    check(name~=nil and Locs[name]~=nil,"coordinate lookup: recruiter lookup must return a recruiter stable")
  else
    err("coordinate lookup: no recruiter test data")
  end
end

print(string.format("DATA: %d locations, %d destination edges, %d zones, %d areas, %d requirements", count(Locs), dest_count, #(zones or {}), count(Areas), count(Reqs)))
print(string.format("ROUTING: %d mixed requirement edges, %d swift fallback times, %d metadata-only edges", mixed_requirements, swift_without_time, metadata_edges))
print(string.format("SPECIAL DATA: %d legacy generic discounts, %d hidden-region locations, %d multi-zone areas", legacy_discounts, hidden_regions, multi_zone_areas))
print("RACE_ONLY: "..table.concat(race_only, ", "))
for _,w in ipairs(warnings) do print("WARNING: "..w) end
for _,e in ipairs(errors) do print("ERROR: "..e) end
print(string.format("RELEASE_AUDIT_RESULT errors=%d warnings=%d",#errors,#warnings))
if #errors>0 then os.exit(1) end
