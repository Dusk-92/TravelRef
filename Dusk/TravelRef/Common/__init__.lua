import "Dusk.TravelRef.Common.Class"
import "Dusk.TravelRef.Common.Sort"
import "Dusk.TravelRef.Common.Type"

-- Keep PluginData handling local to TravelRef. Older Dusk plugin combinations
-- could apply two marker-encoding layers to these saves; decode complete legacy
-- layers until the root is normal again. Decoding is always enabled so changing
-- the LOTRO client language cannot strand FR/DE saves on an EN client.
local NativeLoad = Turbine.PluginData.Load
local NativeSave = Turbine.PluginData.Save
local LocalizedPluginData =
    Turbine.Shell.IsCommand("aide") or Turbine.Shell.IsCommand("zusatzmodule")
local FailedLoads = {}

local function ExportTable(obj)
    if type(obj) == "number" then
        return "#" .. string.gsub(tostring(obj), ",", ".")
    elseif type(obj) == "string" then
        return "$" .. obj
    elseif type(obj) == "table" then
        local out = {}
        for k,v in pairs(obj) do out[ExportTable(k)] = ExportTable(v) end
        return out
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

local function ImportOnce(obj)
    if type(obj) == "string" then
        local prefix = string.sub(obj,1,1)
        if prefix == "$" then
            return string.sub(obj,2)
        elseif prefix == "#" then
            local text = string.sub(obj,2)
            return ParseNumber(text) or ("#"..text)
        end
        return obj
    elseif type(obj) == "table" then
        local out = {}
        for k,v in pairs(obj) do
            local dk = ImportOnce(k)
            if dk ~= nil then out[dk] = ImportOnce(v) end
        end
        return out
    end
    return obj
end

local function LooksEncoded(value)
    if type(value) == "string" then
        local p = string.sub(value,1,1)
        return p=="$" or p=="#"
    end
    if type(value) ~= "table" then return false end
    local saw = false
    for k in pairs(value) do
        if type(k) == "string" then
            local p = string.sub(k,1,1)
            if p~="$" and p~="#" then return false end
            saw = true
        elseif type(k) == "number" then
            return false
        end
    end
    return saw
end

local function DecodeLegacy(value)
    local current=value
    for _=1,4 do
        if not LooksEncoded(current) then break end
        current=ImportOnce(current)
    end
    return current
end

function PluginDataLoadChecked(dataScope,key,dataLoadEventHandler)
    local wrapped
    if dataLoadEventHandler then
        wrapped=function(diskData)
            local ok,decoded=pcall(DecodeLegacy,diskData)
            dataLoadEventHandler(ok and decoded or diskData)
        end
    end

    local ok,diskData=pcall(NativeLoad,dataScope,key,wrapped)
    if not ok then
        FailedLoads[key]=tostring(diskData)
        return nil,false,diskData
    end

    local decodedOK,decoded=pcall(DecodeLegacy,diskData)
    if not decodedOK then
        FailedLoads[key]=tostring(decoded)
        return diskData,false,decoded
    end
    FailedLoads[key]=nil
    return decoded,true,nil
end

function PluginDataLoad(dataScope,key,dataLoadEventHandler)
    local data=PluginDataLoadChecked(dataScope,key,dataLoadEventHandler)
    return data
end

function PluginDataSave(dataScope,key,data,saveCompleteEventHandler)
    if FailedLoads[key] then
        if saveCompleteEventHandler then
            pcall(saveCompleteEventHandler,false,"load failed earlier in this session")
        end
        return false
    end
    local payload=LocalizedPluginData and ExportTable(data) or data
    return NativeSave(dataScope,key,payload,saveCompleteEventHandler)
end

function PluginDataDecodeLegacy(value)
    return DecodeLegacy(value)
end
