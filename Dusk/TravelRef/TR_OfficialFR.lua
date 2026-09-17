-- TravelRef official French LOTRO display layer.
--
-- The data files contain EN -> FR pairs joined by LOTRO's own localization
-- keys. Route data and saved-data keys remain untouched in English.

import "Dusk.TravelRef.Common.noAccent"

TR_OfficialZoneRaw = {}
TR_OfficialLocRaw = {}
import "Dusk.TravelRef.TR_OfficialFR_Data1"
import "Dusk.TravelRef.TR_OfficialFR_Data2"
import "Dusk.TravelRef.TR_OfficialFR_Data3"
import "Dusk.TravelRef.TR_OfficialFR_Data4"
import "Dusk.TravelRef.TR_OfficialFR_Data5"

local function OfficialNorm(value)
    if not value then return nil end
    value = noAccent(value):lower()
    value = value:gsub("œ", "oe"):gsub("æ", "ae")
    value = value:gsub("[^%w]", "")
    return value
end

local function BuildOfficialMap(raw)
    local exact = {}
    local aliases = {}
    local ambiguous = {}

    local function addAlias(value, fr)
        if not value or value == "" then return end
        local key = OfficialNorm(value)
        if not key or key == "" or exact[key] then return end
        if aliases[key] == nil then
            aliases[key] = fr
        elseif aliases[key] ~= fr then
            ambiguous[key] = true
        end
    end

    -- Exact labels always win.
    for en,fr in pairs(raw) do
        exact[OfficialNorm(en)] = fr
    end

    -- Older TravelRef data often omits a geographic qualifier that the modern
    -- stable-map label includes, e.g. "Bargstad" vs
    -- "Bárgstad (Pit of Stonejaws)". Only unique aliases are accepted.
    for en,fr in pairs(raw) do
        local base = en:gsub("%s*%b()%s*$", "")
        addAlias(base, fr)
        addAlias(base:gsub("^The%s+", ""), fr)

        local simple = base:gsub(",%s+the%s+.+$", "")
        addAlias(simple, fr)
        addAlias(simple:gsub("^The%s+", ""), fr)

        local travel = en:gsub("%s+%-%s+Swift$", "")
        travel = travel:gsub("%s+%-%s+Boat Travel$", "")
        addAlias(travel, fr)
        addAlias(travel:gsub("^The%s+", ""), fr)

        addAlias(en:gsub("^The%s+", ""), fr)
    end

    for key,fr in pairs(aliases) do
        if not ambiguous[key] and not exact[key] then exact[key] = fr end
    end
    return exact
end

local OfficialLoc = BuildOfficialMap(TR_OfficialLocRaw)
local OfficialZone = BuildOfficialMap(TR_OfficialZoneRaw)

-- A handful of TravelRef region keys use an older English form that cannot be
-- recovered by accent/punctuation normalization alone.
local ZoneAliases = {
    ["Great River"] = "The Great River",
    ["West Rohan"] = "Western Rohan",
    ["East Gondor"] = "Eastern Gondor",
    ["West Gondor"] = "Western Gondor",
    ["Valley of Ikorbad"] = "Valley of Ikorbân",
}
for oldName,officialName in pairs(ZoneAliases) do
    local fr = OfficialZone[OfficialNorm(officialName)]
    if fr then OfficialZone[OfficialNorm(oldName)] = fr end
end

local PreviousLocName = TR_LocName
local PreviousZoneName = TR_ZoneName

function TR_LocName(name)
    if not name then return name end

    -- Internal suffixes distinguish recruiter/boat/etc. nodes but are not part
    -- of LOTRO's localized place name.
    local base,suffix = name:match("^(.-)(%([A-Z]+%))$")
    base = base or name

    local official = OfficialLoc[OfficialNorm(base)]
    if official then return official..(suffix or "") end
    return PreviousLocName(name)
end

function TR_ZoneName(name)
    if not name then return name end
    local official = OfficialZone[OfficialNorm(name)]
    if official then return official end
    return PreviousZoneName(name)
end

-- TR_Data.lua built these reverse lookup tables before this official display
-- layer was loaded, so rebuild them with the final visible French strings.
TR_LocEN = {}
for en in pairs(Locs) do TR_LocEN[TR_LocName(en)] = en end
for en in pairs(R_Dest) do TR_LocEN[TR_LocName(en)] = en end
function TR_LocKey(name) return TR_LocEN[name] or name end

TR_ZoneEN = {}
for en in pairs(TR_ZoneFR) do TR_ZoneEN[TR_ZoneName(en)] = en end
function TR_ZoneKey(name) return TR_ZoneEN[name] or name end
