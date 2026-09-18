-- TravelRef runtime robustness fixes loaded after TR_Main.
-- coding: utf-8 'ä

-- Old saves may have the dock option enabled without a separate dtime value
-- (older builds accidentally reused htime).  Give them a safe default before
-- any route calculation can use the value.
if type(TR_req) == "table" then
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
end

local TR_RobustCoord = "^(%d+%.%d[NnSs]), ?(%d+%.%d[EeWwOo])$"
local TR_RobustZloc = "^(.+): .+: (%d+%.%d[NnSs]), (%d+%.%d[EeWwOo])$"

local function TR_RobustLocValue(str, negative)
    if type(str) ~= "string" then return nil end
    local number = tonumber(str:sub(1, -2))
    if not number then return nil end
    if negative:find(str:sub(-1)) then number = -number end
    return number
end

local function TR_RobustDistance(dy, dx)
    return math.sqrt(dy * dy + dx * dx)
end

-- Skip malformed/missing entries instead of dereferencing nil.  Keep internal
-- English keys untouched and translate only when displaying the result.
function Loc_Find(r, y, x, locs, flg)
    if type(locs) ~= "table" then
        return "aucun lieu correspondant trouvé", nil
    end

    local y1 = TR_RobustLocValue(y, "Ss")
    local x1 = TR_RobustLocValue(x, "WwOo")
    if not y1 or not x1 then
        return "coordonnées invalides", nil
    end

    local bestDistance = 999
    local bestName = nil
    local bestCoords = nil

    for loc, value in pairs(locs) do
        local name, tbl
        if flg then
            name = value
            tbl = Locs and Locs[value] or nil
        else
            name = loc
            tbl = value
        end

        if type(tbl) ~= "table" then
            printe("Aucun lieu défini pour "..tostring(name))
        elseif (not r) or ((flg or tbl.d) and tbl.r == r) then
            local y0, x0
            if type(tbl.l) == "string" then y0, x0 = tbl.l:match(TR_RobustCoord) end
            if not y0 or not x0 then
                printe("Coordonnées invalides pour "..TR_LocName(name))
            else
                local y2 = TR_RobustLocValue(y0, "Ss")
                local x2 = TR_RobustLocValue(x0, "WwOo")
                if y2 and x2 then
                    local d = TR_RobustDistance(y1 - y2, x1 - x2)
                    if d < bestDistance then
                        bestDistance = d
                        bestName = r and name or (tbl.n or name)
                        bestCoords = tbl.l
                    end
                end
            end
        end
    end

    if not bestName or not bestCoords then
        return "aucun lieu correspondant trouvé", nil
    end

    return string.format("%s @ %s (à %.1f unités).", TR_LocName(bestName), bestCoords, bestDistance), bestName
end

-- TR_Main's original helper assumes Loc_Find always succeeds.  Guard its UI
-- updates so one malformed data row cannot abort the whole plugin command.
function TR_Find(args, locs, flg)
    local reg, y, x = args:match(TR_RobustZloc)
    if not y then
        printe("Aucune donnée de lieu dans cette instance.")
        return
    end

    local r = Region[reg]
    if not r then
        print("Région inconnue : "..reg)
        return
    end

    local d, ln = Loc_Find(r, y, x, locs, flg)
    if not ln or not Locs or not Locs[ln] then
        printe("Aucun lieu correspondant trouvé.")
        return
    end

    local w = flg and "de recruteur de mission " or ""
    print("L’écurie "..w.."la plus proche est "..d)
    TR_window.zoneMenu:SetText(TR_ZoneName(Locs[ln].z))
    TR_window.locMenu:SetText(TR_LocName(ln))
end
