-- Bouton flottant pour Travel Ref.
-- Clic gauche : afficher/masquer la fenêtre principale.
-- Glisser-déposer : déplacer l’icône. Sa position est mémorisée.
-- La position utilise un fichier de réglages dédié, par personnage, comme les addons Homeopatix.

import "Turbine.UI"
import "Dusk.TravelRef.TR_OfficialFR"

local LAUNCHER_SETTINGS = "TravelRef_Launcher"
local launcherSaved = Dusk.TravelRef.Common.PluginDataLoad(Turbine.DataScope.Character, LAUNCHER_SETTINGS)

TR_Launcher = Turbine.UI.Window()
TR_Launcher:SetSize(32, 32)
TR_Launcher:SetBackground("Dusk/TravelRef/Stable.tga")
TR_Launcher:SetOpacity(1.0)
TR_Launcher:SetZOrder(0) -- couche normale : les panneaux natifs LOTRO (carte, etc.) passent devant

-- Migration : reprend l’ancienne position si elle avait déjà été enregistrée dans TravelRef_Opt.
local launcherPos
if type(launcherSaved) == "table" and tonumber(launcherSaved.x) and tonumber(launcherSaved.y) then
    launcherPos = { x = tonumber(launcherSaved.x), y = tonumber(launcherSaved.y) }
elseif TR_Opt and type(TR_Opt.launcher) == "table" and tonumber(TR_Opt.launcher.x) and tonumber(TR_Opt.launcher.y) then
    launcherPos = { x = tonumber(TR_Opt.launcher.x), y = tonumber(TR_Opt.launcher.y) }
else
    launcherPos = {
        x = math.max(0, Turbine.UI.Display.GetWidth() - 52),
        y = math.floor(Turbine.UI.Display.GetHeight() / 2 - 16)
    }
end

local function clampPosition(x, y)
    local maxX = math.max(0, Turbine.UI.Display.GetWidth() - TR_Launcher:GetWidth())
    local maxY = math.max(0, Turbine.UI.Display.GetHeight() - TR_Launcher:GetHeight())
    x = math.max(0, math.min(maxX, tonumber(x) or 0))
    y = math.max(0, math.min(maxY, tonumber(y) or 0))
    return math.floor(x + 0.5), math.floor(y + 0.5)
end

local function rememberPosition(saveNow)
    local x, y = TR_Launcher:GetPosition()
    x, y = clampPosition(x, y)
    TR_Opt.launcher = { x = x, y = y }
    if saveNow then
        Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Character, LAUNCHER_SETTINGS, { x = x, y = y })
    end
end

launcherPos.x, launcherPos.y = clampPosition(launcherPos.x, launcherPos.y)
TR_Launcher:SetPosition(launcherPos.x, launcherPos.y)
TR_Launcher:SetVisible(true)

-- Exposé au module principal afin de sauvegarder aussi à la déconnexion / au déchargement.
TR_Launcher.SavePosition = function()
    rememberPosition(true)
end

local mouseDown = false
local moved = false
local startMouseX, startMouseY = 0, 0
local startLeft, startTop = 0, 0

TR_Launcher.MouseEnter = function(sender, args)
    sender:SetOpacity(1.0)
end

TR_Launcher.MouseLeave = function(sender, args)
    if not mouseDown then sender:SetOpacity(1.0) end
end

TR_Launcher.MouseDown = function(sender, args)
    if args.Button ~= Turbine.UI.MouseButton.Left then return end
    mouseDown = true
    moved = false
    startMouseX = Turbine.UI.Display.GetMouseX()
    startMouseY = Turbine.UI.Display.GetMouseY()
    startLeft, startTop = sender:GetPosition()
end

TR_Launcher.MouseMove = function(sender, args)
    if not mouseDown then return end

    local mx = Turbine.UI.Display.GetMouseX()
    local my = Turbine.UI.Display.GetMouseY()
    local dx = mx - startMouseX
    local dy = my - startMouseY

    if math.abs(dx) > 3 or math.abs(dy) > 3 then moved = true end
    if not moved then return end

    local x, y = clampPosition(startLeft + dx, startTop + dy)
    sender:SetPosition(x, y)

    -- Garde en mémoire la dernière position même si MouseUp n’est pas reçu par LOTRO.
    rememberPosition(false)
end

TR_Launcher.MouseUp = function(sender, args)
    if args.Button ~= Turbine.UI.MouseButton.Left or not mouseDown then return end
    mouseDown = false
    sender:SetOpacity(1.0)

    if moved then
        rememberPosition(true)
        return
    end

    if TR_window:IsVisible() then
        TR_window:SetVisible(false)
    else
        TR_window.level:SetText(plevel)
        TR_window:SetVisible(true)
        TR_window:SetZOrder(0)
    end
end
