-- TravelRef official French LOTRO display layer.
-- coding: utf-8 'ä
--
-- This layer only updates TravelRef's existing TR_LocFR / TR_ZoneFR tables.
-- It does not replace TR_LocName / TR_ZoneName, so the original routing and
-- UI code keep working exactly as before.
-- Any localization error is contained with pcall so it can never prevent
-- TravelRef itself from loading.

local function TR_OfficialSafeImport(moduleName)
    local ok = pcall(import, moduleName)
    return ok
end

local TR_OfficialOK, TR_OfficialError = pcall(function()
    TR_OfficialSafeImport("Dusk.TravelRef.Common.noAccent")

    TR_OfficialZoneRaw = {}
    TR_OfficialLocRaw = {}
    TR_OfficialAreaRaw = {}
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data1")
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data2")
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data3")
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data4")
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Data5")
    -- Generated from travelsMap + travelsWeb + dungeons + landmarks + geoAreas.
    -- SafeImport keeps TravelRef loadable even if this optional generated file
    -- is absent or malformed.
    TR_OfficialSafeImport("Dusk.TravelRef.TR_OfficialFR_Auto")

    -- Fallback local: LOTRO/Turbine Lua peut parfois ne pas charger noAccent
    -- assez tôt. On garde donc ici les caractères utiles pour comparer les
    -- vieilles clés TravelRef aux libellés officiels modernes.
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
        ["ý"]="y", ["ÿ"]="y", ["Ý"]="Y",
        ["œ"]="oe", ["Œ"]="OE",
    }

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
            local key = OfficialNorm(value)
            if key and key ~= "" then exact[key] = fr end
        end

        local function addAlias(value, fr)
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

    local ZoneAliases = {
        ["Great River"] = "The Great River",
        ["West Rohan"] = "Western Rohan",
        ["East Gondor"] = "Eastern Gondor",
        ["West Gondor"] = "Western Gondor",
        ["Valley of Ikorbad"] = "Valley of Ikorbân",
    }

    -- Anciennes clés TravelRef encore utilisées par l'addon mais absentes ou
    -- orthographiées différemment dans travelsMap.xml. Les valeurs ci-dessous
    -- viennent des tables FR officielles LOTRO (travelsWeb/dungeons) ou de
    -- libellés français vérifiés du client/notes officielles.
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
        local function applyLocation(name)
            if type(name) ~= "string" then return end
            local base = string.match(name, "^(.-)(%([A-Z]+%))$")
            base = base or name

            local key = OfficialNorm(base)
            local fr = key and OfficialLoc[key] or nil

            -- TravelRef a parfois ajouté/supprimé un article par rapport au
            -- client (ex. "The Deep Descent" / "Deep Descent").
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

        for en,fr in pairs(LegacyOfficial) do
            TR_LocFR[en] = fr
        end

        -- Le nœud bateau de Lothlórien a une désignation officielle dédiée.
        TR_LocFR["Lothlorien(B)"] = "Quais de la Lothlorien(B)"

        -- Rebuild the reverse lookup used when a French menu entry is chosen.
        TR_LocEN = {}
        if type(Locs) == "table" then
            for en in pairs(Locs) do TR_LocEN[TR_LocName(en)] = en end
        end
        if type(R_Dest) == "table" then
            for en in pairs(R_Dest) do TR_LocEN[TR_LocName(en)] = en end
        end
    end

    if type(TR_ZoneFR) == "table" then
        for en in pairs(TR_ZoneFR) do
            local lookup = ZoneAliases[en] or en
            local key = OfficialNorm(lookup)
            local fr = key and OfficialZone[key] or nil
            if fr then TR_ZoneFR[en] = fr end
        end

        TR_ZoneEN = {}
        for en,fr in pairs(TR_ZoneFR) do TR_ZoneEN[fr] = en end
    end
end)

-- Never let the optional localization layer break the addon. If something
-- goes wrong, TravelRef simply keeps its previous/manual French names.
if not TR_OfficialOK and Turbine and Turbine.Shell then
    Turbine.Shell.WriteLine("<rgb=#FF6040>TravelRef FR officiel désactivé : "..tostring(TR_OfficialError).."</rgb>")
end
