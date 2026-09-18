-- Persistence regression tests for TravelRef. Runs on stock Lua 5.1.
local function check(value, message)
    if not value then error(message, 2) end
end

local commonPath = "Dusk/TravelRef/Common/__init__.lua"

local function loadCommon(localized, initial, failLoad)
    local saved = {}
    local env = {}
    setmetatable(env, { __index = _G })

    env.import = function() end
    env.Turbine = {
        PluginData = {
            Load = function(scope, key, handler)
                if failLoad then error("simulated load failure") end
                local value = initial and initial[key] or nil
                if handler then handler(value) end
                return value
            end,
            Save = function(scope, key, value, handler)
                saved[key] = value
                if handler then handler(true) end
                return true
            end,
        },
        Shell = {
            IsCommand = function(command)
                return localized and command == "aide"
            end,
        },
    }

    local chunk = assert(loadfile(commonPath))
    setfenv(chunk, env)
    chunk()
    return env, saved
end

-- English clients save native values.
do
    local env, saved = loadCommon(false)
    check(env.PluginDataSave(1, "raw", {name="Bree", count=1.5}), "native save failed")
    check(saved.raw.name == "Bree", "English save unexpectedly encoded strings")
    check(saved.raw.count == 1.5, "English save unexpectedly encoded numbers")
end

-- Localized clients use locale-neutral markers.
local once
do
    local env, saved = loadCommon(true)
    check(env.PluginDataSave(1, "fr", {name="Bree", count=1.5}), "localized save failed")
    once = saved.fr
    check(once["$name"] == "$Bree", "localized string marker missing")
    check(once["$count"] == "#1.5", "localized number marker missing")
end

-- Simulate the historical double-encoding produced by stacked Dusk wrappers.
local twice
do
    local env, saved = loadCommon(true)
    check(env.PluginDataSave(1, "fr2", once), "second localized save failed")
    twice = saved.fr2
end

-- Decoding is language-independent and peels all complete legacy layers.
do
    local env = loadCommon(false, { legacy = twice })
    local decoded, ok = env.PluginDataLoadChecked(1, "legacy")
    check(ok == true, "legacy load reported failure")
    check(decoded.name == "Bree", "double-encoded string was not recovered")
    check(math.abs(decoded.count - 1.5) < 0.000001, "double-encoded number was not recovered")
end

-- Async load callbacks receive the same decoded data.
do
    local env = loadCommon(false, { legacy = once })
    local callbackValue
    env.PluginDataLoad(1, "legacy", function(value) callbackValue = value end)
    check(type(callbackValue) == "table", "load callback did not receive a table")
    check(callbackValue.name == "Bree", "load callback did not receive decoded data")
end

-- A failed load must block a later save for the same key in that session.
do
    local env, saved = loadCommon(false, nil, true)
    local _, ok = env.PluginDataLoadChecked(1, "unsafe")
    check(ok == false, "simulated load failure was not reported")
    check(env.PluginDataSave(1, "unsafe", {value=1}) == false, "save was not blocked after failed load")
    check(saved.unsafe == nil, "failed-load key was overwritten")
end

print("TravelRef PluginData tests OK")
