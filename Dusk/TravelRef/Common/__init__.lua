import "Dusk.TravelRef.Common.Class"
import "Dusk.TravelRef.Common.Sort"
import "Dusk.TravelRef.Common.Type"

-- LOTRO historically had locale-sensitive PluginData number handling on some
-- French/German clients.  Keep the workaround local to Dusk plugins instead
-- of replacing Turbine.PluginData.Load/Save globally for every loaded plugin.
local LocalizedPluginData = Turbine.Shell.IsCommand("aide") or
    Turbine.Shell.IsCommand("zusatzmodule")

local function ExportTable(obj)
    if type(obj) == "number" then
        -- Store a locale-neutral decimal representation with a type marker.
        return "#" .. string.gsub(tostring(obj), ",", ".")
    elseif type(obj) == "string" then
        return "$" .. obj
    elseif type(obj) == "table" then
        local newTable = {}
        for i, v in pairs(obj) do
            newTable[ExportTable(i)] = ExportTable(v)
        end
        return newTable
    end
    return obj
end

local function ParseNumber(text)
    local n = tonumber(text)
    if n ~= nil then return n end
    n = tonumber((string.gsub(text, "\.", ",")))
    if n ~= nil then return n end
    n = tonumber((string.gsub(text, ",", ".")))
    return n
end

local function ImportTable(obj)
    if type(obj) == "string" then
        local prefix = string.sub(obj, 1, 1)
        if prefix == "$" then
            return string.sub(obj, 2)
        elseif prefix == "#" then
            local text = string.sub(obj, 2)
            return ParseNumber(text) or text
        end
        return obj
    elseif type(obj) == "table" then
        local newTable = {}
        for i, v in pairs(obj) do
            newTable[ImportTable(i)] = ImportTable(v)
        end
        return newTable
    end
    return obj
end

function PluginDataLoad(dataScope, key, dataLoadEventHandler)
    if not LocalizedPluginData then
        return Turbine.PluginData.Load(dataScope, key, dataLoadEventHandler)
    end

    local wrappedHandler
    if dataLoadEventHandler then
        wrappedHandler = function(diskData)
            dataLoadEventHandler(ImportTable(diskData))
        end
    end

    local success, diskData = pcall(Turbine.PluginData.Load, dataScope, key, wrappedHandler)
    if not success then return nil end
    if diskData ~= nil then return ImportTable(diskData) end
    return nil
end

function PluginDataSave(dataScope, key, data, saveCompleteEventHandler)
    if LocalizedPluginData then data = ExportTable(data) end
    return Turbine.PluginData.Save(dataScope, key, data, saveCompleteEventHandler)
end
