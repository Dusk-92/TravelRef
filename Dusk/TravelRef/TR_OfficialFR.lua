-- TravelRef official French LOTRO display layer.
-- coding: utf-8 'ä
--
-- Internal travel/location keys stay in English. This layer only changes
-- labels shown to the player. Any localization failure is contained by pcall.

local function TR_OfficialSafeImport(moduleName, required)
    local ok, err = pcall(import, moduleName)
    if not ok and required then
        error("échec import "..moduleName.." : "..tostring(err))
    end
    return ok, err
end

local TR_OfficialOK, TR_OfficialError = pcall(function()
    TR_OfficialSafeImport("Dusk.TravelRef.Common.noAccent", false)

    TR_OfficialZoneRaw = {}
    TR_OfficialLocRaw = {}
    TR_OfficialAreaRaw = {}
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data1", true)
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data2", true)
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data3", true)
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data4", true)
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data5", true)
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Auto", true)

    -- TravelRef uses a few shortened/old internal names which do not exist as
    -- exact English labels in the current client data. These French values are
    -- taken from the corresponding official EN/FR localization IDs.
    TR_OfficialZoneRaw["Azanulbizar"] = "Contes des temps jadis : Azanulbizar"
    TR_OfficialZoneRaw["Strongholds"] = "Bastions du Nord"
    TR_OfficialZoneRaw["Zirer Tarka"] = "Les îles du Bouclier"

    TR_OfficialAreaRaw["Belfalas"] = "Les Havres de Belfalas (Gondor royal)"
    TR_OfficialAreaRaw["Dor-en-Emil"] = "Dor-en-Ernil (Gondor royal)"
    TR_OfficialAreaRaw["Fearwater"] = "Sûg Nidar, les Eaux troubles"
    TR_OfficialAreaRaw["the berths"] = "Dil-irmiz, les Mouillages"
    TR_OfficialAreaRaw["the cellars"] = "Tâkhdar, les Caves"
    TR_OfficialAreaRaw["the crypts"] = "Khabârkhad, les Cryptes"
    TR_OfficialAreaRaw["the vaults"] = "Kamrabezûr, les Chambres fortes"
    TR_OfficialAreaRaw["the wells"] = "Ilmabiri, les Puits"

    local AccentFallback = {
        ["à"]="a", ["á"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a", ["å"]="a",
        ["À"]="A", ["Á"]="A", ["Â"]="A", ["Ã"]="A", ["Ä"]="A", ["Å"]="A",
        ["æ"]="ae", ["Æ"]="AE", ["ç"]="c", ["Ç"]="C",
        ["è"]="e", ["é"]="e", ["ê"]="e", ["ë"]="e",
        ["È"]="E", ["É"]="E", ["Ê"]="E", ["Ë"]="E",
        ["ì"]="i", ["í"]="i", ["î"]="i", ["ï"]="i",
        ["Ì"]="I", ["Í"]="I", ["Î"]="I", ["Ï"]="I",
        ["ñ"]="n", ["Ñ"]="N",
        ["ò"]="o", ["ó"]="o", ["ô"]="o", ["õ"]="o", ["ö"]="o", ["ø"]="o",
        ["Ò"]="O", ["Ó"]="O", ["Ô"]="O", ["Õ"]="O", ["Ö"]="O", ["Ø"]="O",
        ["ù"]="u", ["ú"]="u", ["û"]="u", ["ü"]="u",
        ["Ù"]="U", ["Ú"]="U", ["Û"]="U", ["Ü"]="U",
        ["ý"]="y", ["ÿ"]="y", ["Ý"]="Y", ["œ"]="oe", ["Œ"]="OE",
    }

    local function CleanOfficial(value)
        if type(value) ~= "string" then return value end
        value = string.gsub(value, "%[[%a]+%]", "")
        value = string.gsub(value, "\194\160", " ")
        return value
    end

    local function OfficialNorm(value)
        if type(value) ~= "string" then return nil end
        if type(noAccent) == "function" then
            value = noAccent(value)
        else
            for accented,plain in pairs(AccentFallback) do
                value = string.gsub(value, accented, plain)
            end
        end
        value = string.lower(value)
        value = string.gsub(value, "[^%w]", "")
        return value
    end

    local function BuildOfficialMap(raw)
        local exact = {}
        local aliases = {}
        local ambiguous = {}

        local function addExact(value, fr)
            fr = CleanOfficial(fr)
            local key = OfficialNorm(value)
            if key and key ~= "" then exact[key] = fr end
        end

        local function addAlias(value, fr)
            fr = CleanOfficial(fr)
            if type(value) ~= "string" or value == "" then return end
            local key = OfficialNorm(value)
            if not key or key == "" or exact[key] then return end
            if aliases[key] == nil then
                aliases[key] = fr
            elseif aliases[key] ~= fr then
                ambiguous[key] = true
            end
        end

        for en,fr in pairs(raw or {}) do addExact(en, fr) end
        for en,fr in pairs(raw or {}) do
            local base = string.gsub(en, "%s*%b()%s*$", "")
            addAlias(base, fr)
            addAlias(string.gsub(base, "^The%s+", ""), fr)

            local simple = string.gsub(base, ",%s+the%s+.+$", "")
            addAlias(simple, fr)
            addAlias(string.gsub(simple, "^The%s+", ""), fr)

            local travel = string.gsub(en, "%s+%-%s+Swift$", "")
            travel = string.gsub(travel, "%s+%-%s+Swift Travel$", "")
            travel = string.gsub(travel, "%s+%-%s+Boat Travel$", "")
            addAlias(travel, fr)
            addAlias(string.gsub(travel, "^The%s+", ""), fr)
            addAlias(string.gsub(en, "^The%s+", ""), fr)
        end

        for key,fr in pairs(aliases) do
            if not ambiguous[key] and not exact[key] then exact[key] = fr end
        end
        return exact
    end

    local OfficialLoc = BuildOfficialMap(TR_OfficialLocRaw)
    local OfficialZone = BuildOfficialMap(TR_OfficialZoneRaw)
    local OfficialArea = BuildOfficialMap(TR_OfficialAreaRaw)

    local ZoneAliases = {
        ["Great River"] = "The Great River",
        ["West Rohan"] = "Western Rohan",
        ["East Gondor"] = "Eastern Gondor",
        ["West Gondor"] = "Western Gondor",
        ["Valley of Ikorbad"] = "Valley of Ikorbân",
    }

    local LegacyOfficial = {
        ["Anazarmekhem"] = "Anazârmekhem",
        ["Eastern Crossroads"] = "Carrefour de l'Est",
        ["Nameless Places"] = "Des lieux sans nom",
        ["Second Hall Camp-site"] = "Campement de la Seconde salle",
        ["Sudultirh Outpost"] = "Avant-poste de Sudulthurkh",
        ["Sudulthurkh Outpost"] = "Avant-poste de Sudulthurkh",
        ["The Deep Descent"] = "Longue Descente",
        ["Tharakh Bazan"] = "Tharâkh Bazân",
        ["Jazargund"] = "Jazârgund",
        ["King's Crossing"] = "Carrefour du roi - Trajet en bateau",
        ["Trader's Wharf"] = "Quai des négociants - Trajet en bateau",
        ["Court of Celeborn"] = "Cour de Celeborn",
        ["The Vineyards of Lorien"] = "Les Vignes de la Lórien",
        ["Blazon of the Great Alliance"] = "Blason de la Grande Alliance",
        ["Blazon of the Last Alliance"] = "Blason de la dernière Alliance",
    }

    if type(TR_LocFR) == "table" then
        for en,fr in pairs(TR_OfficialLocRaw or {}) do TR_LocFR[en] = CleanOfficial(fr) end

        local function applyLocation(name)
            if type(name) ~= "string" then return end
            local base = string.match(name, "^(.-)(%([A-Z]+%))$")
            base = base or name
            local key = OfficialNorm(base)
            local fr = key and OfficialLoc[key] or nil
            if not fr then
                local noThe = string.gsub(base, "^The%s+", "")
                if noThe ~= base then
                    local noTheKey = OfficialNorm(noThe)
                    fr = noTheKey and OfficialLoc[noTheKey] or nil
                end
            end
            if fr then TR_LocFR[base] = fr end
        end

        if type(Locs) == "table" then
            for en in pairs(Locs) do applyLocation(en) end
        end
        if type(R_Dest) == "table" then
            for en in pairs(R_Dest) do applyLocation(en) end
        end
        for en,fr in pairs(LegacyOfficial) do TR_LocFR[en] = CleanOfficial(fr) end

        TR_LocFR["Lothlorien(B)"] = "Quais de la Lothlorien(B)"

        TR_LocEN = {}
        if type(Locs) == "table" then
            for en in pairs(Locs) do TR_LocEN[TR_LocName(en)] = en end
        end
        if type(R_Dest) == "table" then
            for en in pairs(R_Dest) do TR_LocEN[TR_LocName(en)] = en end
        end
    end

    if type(TR_ZoneFR) == "table" then
        local function applyZone(en)
            if type(en) ~= "string" then return end
            local lookup = ZoneAliases[en] or en
            local key = OfficialNorm(lookup)
            local fr = key and OfficialZone[key] or nil
            if fr then TR_ZoneFR[en] = CleanOfficial(fr)
            elseif TR_ZoneFR[en] == nil then TR_ZoneFR[en] = en end
        end
        for en in pairs(TR_ZoneFR) do applyZone(en) end
        if type(zones) == "table" then
            for _,en in ipairs(zones) do applyZone(en) end
        end
        if type(Zones) == "table" then
            for en in pairs(Zones) do applyZone(en) end
        end
        TR_ZoneEN = {}
        for en,fr in pairs(TR_ZoneFR) do
            if TR_ZoneEN[fr] == nil then TR_ZoneEN[fr] = en end
        end
    end

    -- Keep internal area keys immutable; translate display/reverse lookup only.
    if type(Areas) == "table" then
        TR_AreaFR = {}
        TR_AreaEN = {}
        for area in pairs(Areas) do
            local key = OfficialNorm(area)
            local fr = CleanOfficial((key and OfficialArea[key]) or area)
            TR_AreaFR[area] = fr
            if TR_AreaEN[fr] == nil then TR_AreaEN[fr] = area end
        end

        function TR_AreaName(name) return TR_AreaFR[name] or name end
        function TR_AreaKey(name) return TR_AreaEN[name] or name end
    end
end)

if not TR_OfficialOK and Turbine and Turbine.Shell then
    Turbine.Shell.WriteLine("<rgb=#FF6040>TravelRef FR officiel désactivé : "..tostring(TR_OfficialError).."</rgb>")
end
