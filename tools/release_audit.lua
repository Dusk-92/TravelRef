-- Temporary release audit for TravelRef. Runs without LOTRO.
local errors, warnings = {}, {}
local function err(msg) errors[#errors+1] = msg end
local function warn(msg) warnings[#warnings+1] = msg end
local function count(tbl) local n=0; for _ in pairs(tbl or {}) do n=n+1 end; return n end

Turbine = { Gameplay = { Race = setmetatable({}, {
  __index = function(t,k) rawset(t,k,k); return k end
}) } }

dofile("Dusk/TravelRef/TR_Data.lua")
dofile("Dusk/TravelRef/TR_RouteRules.lua")

local required_tables = {"Locs","Zones","Zlvl","zones","Areas","Reqs","Reqs_list","TD_list","R_Dest","R_Locs","Vaults","House","Miles","Return","Guide","Muster","Sail","Travel"}
for _,name in ipairs(required_tables) do
  if type(_G[name]) ~= "table" then err(name.." is not a table") end
end

local function coord_ok(value)
  return type(value)=="string" and value:match("^%d+%.%d+[NnSs], ?%d+%.%d+[EeWw]$") ~= nil
end

local numeric_fields = {"c","s","l","t","st","mt"}
local dest_count, swift_without_time, mixed_requirements = 0,0,0
local used_req = {}

for name,loc in pairs(Locs or {}) do
  if type(name) ~= "string" or type(loc) ~= "table" then
    err("invalid Locs row: "..tostring(name))
  else
    if type(loc.z) ~= "string" then err("location without zone: "..name) end
    if loc.r ~= nil and (type(loc.r)~="number" or loc.r<1 or loc.r>5) then err("invalid region on "..name) end
    if loc.l ~= nil and not coord_ok(loc.l) then err("invalid coordinate on "..name..": "..tostring(loc.l)) end
    for _,f in ipairs({"t","ml","ql"}) do
      if loc[f] ~= nil and type(loc[f]) ~= "number" then err("non-numeric "..f.." on "..name) end
    end
    if loc.td then
      if not TD_list[loc.td] then err("unknown discount code "..tostring(loc.td).." on "..name) end
      if not Reqs[loc.td] then err("discount code without label "..tostring(loc.td).." on "..name) end
    end
    if loc.vr then
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
            if dv[f] ~= nil and type(dv[f]) ~= "number" then err("non-numeric "..f.." on "..name.." -> "..dest) end
          end
          if dv.s ~= nil and dv.st == nil then
            swift_without_time = swift_without_time + 1
            warn("swift destination uses fallback time: "..name.." -> "..dest)
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

local zone_seen = {}
for _,z in ipairs(zones or {}) do
  if zone_seen[z] then err("duplicate zone in zones list: "..tostring(z)) end
  zone_seen[z]=true
  if Zones[z] == nil then err("zones entry missing Zones mapping: "..tostring(z)) end
  if type(Zlvl[z]) ~= "number" then err("zones entry missing Zlvl: "..tostring(z)) end
end
for name,loc in pairs(Locs or {}) do
  if loc.z and Zones[loc.z] == nil and loc.z ~= Hs then warn("location zone is not in Zones: "..name.." -> "..loc.z) end
end

for _,name in ipairs(R_Locs or {}) do
  if not Locs[name] then err("R_Locs missing Locs entry: "..tostring(name))
  elseif type(Locs[name].d) ~= "table" then warn("R_Locs entry has no destinations: "..name) end
end
for name,d in pairs(R_Dest or {}) do
  if not Locs[name] then err("R_Dest missing Locs entry: "..tostring(name)) end
  if type(d) ~= "table" then err("invalid R_Dest row: "..tostring(name)) end
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
      if row.r and row.rd and not row.d then race_only[#race_only+1] = label..":"..name end
      if not row.d and not row.rd then err(label.." entry without action code: "..name) end
      if row.n ~= nil and type(row.n)~="string" then err(label.." entry with invalid alternate name: "..name) end
    end
  end
end
for _,pair in ipairs({{"Return",Return},{"Guide",Guide},{"Muster",Muster},{"Sail",Sail}}) do audit_skill(pair[1],pair[2]) end

for k,v in pairs(House or {}) do
  if type(k)~="string" or type(v)~="string" then err("invalid House entry: "..tostring(k)) end
end
for i=1,11 do if type(Miles[i])~="string" then err("missing milestone skill #"..i) end end

-- Route-rule behavior, duplicated here so the release audit fails if semantics regress.
local function check(value,msg) if not value then err("route rule: "..msg) end end
check(TR_RequirementCodesMet("R29,Q6",{R29=true,Q6=true},false),"swift mixed requirements")
check(not TR_RequirementCodesMet("R29,Q6",{Q6=true},false),"swift reputation requirement")
check(TR_RequirementCodesMet("R29,Q6",{Q6=true},true),"normal suffix requirement")
check(not TR_RequirementCodesMet("R29,Q6",{R29=true},true),"normal missing suffix requirement")
check(TR_RequirementCodesMet(",Q7",{Q7=true},true),"leading-comma normal requirement")
check(math.abs(TR_DiscountRate("R23",{R23=true,S2=true},TD_list)-0.60)<0.000001,"stacked R23 + S2 discount")
check(TR_DiscountRate("UNKNOWN",{UNKNOWN=true},TD_list)==1,"unknown discount fallback")

print(string.format("DATA: %d locations, %d destination edges, %d zones, %d areas, %d requirements", count(Locs), dest_count, #(zones or {}), count(Areas), count(Reqs)))
print(string.format("ROUTING: %d mixed requirement edges, %d swift edges using fallback time", mixed_requirements, swift_without_time))
print("RACE_ONLY: "..table.concat(race_only, ", "))
for _,w in ipairs(warnings) do print("WARNING: "..w) end
for _,e in ipairs(errors) do print("ERROR: "..e) end
print(string.format("RELEASE_AUDIT_RESULT errors=%d warnings=%d",#errors,#warnings))
if #errors>0 then os.exit(1) end
