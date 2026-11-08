-- Albis Minimap Buttons
-- Sammelt Minimap-Buttons (LibDBIcon + andere) und zeigt sie in einem
-- scrollbaren Dropdown-Menue unter einem einzigen Anker-Button an.

local ADDON, ns = ...
local TR = ns.L
local AMB = CreateFrame("Frame", "AlbisMinimapButtonsCore")

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------
local DEFAULTS = {
    rowsCompact  = 5,     -- sichtbare Eintraege (kompakt)
    rowsExpanded = 10,    -- sichtbare Eintraege (erweitert)
    expanded     = false,
    delay        = 5,     -- Sekunden bis zum Schliessen nach Verlassen
    offset       = 0,     -- letzte Scroll-Position
    width        = 320,
    point        = nil,   -- { point, relPoint, x, y }
    ignore       = {},    -- Frame-Namen, die nicht eingesammelt werden
    theme        = "dark",
    custom       = {},    -- eigene Anpassungen am Design
    anchorIcon   = nil,   -- nil = eigenes Logo
    anchorSize   = 40,
    anchorGlow   = true,
}

local ROW_HEIGHT    = 58
local ICON_SIZE     = 34
local HEADER_HEIGHT = 26
local PADDING       = 8
local DESC_LINES    = 3
local MIN_WIDTH, MAX_WIDTH = 220, 600
local MAX_ROWS      = 20

local db
local entries = {}      -- { btn=, name=, kind="ldb"|"frame", ldbName=, iconTex=, desc= }
local grabbed = {}      -- btn -> entry
local rows = {}

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

-- MouseIsOver gibt es nicht in jedem Client (z. B. WoW Forever)
local MouseIsOver = MouseIsOver or function(f)
    return f and f:IsVisible() and f:IsMouseOver() or false
end

local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
AMB.version = VERSION
local GetNumAddOns  = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
local GetAddOnInfo  = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo

------------------------------------------------------------------------
-- Designs
------------------------------------------------------------------------
local FLAT = "Interface\\Buttons\\WHITE8X8"
local TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_EDGE = "Interface\\DialogFrame\\UI-DialogBox-Border"
local LOGO = "Interface\\AddOns\\AlbisMinimapButtons\\Media\\Logo"
local GLOW = "Interface\\AddOns\\AlbisMinimapButtons\\Media\\Glow"
local ANCHOR_ICONS = {
    LOGO,
    "Interface\\Icons\\INV_Misc_Gear_01",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\INV_Gizmo_02",
    "Interface\\Icons\\INV_Misc_Book_09",
    "Interface\\Icons\\INV_Misc_Note_01",
    "Interface\\Icons\\INV_Misc_Map_01",
    "Interface\\Icons\\INV_Misc_Spyglass_03",
    "Interface\\Icons\\INV_Misc_Bag_10",
    "Interface\\Icons\\INV_Misc_Key_03",
    "Interface\\Icons\\INV_Misc_Rune_01",
    "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    "Interface\\Icons\\Spell_Holy_MagicalSentry",
    "Interface\\Icons\\Spell_Arcane_TeleportStormWind",
    "Interface\\Icons\\Spell_Nature_StarFall",
    "Interface\\Icons\\Ability_Hunter_Pathfinding",
    "Interface\\Icons\\INV_Misc_Orb_02",
    "Interface\\Icons\\INV_Enchant_EssenceCosmicGreater",
    "Interface\\Icons\\INV_Misc_QuestionMark",
    "Interface\\Icons\\Spell_Shadow_Teleport",
}

-- Setzt ein Icon; WoW-Icons werden leicht beschnitten (eckig, ohne Rand)
local function SetIconTexture(tex, path)
    tex:SetTexture(path)
    if path:lower():find("^interface\\icons\\") then
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local DEFAULT_FONT = (GameFontNormal and GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"

local PRESETS = {
    { key = "dark", name = TR.THEME_DARK,
      bg = FLAT, edge = FLAT, edgeSize = 1, glow = true, iconBorder = true,
      bgColor = { 0.06, 0.06, 0.08, 0.96 }, borderColor = { 0, 0, 0, 1 },
      headerTex = FLAT, headerColor = { 0.11, 0.11, 0.15, 1 }, accent = { 0.25, 0.65, 1 } },
    { key = "class", name = TR.THEME_CLASS,
      bg = FLAT, edge = FLAT, edgeSize = 1, glow = true, iconBorder = true,
      bgColor = { 0.07, 0.07, 0.07, 0.95 }, borderColor = { 0, 0, 0, 1 },
      headerTex = FLAT, headerColor = { 0.13, 0.13, 0.13, 1 }, accent = "class" },
    { key = "glass", name = TR.THEME_GLASS,
      bg = FLAT, edge = FLAT, edgeSize = 1, glow = true, iconBorder = true,
      bgColor = { 0.08, 0.10, 0.14, 0.55 }, borderColor = { 1, 1, 1, 0.18 },
      headerTex = FLAT, headerColor = { 1, 1, 1, 0.06 }, accent = { 0.35, 1, 0.8 } },
    { key = "blood", name = TR.THEME_BLOOD,
      bg = FLAT, edge = FLAT, edgeSize = 1, glow = true, iconBorder = true,
      bgColor = { 0.10, 0.03, 0.03, 0.95 }, borderColor = { 0.35, 0.05, 0.05, 1 },
      headerTex = FLAT, headerColor = { 0.22, 0.04, 0.04, 1 }, accent = { 1, 0.3, 0.2 } },
    { key = "classic", name = TR.THEME_CLASSIC,
      bg = TOOLTIP_BG, edge = TOOLTIP_EDGE, edgeSize = 16, iconBorder = false,
      bgColor = { 0.05, 0.05, 0.05, 0.92 }, borderColor = { 0.8, 0.8, 0.8, 1 },
      headerTex = FLAT, headerColor = { 1, 1, 1, 0.06 }, accent = { 1, 0.82, 0 } },
    { key = "dialog", name = TR.THEME_DIALOG,
      bg = DIALOG_BG, edge = DIALOG_EDGE, edgeSize = 24, iconBorder = true,
      bgColor = { 1, 1, 1, 1 }, borderColor = { 1, 1, 1, 1 },
      headerTex = FLAT, headerColor = { 0, 0, 0, 0.35 }, accent = { 1, 0.82, 0 } },
}
local PRESET_BY_KEY = {}
for _, p in ipairs(PRESETS) do PRESET_BY_KEY[p.key] = p end

local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return { c.r, c.g, c.b } end
    return { 1, 0.82, 0 }
end

-- Fertiges Design: Vorlage + eigene Anpassungen
local function BuildTheme(presetKey, custom)
    local base = PRESET_BY_KEY[presetKey] or PRESETS[1]
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    if custom then for k, v in pairs(custom) do t[k] = v end end
    if t.accent == "class" then t.accent = ClassColor() end
    t.font = t.font or DEFAULT_FONT
    t.fontSize = t.fontSize or 12
    t.nameColor = t.nameColor or { 1, 0.82, 0 }
    t.descColor = t.descColor or { 0.82, 0.82, 0.82 }
    t.inset = math.max(1, math.floor((t.edgeSize or 1) / 4 + 0.5))
    return t
end

local function SafeSetFont(fs, path, size, flags)
    if not (path and fs:SetFont(path, size, flags or "")) then
        fs:SetFont(DEFAULT_FONT, size, flags or "")
    end
end

local function MakeBackdrop(bg, edge, edgeSize)
    local ins = math.max(1, math.floor((edgeSize or 1) / 4 + 0.5))
    return {
        bgFile = bg, edgeFile = edge, edgeSize = edgeSize,
        tile = bg ~= FLAT, tileSize = 16,
        insets = { left = ins, right = ins, top = ins, bottom = ins },
    }
end

-- SharedMedia (falls vorhanden) + eingebaute Auswahl
local BUILTIN_MEDIA = {
    background = { { TR.MEDIA_FLAT, FLAT }, { "Tooltip", TOOLTIP_BG }, { "Dialog", DIALOG_BG } },
    border     = { { TR.MEDIA_NONE, "Interface\\None" }, { "Pixel", FLAT }, { "Tooltip", TOOLTIP_EDGE }, { "Dialog", DIALOG_EDGE } },
    statusbar  = { { TR.MEDIA_FLAT, FLAT }, { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" } },
    font       = { { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" }, { "Arial Narrow", "Fonts\\ARIALN.TTF" },
                   { "Morpheus", "Fonts\\MORPHEUS.TTF" }, { "Skurri", "Fonts\\skurri.ttf" } },
}

-- Mitgelieferte Schriften (SIL Open Font License, siehe Licenses\\FONTS.txt)
local FONT_DIR = "Interface\\AddOns\\AlbisMinimapButtons\\Fonts\\"
local BUNDLED_FONTS = {
    { "Roboto", "Roboto-Regular.ttf", true },
    { "Roboto Bold", "Roboto-Bold.ttf", true },
    { "Roboto Condensed", "RobotoCondensed-Regular.ttf", true },
    { "PT Sans Narrow", "PTSansNarrow-Regular.ttf", true },
    { "Open Sans", "OpenSans-Regular.ttf", true },
    { "Lato", "Lato-Regular.ttf", false },
    { "Fira Sans", "FiraSans-Regular.ttf", true },
    { "Oswald", "Oswald-Regular.ttf", true },
    { "Montserrat", "Montserrat-Regular.ttf", true },
    { "Noto Sans", "NotoSans-Regular.ttf", true },
    { "Exo 2", "Exo2-Regular.ttf", true },
    { "Rubik", "Rubik-Regular.ttf", true },
}
for _, f in ipairs(BUNDLED_FONTS) do
    table.insert(BUILTIN_MEDIA.font, { f[1], FONT_DIR .. f[2] })
end

-- Schriften auch bei SharedMedia anmelden, damit andere Addons sie nutzen koennen
local function RegisterFontsWithLSM()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return end
    local western = LSM.LOCALE_BIT_western or 128
    local cyrillic = LSM.LOCALE_BIT_ruRU or 0
    for _, f in ipairs(BUNDLED_FONTS) do
        LSM:Register("font", f[1], FONT_DIR .. f[2], f[3] and (western + cyrillic) or western)
    end
end

local function MediaList(kind)
    local items = {}
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local seen = {}
    if LSM then
        for _, name in ipairs(LSM:List(kind)) do
            local path = LSM:Fetch(kind, name, true)
            if path then
                items[#items + 1] = { name = name, value = path }
                seen[name] = true
            end
        end
    end
    for _, b in ipairs(BUILTIN_MEDIA[kind] or {}) do
        if not seen[b[1]] then items[#items + 1] = { name = b[1], value = b[2] } end
    end
    table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
    return items
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffAlbisMinimapButtons|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Unsichtbarer Halter fuer die Original-Buttons
-- (bleiben "shown", damit Tooltips/Menues korrekt verankert werden,
--  sind aber durch Alpha 0 unsichtbar und nicht anklickbar)
------------------------------------------------------------------------
local holder = CreateFrame("Frame", "AlbisMinimapButtonsHolder", UIParent)
holder:SetSize(1, 1)
holder:SetPoint("CENTER")
holder:SetAlpha(0)
holder:EnableMouse(false)

-- Blizzard-eigene Frames an der Minimap, die nie eingesammelt werden
local BLIZZARD = {
    MinimapBackdrop = true, MinimapZoomIn = true, MinimapZoomOut = true,
    MiniMapTracking = true, MiniMapTrackingButton = true, MiniMapTrackingFrame = true,
    MiniMapMailFrame = true, MiniMapWorldMapButton = true, MinimapToggleButton = true,
    MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, MiniMapMeetingStoneFrame = true,
    MiniMapVoiceChatFrame = true, GameTimeFrame = true, TimeManagerClockButton = true,
    MiniMapInstanceDifficulty = true, GuildInstanceDifficulty = true,
    MiniMapChallengeMode = true, QueueStatusMinimapButton = true,
    GarrisonLandingPageMinimapButton = true, ExpansionLandingPageMinimapButton = true,
    AddonCompartmentFrame = true, MinimapZoneTextButton = true, MinimapNorthTag = true,
    MinimapCompassTexture = true, MiniMapRecordingButton = true, LFGMinimapFrame = true,
    MinimapCluster = true, Minimap = true, MinimapBorder = true, MinimapBorderTop = true,
    AlbisMinimapButtonsAnchor = true,
    -- moderne Clients (Retail / WoW Forever)
    QueueStatusButton = true, MiniMapCraftingOrderFrame = true, MinimapClusterTracking = true,
    MinimapClusterIndicatorFrame = true, MiniMapMailIcon = true,
}

-- Namensmuster von Kartenpins etc., die keine Minimap-Buttons sind
local IGNORE_PATTERNS = { "Pin", "QuestieFrame", "TomTom", "HereBeDragons", "Arrow", "Node", "POI" }

------------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------------
local addonTitles
local function AddonTitleFor(name)
    if not addonTitles then
        addonTitles = {}
        if GetNumAddOns and GetAddOnInfo then
            for i = 1, GetNumAddOns() do
                local n, title = GetAddOnInfo(i)
                if n then
                    title = (title or n):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    addonTitles[n:lower()] = title
                end
            end
        end
    end
    return addonTitles[name:lower()]
end

local function CleanFrameName(name)
    local n = name
    n = n:gsub("^LibDBIcon10_", "")
    n = n:gsub("[_%-]?[Mm]ini[Mm]ap[_%-]?[Bb]utton%d*", "")
    n = n:gsub("[_%-]?[Mm]ini[Mm]ap[_%-]?[Ii]con", "")
    n = n:gsub("[_%-]?[Mm]ini[Mm]ap", "")
    n = n:gsub("[_%-]?[Bb]utton%d*$", "")
    n = n:gsub("[_%-]?Frame$", "")
    n = n:gsub("[_%-]?Launcher$", "")
    if n == "" then n = name end
    return AddonTitleFor(n) or (n:gsub("(%l)(%u)", "%1 %2"))
end

local function IsJunkPath(path)
    if type(path) ~= "string" then return false end
    path = path:lower()
    return path:find("border") or path:find("background") or path:find("highlight")
        or path:find("trackingborder") or path:find("ui%-minimap")
end

-- Sucht die eigentliche Icon-Textur eines fremden Buttons
local function FindIconTexture(btn)
    local name = btn:GetName()
    local cands = { btn.icon, btn.Icon, name and _G[name .. "Icon"], name and _G[name .. "Texture"] }
    for i = 1, 4 do
        local t = cands[i]
        if type(t) == "table" and t.GetObjectType and t:GetObjectType() == "Texture" and t:GetTexture() then
            return t
        end
    end
    local bw = btn:GetWidth() or 32
    local best, bestScore
    for _, r in ipairs({ btn:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local path = r:GetTexture()
            local layer = r:GetDrawLayer()
            local w = r:GetWidth() or 0
            if path and layer ~= "HIGHLIGHT" and not IsJunkPath(path) and w <= bw * 1.3 then
                local score = (layer == "ARTWORK" and 3) or (layer == "BORDER" and 2) or 1
                if not bestScore or score > bestScore then best, bestScore = r, score end
            end
        end
    end
    if best then return best end
    local nt = btn.GetNormalTexture and btn:GetNormalTexture()
    if nt and nt:GetTexture() then return nt end
end

-- GetScript wirft einen Fehler, wenn der Frame-Typ das Skript nicht kennt
-- (z.B. "OnClick" bei einem normalen Frame) – daher vorher pruefen
local function GetScriptSafe(f, script)
    if f and f.HasScript and f:HasScript(script) then
        return f:GetScript(script)
    end
end

local function Call(func, ...)
    if not func then return end
    local args = { ... }
    local n = select("#", ...)
    xpcall(function() func(unpack(args, 1, n)) end, geterrorhandler())
end

------------------------------------------------------------------------
-- Buttons einsammeln
------------------------------------------------------------------------
local function Grab(btn)
    if btn.__ambGrabbing then return end
    btn.__ambGrabbing = true
    if btn:GetParent() ~= holder then btn:SetParent(holder) end
    btn:EnableMouse(false)
    btn.__ambGrabbing = nil
    if not btn.__ambHooked then
        btn.__ambHooked = true
        -- Falls das Addon den Button spaeter wieder umhaengt: zurueckholen
        hooksecurefunc(btn, "SetParent", function(self, parent)
            if grabbed[self] and parent ~= holder then Grab(self) end
        end)
    end
end

local function AddEntry(btn, name, kind, ldbName)
    local e = grabbed[btn]
    if not e then
        e = { btn = btn }
        grabbed[btn] = e
    end
    e.name, e.kind, e.ldbName = name, kind, ldbName
    if kind ~= "ldb" then e.iconTex = e.iconTex or FindIconTexture(btn) end
    Grab(btn)
    entries[#entries + 1] = e
end

local function HasClickHandler(f)
    return GetScriptSafe(f, "OnClick") or GetScriptSafe(f, "OnMouseUp") or GetScriptSafe(f, "OnMouseDown")
end

-- Pfad der Icon-Textur (bei modernen Clients evtl. eine Datei-ID)
local function IconPath(f)
    local tex = FindIconTexture(f)
    if not tex then return end
    local path = tex.GetTextureFilePath and tex:GetTextureFilePath() or tex:GetTexture()
    if type(path) == "string" then return (path:gsub("/", "\\")) end
end

-- Addon-Ordner, aus dem das Icon stammt (z.B. "Guild_Roster_Manager")
local function IconAddonFolder(f)
    local path = IconPath(f)
    return path and path:lower():find("^interface\\addons\\") and path:match("^[^\\]+\\[^\\]+\\([^\\]+)")
end

-- Stammt der Button erkennbar von einem Addon (oder zeigt ein Spiel-Icon)?
-- Blizzards eigene Minimap-Elemente nutzen Interface\Minimap-Texturen.
local function HasAddonIcon(f)
    local path = IconPath(f)
    path = path and path:lower()
    return path and (path:find("^interface\\addons\\") or path:find("^interface\\icons\\")) and true or false
end

local function HasButtonKeyword(lname)
    return lname:find("minimap") or lname:find("button") or lname:find("launcher") or lname:find("icon")
end

-- Ist der Frame als Feld seines Elternframes eingetragen (z.B. Minimap.ZoomIn)?
-- So haengt Blizzard seine eigenen, namenlosen Minimap-Elemente an.
local function IsParentKey(f)
    local key = f.GetParentKey and f:GetParentKey()
    if key then return true end
    local parent = f:GetParent()
    if type(parent) ~= "table" then return false end
    for _, v in pairs(parent) do
        if v == f then return true end
    end
    return false
end

-- Liegt der Frame am Rand der Minimap (wie fast alle Minimap-Buttons)?
-- Kartenpins liegen dagegen meist innerhalb der Karte.
local function IsOnMinimapRim(f)
    if not Minimap then return false end
    local fx, fy = f:GetCenter()
    local mx, my = Minimap:GetCenter()
    if not (fx and mx) then return false end
    local fs, ms = f:GetEffectiveScale(), Minimap:GetEffectiveScale()
    local dx, dy = fx * fs - mx * ms, fy * fs - my * ms
    local dist = math.sqrt(dx * dx + dy * dy)
    local r = (Minimap:GetWidth() or 140) * ms / 2
    -- eckige Minimaps: Ecken liegen bei r * 1.41
    return dist >= r * 0.75 and dist <= r * 1.5 + 40 * fs
end

-- Titel aus dem Tooltip des Buttons (erste Zeile), fuer Buttons ohne Namen
local function TooltipTitle(f)
    local onEnter = GetScriptSafe(f, "OnEnter")
    if not onEnter or not GameTooltip then return end
    GameTooltip:Hide()
    local title
    if pcall(onEnter, f) and GameTooltip:IsShown() then
        local l = _G.GameTooltipTextLeft1
        title = l and l:GetText()
    end
    local onLeave = GetScriptSafe(f, "OnLeave")
    if onLeave then pcall(onLeave, f) end
    GameTooltip:Hide()
    if type(title) == "string" then
        title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):match("^%s*(.-)%s*$")
        if title ~= "" and #title <= 40 then return title end
    end
end

-- strict = true: nur Buttons mit typischem Namen (fuer Frames ausserhalb der Minimap)
local function LooksLikeMinimapButton(f, strict)
    if f.IsForbidden and f:IsForbidden() then return false end
    local name = f:GetName()
    if name and (BLIZZARD[name] or db.ignore[name]) then return false end
    local lname = name and name:lower() or ""
    local strong = lname:find("minimapbutton") or lname:find("minimap_button") or lname:find("^libdbicon")
    if name and not strong then
        for _, p in ipairs(IGNORE_PATTERNS) do
            if name:find(p) then return false end
        end
    end
    local t = f:GetObjectType()
    if t ~= "Button" and t ~= "Frame" and t ~= "CheckButton" then return false end
    if not HasClickHandler(f) then return false end
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w < 16 or w > 60 or h < 16 or h > 60 then return false end
    if name and HasButtonKeyword(lname) then return true end
    if strict then return false end
    -- Ohne typischen Namen (oder ganz ohne Namen, z.B. SpellRank):
    -- Blizzard-Teile der Minimap sind dort als Feld eingetragen
    -- (Minimap.ZoomIn ...), Kartenpins sind kleiner und liegen innen.
    if w < 20 or h < 20 then return false end
    if IsParentKey(f) then return false end
    return IsOnMinimapRim(f) or HasAddonIcon(f)
end

-- Anzeigename fuer einen fremden Button: bevorzugt der Titel des Addons,
-- aus dessen Ordner das Icon stammt
local function NameFor(f)
    local name = f:GetName()
    local okF, folder = pcall(IconAddonFolder, f)
    folder = okF and folder or nil
    local folderTitle = folder and AddonTitleFor(folder)
    if folderTitle then return folderTitle end
    if name then return CleanFrameName(name) end
    local okT, tip = pcall(TooltipTitle, f)
    return (okT and tip) or folder or "Addon"
end

local function SafeLooksLike(f)
    local ok, res = pcall(LooksLikeMinimapButton, f)
    return ok and res
end

-- Frames, an denen Minimap-Buttons direkt haengen
local function MinimapParents()
    return { Minimap, MinimapBackdrop, MinimapCluster }
end

-- Manche Addons (z.B. Guild Roster Manager) haengen ihren Button an
-- UIParent und verankern ihn nur an der Minimap
local function IsAnchoredToMinimap(f)
    if f.IsForbidden and f:IsForbidden() then return false end
    for i = 1, (f:GetNumPoints() or 0) do
        local _, rel = f:GetPoint(i)
        if rel and (rel == Minimap or rel == MinimapBackdrop or rel == MinimapCluster) then
            return true
        end
    end
    return false
end

local function IsUIParentCandidate(f)
    local ok, res = pcall(function() return IsAnchoredToMinimap(f) and LooksLikeMinimapButton(f, true) end)
    return ok and res
end

-- Geschuetzte (forbidden) Blizzard-Frames duerfen von Addons nicht einmal
-- abgefragt werden; jede Pruefung ist daher komplett abgesichert
local function IsForbiddenFrame(f)
    local ok, res = pcall(function() return f.IsForbidden and f:IsForbidden() end)
    return not ok or res
end

local function IsShownCandidate(f, onUIParent)
    if IsForbiddenFrame(f) then return false end
    local ok, res = pcall(function()
        if not f:IsShown() then return false end
        if onUIParent then return IsAnchoredToMinimap(f) and LooksLikeMinimapButton(f, true) end
        return LooksLikeMinimapButton(f)
    end)
    return ok and res
end

local function LDBWanted(ldbName, btn)
    local hidden = btn.db and btn.db.hide
    return not hidden and not db.ignore[ldbName] and not db.ignore[btn:GetName() or ""]
end

-- Fuegt einen Eintrag hinzu; ein fehlerhafter Fremd-Button darf
-- niemals den restlichen Scan abbrechen
local failed = {}       -- btn -> true, Buttons, die sich nicht einsammeln liessen
local function TryAdd(btn, name, kind, ldbName)
    if kind == "frame" and db.ignore[name] then return false end
    local ok = pcall(AddEntry, btn, name, kind, ldbName)
    if not ok then
        failed[btn] = true
        -- halb angelegten Eintrag wieder entfernen
        if entries[#entries] and entries[#entries].btn == btn then entries[#entries] = nil end
    end
    return ok
end

local listed = {}       -- btn -> true, alles was aktuell im Menue steht

local function ScanUnsafe(full)
    wipe(entries)
    wipe(listed)
    local seen = {}

    -- 1) LibDBIcon
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBIcon and LDBIcon.objects then
        for ldbName, btn in pairs(LDBIcon.objects) do
            local ok, wanted = pcall(LDBWanted, ldbName, btn)
            if ok and wanted then TryAdd(btn, ldbName, "ldb", ldbName) end
            -- ausgeblendete LibDBIcon-Buttons auch nicht ueber die Frame-Suche holen
            seen[btn] = true
        end
    end

    -- 2) Andere Buttons direkt an der Minimap
    for _, parent in ipairs(MinimapParents()) do
        if parent then
            for _, f in ipairs({ parent:GetChildren() }) do
                if not seen[f] and (grabbed[f] or IsShownCandidate(f)) then
                    local fname = f:GetName()
                    if not (fname and db.ignore[fname]) then
                        if TryAdd(f, NameFor(f), "frame") then seen[f] = true end
                    end
                end
            end
        end
    end

    -- 3) Buttons an UIParent, die an der Minimap verankert sind
    --    (teurer, daher nur bei vollstaendiger Suche)
    for _, f in ipairs(full and { UIParent:GetChildren() } or {}) do
        if not seen[f] and not grabbed[f] and f ~= holder and IsShownCandidate(f, true) then
            if TryAdd(f, NameFor(f), "frame") then seen[f] = true end
        end
    end

    -- Bereits eingesammelte Buttons haengen jetzt am Halter
    for _, f in ipairs({ holder:GetChildren() }) do
        local e = grabbed[f]
        if e and not seen[f] and e.kind == "frame" and not db.ignore[f:GetName() or ""] and not db.ignore[e.name or ""] then
            entries[#entries + 1] = e
            seen[f] = true
        end
    end

    for _, e in ipairs(entries) do listed[e.btn] = true end
    table.sort(entries, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    if AMB.menu and AMB.menu:IsShown() then AMB:Refresh() end
end

-- Schnelle Pruefung: gibt es einen neuen Button (oder hat sich bei
-- LibDBIcon etwas geaendert), der noch nicht im Menue ist?
local function NeedsRescanUnsafe(full)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBIcon and LDBIcon.objects then
        for ldbName, btn in pairs(LDBIcon.objects) do
            local ok, wanted = pcall(LDBWanted, ldbName, btn)
            if ok and not failed[btn] and (wanted and true or false) ~= (listed[btn] and true or false) then return true end
        end
    end
    for _, parent in ipairs(MinimapParents()) do
        if parent then
            for _, f in ipairs({ parent:GetChildren() }) do
                if not grabbed[f] and not failed[f] and IsShownCandidate(f) then return true end
            end
        end
    end
    if full then
        for _, f in ipairs({ UIParent:GetChildren() }) do
            if not grabbed[f] and not failed[f] and f ~= holder and IsShownCandidate(f, true) then return true end
        end
    end
    return false
end

local function NeedsRescan(full)
    local ok, res = pcall(NeedsRescanUnsafe, full)
    return ok and res
end

-- full = false: nur Minimap und LibDBIcon (guenstig), sonst auch UIParent
function AMB:Scan(full)
    if full == nil then full = true end
    xpcall(function() ScanUnsafe(full) end, geterrorhandler())
end

------------------------------------------------------------------------
-- Anker-Button
------------------------------------------------------------------------
local anchor = CreateFrame("Button", "AlbisMinimapButtonsAnchor", UIParent, BACKDROP_TEMPLATE)
AMB.anchor = anchor
anchor:SetSize(32, 32)
anchor:SetFrameStrata("MEDIUM")
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:RegisterForDrag("LeftButton")
anchor:RegisterForClicks("LeftButtonUp", "RightButtonUp")
-- Leuchten hinter dem Button, damit er im Spielgeschehen auffaellt
local aGlow = anchor:CreateTexture(nil, "BACKGROUND")
aGlow:SetPoint("CENTER")
aGlow:SetTexture(GLOW)
aGlow:SetBlendMode("ADD")
aGlow:SetAlpha(0.75)
-- schwarzer Rand nur fuer eckige Spiel-Icons
local aBorder = anchor:CreateTexture(nil, "BORDER")
aBorder:SetPoint("TOPLEFT", -1, 1)
aBorder:SetPoint("BOTTOMRIGHT", 1, -1)
aBorder:SetColorTexture(0, 0, 0, 1)
local aIcon = anchor:CreateTexture(nil, "ARTWORK")
aIcon:SetAllPoints()
SetIconTexture(aIcon, LOGO)
local aHL = anchor:CreateTexture(nil, "HIGHLIGHT")
aHL:SetAllPoints()
aHL:SetBlendMode("ADD")
aHL:SetAlpha(0.35)

function AMB:ApplyAnchorIcon()
    local size = db.anchorSize or 40
    local path = db.anchorIcon or LOGO
    anchor:SetSize(size, size)
    if anchor.SetBackdrop then anchor:SetBackdrop(nil) end
    SetIconTexture(aIcon, path)
    SetIconTexture(aHL, path)
    aBorder:SetShown(path:lower():find("^interface\\icons\\") and true or false)
    aGlow:SetSize(size * 1.6, size * 1.6)
    aGlow:SetShown(db.anchorGlow and true or false)
end

anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.point = { p, rp, x, y }
    if AMB.menu:IsShown() then AMB:PositionMenu() end
end)
anchor:SetScript("OnClick", function(_, button)
    if button == "RightButton" then AMB:OpenOptions() else AMB:Toggle() end
end)
anchor:SetScript("OnEnter", function(self)
    aGlow:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("Albis Minimap Buttons", "v" .. VERSION, nil, nil, nil, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(TR.TIP_CLICK, 1, 1, 1)
    GameTooltip:AddLine(TR.TIP_RIGHTCLICK, 1, 1, 1)
    GameTooltip:AddLine(TR.TIP_DRAG, 1, 1, 1)
    GameTooltip:AddLine(TR.TIP_SLASH, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
anchor:SetScript("OnLeave", function() aGlow:SetAlpha(0.75); GameTooltip:Hide() end)

local function PlaceAnchor()
    anchor:ClearAllPoints()
    if db.point then
        anchor:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    else
        anchor:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", 10, -10)
    end
end

------------------------------------------------------------------------
-- Tooltip-Text auslesen (wird direkt unter dem Namen angezeigt)
------------------------------------------------------------------------
local scanTip = CreateFrame("GameTooltip", "AlbisMinimapButtonsScanTip", UIParent, "GameTooltipTemplate")

local function ColorWrap(fs, text)
    local r, g, b = fs:GetTextColor()
    if not r then return text end
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

local function ReadTooltip(tip)
    local prefix = tip:GetName()
    local lines = {}
    for i = 2, tip:NumLines() do -- Zeile 1 ist der Titel (= Addon-Name)
        local l = _G[prefix .. "TextLeft" .. i]
        local r = _G[prefix .. "TextRight" .. i]
        local lt = l and l:GetText()
        local rt = r and r:IsShown() and r:GetText()
        if lt == "" then lt = nil end
        if rt == "" then rt = nil end
        if lt or rt then
            local s = lt and ColorWrap(l, lt) or ""
            if rt then s = s .. (lt and "  " or "") .. ColorWrap(r, rt) end
            lines[#lines + 1] = s
        end
    end
    if #lines > 0 then return table.concat(lines, "\n") end
end

local DESC_TTL = 3 -- Sekunden, die ein ausgelesener Text zwischengespeichert wird

local function FetchDescription(e, anchorRegion)
    local now = GetTime()
    if e.descTime and now - e.descTime < DESC_TTL then return e.desc end
    e.descTime = now
    local desc
    local b = e.btn
    local obj = e.kind == "ldb" and b.dataObject
    if obj and obj.OnTooltipShow then
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        if pcall(obj.OnTooltipShow, scanTip) then desc = ReadTooltip(scanTip) end
        scanTip:Hide()
    else
        local onEnter = GetScriptSafe(b, "OnEnter")
        if onEnter then
            b:ClearAllPoints()
            b:SetPoint("CENTER", anchorRegion, "CENTER")
            GameTooltip:Hide()
            if pcall(onEnter, b) and GameTooltip:IsShown() then desc = ReadTooltip(GameTooltip) end
            local onLeave = GetScriptSafe(b, "OnLeave")
            if onLeave then pcall(onLeave, b) end
            GameTooltip:Hide()
        end
    end
    e.desc = desc
    return desc
end

------------------------------------------------------------------------
-- Dropdown-Menue
------------------------------------------------------------------------
local ACCENT = { 0.25, 0.65, 1.0 }

local menu = CreateFrame("Frame", "AlbisMinimapButtonsMenu", UIParent, BACKDROP_TEMPLATE)
AMB.menu = menu
menu:Hide()
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:EnableMouseWheel(true)
if menu.SetBackdrop then
    menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    menu:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
    menu:SetBackdropBorderColor(0, 0, 0, 1)
end
-- feiner innerer Rahmen
local inner = menu:CreateTexture(nil, "BORDER")
inner:SetPoint("TOPLEFT", 1, -1)
inner:SetPoint("BOTTOMRIGHT", -1, 1)
inner:SetColorTexture(1, 1, 1, 0.03)

-- Kopfzeile
local header = CreateFrame("Frame", nil, menu)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(HEADER_HEIGHT)
local headerBG = header:CreateTexture(nil, "BACKGROUND")
headerBG:SetAllPoints()
headerBG:SetColorTexture(0.11, 0.11, 0.15, 1)
local headerLine = header:CreateTexture(nil, "ARTWORK")
headerLine:SetPoint("BOTTOMLEFT")
headerLine:SetPoint("BOTTOMRIGHT")
headerLine:SetHeight(1)
headerLine:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", PADDING + 2, 0)
title:SetText("Minimap Buttons")
local count = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
count:SetPoint("LEFT", title, "RIGHT", 6, 0)

local expandBtn = CreateFrame("Button", nil, header)
expandBtn:SetSize(16, 16)
expandBtn:SetPoint("RIGHT", -PADDING, 0)
expandBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
expandBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(db.expanded and TR.TIP_COMPACT or TR.TIP_MORE)
    GameTooltip:AddLine(TR.TIP_RESIZE, 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
expandBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateExpandButton()
    local kind = db.expanded and "Minus" or "Plus"
    expandBtn:SetNormalTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Up")
    expandBtn:SetPushedTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Down")
end

local list = CreateFrame("Frame", nil, menu)
list:SetPoint("TOPLEFT", 1, -1 - HEADER_HEIGHT)
list:SetPoint("BOTTOMRIGHT", -1, 1)

local track = list:CreateTexture(nil, "BACKGROUND")
track:SetColorTexture(1, 1, 1, 0.05)
track:SetWidth(3)
track:SetPoint("TOPRIGHT", -3, -4)
track:SetPoint("BOTTOMRIGHT", -3, 4)
local thumb = list:CreateTexture(nil, "ARTWORK")
thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
thumb:SetWidth(3)

local emptyText = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("CENTER")
emptyText:SetText(TR.EMPTY)

local function NumRows()
    return db.expanded and db.rowsExpanded or db.rowsCompact
end

local function SetNumRows(n)
    if db.expanded then db.rowsExpanded = n else db.rowsCompact = n end
end

local function MaxOffset()
    return math.max(0, #entries - NumRows())
end

local function Scroll(delta)
    local new = math.min(MaxOffset(), math.max(0, db.offset - delta))
    if new ~= db.offset then
        db.offset = new
        AMB:Refresh()
    end
end
menu:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)

local function Row_OnClick(row, mouseButton)
    local e = row.entry
    if not e then return end
    local b = e.btn
    -- Original an die Zeile haengen, damit Menues des Addons hier aufgehen
    b:ClearAllPoints()
    b:SetPoint("CENTER", row.icon, "CENTER")
    local onClick = GetScriptSafe(b, "OnClick")
    if onClick then
        Call(onClick, b, mouseButton, false)
    else
        Call(GetScriptSafe(b, "OnMouseDown"), b, mouseButton)
        Call(GetScriptSafe(b, "OnMouseUp"), b, mouseButton)
    end
    -- Text kann sich durch den Klick aendern (z.B. an/aus)
    e.descTime = nil
    if C_Timer then C_Timer.After(0.3, function() if menu:IsShown() then AMB:Refresh() end end) end
end

local function CreateRow(i)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)

    local hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl = hl
    hl:SetAllPoints()
    hl:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12)
    hl:Hide()
    local bar = row:CreateTexture(nil, "ARTWORK")
    row.bar = bar
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(2)
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    bar:Hide()
    row.sep = row:CreateTexture(nil, "BORDER")
    row.sep:SetPoint("BOTTOMLEFT", PADDING, 0)
    row.sep:SetPoint("BOTTOMRIGHT", -PADDING, 0)
    row.sep:SetHeight(1)
    row.sep:SetColorTexture(1, 1, 1, 0.06)

    row:SetScript("OnEnter", function() hl:Show(); bar:Show() end)
    row:SetScript("OnLeave", function() hl:Hide(); bar:Hide() end)
    row:SetScript("OnMouseDown", function() row.icon:SetPoint("LEFT", PADDING + 2, -1) end)
    row:SetScript("OnMouseUp", function() row.icon:SetPoint("LEFT", PADDING + 1, 0) end)

    row.iconBG = row:CreateTexture(nil, "BORDER")
    row.iconBG:SetColorTexture(0, 0, 0, 1)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", PADDING + 1, 0)
    row.iconBG:SetPoint("TOPLEFT", row.icon, -1, 1)
    row.iconBG:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    if row.text.SetWordWrap then row.text:SetWordWrap(false) end

    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.desc:SetJustifyH("LEFT")
    row.desc:SetJustifyV("TOP")
    row.desc:SetTextColor(0.82, 0.82, 0.82)
    row.desc:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
    row.desc:SetPoint("RIGHT", -PADDING - 6, 0)
    row.desc:SetHeight(DESC_LINES * 11 + 1)
    if row.desc.SetWordWrap then row.desc:SetWordWrap(true) end
    if row.desc.SetMaxLines then row.desc:SetMaxLines(DESC_LINES) end

    row:SetScript("OnClick", Row_OnClick)
    AMB:ApplyRowTheme(row)
    rows[i] = row
    return row
end

local function ApplyTexCoord(tex, src)
    local ulx, uly, llx, lly, urx, ury, lrx, lry = src:GetTexCoord()
    if not ulx or (ulx == 0 and uly == 0 and llx == 0 and lly == 1 and urx == 1 and ury == 0 and lrx == 1 and lry == 1) then
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    end
end

local function SetRowIcon(row, e)
    local tex = row.icon
    tex:SetVertexColor(1, 1, 1)
    if e.kind == "ldb" then
        local obj = e.btn.dataObject
        local icon = obj and obj.icon
        tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local c = obj and obj.iconCoords
        if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) else tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        if obj and obj.iconR then tex:SetVertexColor(obj.iconR, obj.iconG or 1, obj.iconB or 1) end
    else
        local src = e.iconTex
        local atlas = src and src.GetAtlas and src:GetAtlas()
        if atlas and tex.SetAtlas then
            tex:SetAtlas(atlas)
        elseif src and src:GetTexture() then
            tex:SetTexture(src:GetTexture())
            ApplyTexCoord(tex, src)
        else
            tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
    end
end

------------------------------------------------------------------------
-- Groesse per Ziehen an der Ecke
------------------------------------------------------------------------
local grip = CreateFrame("Button", nil, menu)
grip:SetSize(16, 16)
grip:SetFrameLevel(menu:GetFrameLevel() + 10)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
local direction = { v = "DOWN", h = "LEFT" }

local function PlaceGrip()
    local corner = (direction.v == "DOWN" and "BOTTOM" or "TOP") .. (direction.h == "LEFT" and "LEFT" or "RIGHT")
    grip:ClearAllPoints()
    grip:SetPoint(corner, menu, corner, direction.h == "LEFT" and 2 or -2, direction.v == "DOWN" and 2 or -2)
    -- Grafik zeigt nach unten rechts; bei Bedarf spiegeln
    local l, r = 0, 1
    local t, b = 0, 1
    if direction.h == "LEFT" then l, r = 1, 0 end
    if direction.v == "UP" then t, b = 1, 0 end
    for _, tex in ipairs({ grip:GetNormalTexture(), grip:GetHighlightTexture(), grip:GetPushedTexture() }) do
        tex:SetTexCoord(l, r, t, b)
    end
end

local function Resize_OnUpdate(self)
    local x, y = GetCursorPosition()
    local s = menu:GetEffectiveScale()
    local dx, dy = (x - self.sx) / s, (y - self.sy) / s
    if direction.h == "LEFT" then dx = -dx end
    if direction.v == "DOWN" then dy = -dy end
    local w = math.floor(math.max(MIN_WIDTH, math.min(MAX_WIDTH, self.sw + dx)))
    local n = math.max(2, math.min(MAX_ROWS, self.sr + math.floor(dy / ROW_HEIGHT + 0.5)))
    if w ~= db.width or n ~= NumRows() then
        db.width = w
        SetNumRows(n)
        AMB:Layout()
        AMB:Refresh()
    end
end

grip:SetScript("OnMouseDown", function(self)
    self.sx, self.sy = GetCursorPosition()
    self.sw, self.sr = db.width, NumRows()
    self.resizing = true
    self:SetScript("OnUpdate", Resize_OnUpdate)
end)
grip:SetScript("OnMouseUp", function(self)
    self.resizing = nil
    self:SetScript("OnUpdate", nil)
end)

------------------------------------------------------------------------
-- Aufbau und Aktualisierung
------------------------------------------------------------------------
function AMB:Layout()
    local n = NumRows()
    local ins = AMB.theme and AMB.theme.inset or 1
    menu:SetSize(db.width, n * ROW_HEIGHT + HEADER_HEIGHT + 2 * ins)
    for i = 1, n do
        local row = rows[i] or CreateRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -8, -(i - 1) * ROW_HEIGHT)
        row.sep:SetShown(i < n)
    end
    for i = n + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
    end
    UpdateExpandButton()
end

function AMB:Refresh()
    local n = NumRows()
    db.offset = math.min(db.offset, MaxOffset())
    for i = 1, n do
        local row = rows[i]
        local e = row and entries[i + db.offset]
        if row then row.entry = e end
        if not row then
            -- Zeile wird erst beim naechsten Layout erzeugt
        elseif e then
            SetRowIcon(row, e)
            row.text:SetText(e.name)
            local desc = FetchDescription(e, row.icon)
            row.text:ClearAllPoints()
            if desc then
                row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 1)
                row.desc:SetText(desc)
                row.desc:Show()
            else
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
                row.desc:Hide()
            end
            row.text:SetPoint("RIGHT", row, "RIGHT", -PADDING, 0)
            row:Show()
        else
            row:Hide()
        end
    end
    emptyText:SetShown(#entries == 0)
    count:SetText("(" .. #entries .. ")")

    local total = #entries
    if total > n then
        local trackH = list:GetHeight() - 8
        local thumbH = math.max(12, trackH * n / total)
        local y = (trackH - thumbH) * db.offset / MaxOffset()
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", -3, -4 - y)
        thumb:SetHeight(thumbH)
        thumb:Show(); track:Show()
    else
        thumb:Hide(); track:Hide()
    end
end

function AMB:PositionMenu()
    menu:ClearAllPoints()
    local scale = anchor:GetEffectiveScale() / menu:GetEffectiveScale()
    local bottom = (anchor:GetBottom() or 500) * scale
    local cx = (anchor:GetCenter() or 0) * scale
    direction.v = (bottom < menu:GetHeight() + 20) and "UP" or "DOWN"
    direction.h = (cx > UIParent:GetWidth() / 2) and "LEFT" or "RIGHT"
    local hSide = direction.h == "LEFT" and "RIGHT" or "LEFT"
    if direction.v == "DOWN" then
        menu:SetPoint("TOP" .. hSide, anchor, "BOTTOM" .. hSide, 0, -3)
    else
        menu:SetPoint("BOTTOM" .. hSide, anchor, "TOP" .. hSide, 0, 3)
    end
    PlaceGrip()
end

function AMB:Open()
    self:Scan()
    for _, e in ipairs(entries) do e.descTime = nil end
    self:Layout()
    self:PositionMenu()
    menu.idle = 0
    menu:Show()
    self:Refresh()
end

function AMB:Toggle()
    if menu:IsShown() then menu:Hide() else self:Open() end
end

expandBtn:SetScript("OnClick", function(self)
    db.expanded = not db.expanded
    AMB:Layout()
    AMB:PositionMenu()
    AMB:Refresh()
    if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
end)

-- Automatisch schliessen, wenn die Maus das Menue laenger verlassen hat
menu:SetScript("OnUpdate", function(self, elapsed)
    if AMB.preview or grip.resizing or MouseIsOver(self) or MouseIsOver(anchor) then
        self.idle = 0
    else
        self.idle = (self.idle or 0) + elapsed
        if self.idle >= db.delay then self:Hide() end
    end
end)
menu:SetScript("OnHide", function()
    grip:GetScript("OnMouseUp")(grip)
end)

------------------------------------------------------------------------
-- Design anwenden
------------------------------------------------------------------------
function AMB:ApplyTheme()
    local t = BuildTheme(db.theme, db.custom)
    AMB.theme = t
    local a = t.accent
    local ins = t.inset

    if menu.SetBackdrop then
        menu:SetBackdrop(MakeBackdrop(t.bg, t.edge, t.edgeSize))
        menu:SetBackdropColor(unpack(t.bgColor))
        menu:SetBackdropBorderColor(unpack(t.borderColor))
    end
    inner:SetShown(t.glow and true or false)
    inner:ClearAllPoints()
    inner:SetPoint("TOPLEFT", ins, -ins)
    inner:SetPoint("BOTTOMRIGHT", -ins, ins)

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", ins, -ins)
    header:SetPoint("TOPRIGHT", -ins, -ins)
    headerBG:SetTexture(t.headerTex or FLAT)
    headerBG:SetVertexColor(unpack(t.headerColor))
    headerLine:SetColorTexture(a[1], a[2], a[3], 0.8)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", ins, -ins - HEADER_HEIGHT)
    list:SetPoint("BOTTOMRIGHT", -ins, ins)
    thumb:SetColorTexture(a[1], a[2], a[3], 0.8)

    local flags = t.outline and "OUTLINE" or ""
    SafeSetFont(title, t.font, t.fontSize + 1, flags)
    title:SetTextColor(unpack(t.nameColor))
    SafeSetFont(count, t.font, t.fontSize - 2, flags)
    SafeSetFont(emptyText, t.font, t.fontSize, flags)

    for _, row in ipairs(rows) do AMB:ApplyRowTheme(row) end


    if db.offset and menu:IsShown() then
        AMB:Layout()
        AMB:Refresh()
    end
end

function AMB:ApplyRowTheme(row)
    local t = AMB.theme
    if not t then return end
    local a = t.accent
    local flags = t.outline and "OUTLINE" or ""
    row.hl:SetColorTexture(a[1], a[2], a[3], 0.14)
    row.bar:SetColorTexture(a[1], a[2], a[3], 1)
    row.iconBG:SetShown(t.iconBorder and true or false)
    SafeSetFont(row.text, t.font, t.fontSize, flags)
    row.text:SetTextColor(unpack(t.nameColor))
    SafeSetFont(row.desc, t.font, math.max(8, t.fontSize - 2), flags)
    row.desc:SetTextColor(unpack(t.descColor))
    row.desc:SetHeight(DESC_LINES * (math.max(8, t.fontSize - 2) + 1) + 1)
end

------------------------------------------------------------------------
-- Live-Vorschau neben dem Optionsfenster
------------------------------------------------------------------------
function AMB:OpenPreview(host)
    self.preview = true
    self:Scan()
    self:Layout()
    menu:ClearAllPoints()
    local right = host:GetRight() or 0
    if right + db.width + 20 < UIParent:GetRight() then
        menu:SetPoint("TOPLEFT", host, "TOPRIGHT", 8, 0)
        direction.h = "RIGHT"
    else
        menu:SetPoint("TOPRIGHT", host, "TOPLEFT", -8, 0)
        direction.h = "LEFT"
    end
    direction.v = "DOWN"
    PlaceGrip()
    menu.idle = 0
    menu:Show()
    self:Refresh()
end

function AMB:ClosePreview()
    if self.preview then
        self.preview = nil
        menu:Hide()
    end
end

------------------------------------------------------------------------
-- Optionsfenster (Interface -> AddOns)
------------------------------------------------------------------------
local panel = CreateFrame("Frame", "AlbisMinimapButtonsOptions", UIParent)
panel.name = "Albis Minimap Buttons"
panel:Hide()
AMB.panel = panel
local widgets = {}

local function Custom()
    return db.custom
end

local function CurrentColor(key)
    local c = AMB.theme[key]
    return c[1], c[2], c[3], c[4] or 1
end

local function Changed()
    AMB:ApplyTheme()
    for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

local function SectionHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
end

-- Schieberegler
local function CreateSlider(parent, label, x, y, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(260, 38)
    f.updating = true -- keine Aenderungen speichern, bevor Refresh lief
    f:SetPoint("TOPLEFT", x, y)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT")
    text:SetText(label)
    local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOPRIGHT")
    local s = CreateFrame("Slider", nil, f, BACKDROP_TEMPLATE)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(12)
    s:SetPoint("TOPLEFT", 0, -16)
    s:SetPoint("TOPRIGHT", 0, -16)
    if s.SetBackdrop then
        s:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        s:SetBackdropColor(0, 0, 0, 0.6)
        s:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    s:SetThumbTexture(FLAT)
    local th = s:GetThumbTexture()
    th:SetSize(8, 12)
    th:SetVertexColor(1, 0.82, 0)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    fmt = fmt or function(v) return tostring(v) end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        val:SetText(fmt(v))
        if not f.updating then set(v) end
    end)
    function f:Refresh()
        self.updating = true
        local v = get()
        s:SetValue(v)
        val:SetText(fmt(v))
        self.updating = nil
    end
    widgets[#widgets + 1] = f
    return f
end

-- Farbfeld mit Farbwaehler
local function OpenColorPicker(r, g, b, callback)
    local function onChange()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        callback(nr, ng, nb)
    end
    local function onCancel() callback(r, g, b) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = onChange, cancelFunc = onCancel,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.func = onChange
        ColorPickerFrame.cancelFunc = onCancel
        ColorPickerFrame.previousValues = { r = r, g = g, b = b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ShowUIPanel(ColorPickerFrame)
    end
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
end

local function CreateColor(parent, label, x, y, key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(260, 22)
    b:SetPoint("TOPLEFT", x, y)
    local border = b:CreateTexture(nil, "BORDER")
    border:SetSize(20, 20)
    border:SetPoint("LEFT")
    border:SetColorTexture(0, 0, 0, 1)
    local sw = b:CreateTexture(nil, "ARTWORK")
    sw:SetPoint("TOPLEFT", border, 2, -2)
    sw:SetPoint("BOTTOMRIGHT", border, -2, 2)
    sw:SetTexture(FLAT)
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", border, "RIGHT", 8, 0)
    text:SetText(label)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    b:SetScript("OnClick", function()
        local r, g, bl, al = CurrentColor(key)
        OpenColorPicker(r, g, bl, function(nr, ng, nb)
            Custom()[key] = { nr, ng, nb, al }
            Changed()
        end)
    end)
    function b:Refresh()
        sw:SetVertexColor(CurrentColor(key))
    end
    widgets[#widgets + 1] = b
    return b
end

local function CreateCheck(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x - 3, y + 2)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function cb:Refresh() self:SetChecked(get() and true or false) end
    widgets[#widgets + 1] = cb
    return cb
end

-- Auswahlliste mit Vorschau (Texturen, Rahmen, Schriften)
local popup = CreateFrame("Frame", "AlbisMinimapButtonsPopup", UIParent, BACKDROP_TEMPLATE)
popup:SetFrameStrata("FULLSCREEN_DIALOG")
popup:SetClampedToScreen(true)
popup:EnableMouse(true)
popup:EnableMouseWheel(true)
popup:Hide()
if popup.SetBackdrop then
    popup:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    popup:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    popup:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
end
local POPUP_ROWS, POPUP_ROW_H = 12, 22
popup.rows = {}
for i = 1, POPUP_ROWS do
    local r = CreateFrame("Button", nil, popup)
    r:SetHeight(POPUP_ROW_H)
    r:SetPoint("TOPLEFT", 3, -3 - (i - 1) * POPUP_ROW_H)
    r:SetPoint("TOPRIGHT", -3, -3 - (i - 1) * POPUP_ROW_H)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetColorTexture(1, 0.82, 0, 0.15)
    r.tex = r:CreateTexture(nil, "ARTWORK")
    r.tex:SetSize(70, 14)
    r.tex:SetPoint("RIGHT", -4, 0)
    r.edge = CreateFrame("Frame", nil, r, BACKDROP_TEMPLATE)
    r.edge:SetSize(70, 18)
    r.edge:SetPoint("RIGHT", -4, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", 6, 0)
    r.text:SetPoint("RIGHT", r.tex, "LEFT", -6, 0)
    r.text:SetJustifyH("LEFT")
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, d) popup:GetScript("OnMouseWheel")(popup, d) end)
    r:SetScript("OnClick", function(self)
        popup.onPick(self.item)
        popup:Hide()
    end)
    popup.rows[i] = r
end

function popup:Render()
    for i = 1, POPUP_ROWS do
        local r = self.rows[i]
        local item = self.items[i + self.offset]
        r.item = item
        if item then
            r.text:SetText(item.name)
            if self.kind == "font" then
                SafeSetFont(r.text, item.value or DEFAULT_FONT, 13)
            else
                SafeSetFont(r.text, DEFAULT_FONT, 12)
            end
            r.tex:Hide(); r.edge:Hide()
            if item.value and (self.kind == "background" or self.kind == "statusbar") then
                r.tex:SetTexture(item.value)
                r.tex:SetVertexColor(1, 1, 1)
                r.tex:Show()
            elseif item.value and self.kind == "border" and r.edge.SetBackdrop then
                r.edge:SetBackdrop({ edgeFile = item.value, edgeSize = 10 })
                r.edge:Show()
            end
            r.sel:SetShown(item.value == self.current)
            r:Show()
        else
            r:Hide()
        end
    end
end

popup:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, #self.items - POPUP_ROWS)
    self.offset = math.min(max, math.max(0, self.offset - d))
    self:Render()
end)
popup:SetScript("OnUpdate", function(self, e)
    if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then
        self.idle = 0
    else
        self.idle = (self.idle or 0) + e
        if self.idle > 1.5 then self:Hide() end
    end
end)

local function CreateSelector(parent, label, x, y, kind, key, themeKey)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(260, 44)
    f:SetPoint("TOPLEFT", x, y)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT")
    text:SetText(label)
    local b = CreateFrame("Button", nil, f, BACKDROP_TEMPLATE)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", 0, -14)
    b:SetPoint("TOPRIGHT", 0, -14)
    if b.SetBackdrop then
        b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        b:SetBackdropColor(0, 0, 0, 0.6)
        b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    local arrow = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetSize(60, 14)
    tex:SetPoint("RIGHT", arrow, "LEFT", -6, 0)
    local edge = CreateFrame("Frame", nil, b, BACKDROP_TEMPLATE)
    edge:SetSize(60, 18)
    edge:SetPoint("RIGHT", arrow, "LEFT", -6, 0)
    local val = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("LEFT", 6, 0)
    val:SetPoint("RIGHT", tex, "LEFT", -6, 0)
    val:SetJustifyH("LEFT")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    function f:Refresh()
        local current = AMB.theme[themeKey]
        local name = Custom()[key .. "Name"] or TR.FROM_THEME
        val:SetText(name)
        if kind == "font" then
            SafeSetFont(val, current, 13)
        end
        tex:Hide(); edge:Hide()
        if kind == "background" or kind == "statusbar" then
            tex:SetTexture(current)
            tex:Show()
        elseif kind == "border" and edge.SetBackdrop then
            edge:SetBackdrop({ edgeFile = current, edgeSize = 10 })
            edge:Show()
        end
    end

    b:SetScript("OnClick", function()
        if popup:IsShown() and popup.owner == b then popup:Hide(); return end
        local items = { { name = TR.FROM_THEME, value = nil } }
        for _, it in ipairs(MediaList(kind)) do items[#items + 1] = it end
        popup.items, popup.kind, popup.owner, popup.offset = items, kind, b, 0
        popup.current = Custom()[key .. "Name"] and AMB.theme[themeKey] or nil
        for i, it in ipairs(items) do
            if it.value == popup.current then
                popup.offset = math.max(0, math.min(i - 1, #items - POPUP_ROWS))
                break
            end
        end
        popup.onPick = function(item)
            Custom()[key] = item.value
            Custom()[key .. "Name"] = item.value and item.name or nil
            if kind == "border" then
                Custom().edgeSize = item.value and (item.value == FLAT and 1 or 16) or nil
            end
            Changed()
        end
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        popup:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
        popup:SetHeight(math.min(#items, POPUP_ROWS) * POPUP_ROW_H + 6)
        popup.idle = 0
        popup:Show()
        popup:Render()
    end)
    widgets[#widgets + 1] = f
    return f
end

-- Kachel mit Vorschau eines Designs
local function CreateThemeTile(parent, preset, x, y)
    local b = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    b:SetSize(176, 60)
    b:SetPoint("TOPLEFT", x, y)
    local t = BuildTheme(preset.key, nil)
    if b.SetBackdrop then
        b:SetBackdrop(MakeBackdrop(t.bg, t.edge, math.min(t.edgeSize, 12)))
        b:SetBackdropColor(unpack(t.bgColor))
        b:SetBackdropBorderColor(unpack(t.borderColor))
    end
    local ins = math.max(1, math.floor(math.min(t.edgeSize, 12) / 4 + 0.5))
    local head = b:CreateTexture(nil, "ARTWORK")
    head:SetPoint("TOPLEFT", ins, -ins)
    head:SetPoint("TOPRIGHT", -ins, -ins)
    head:SetHeight(14)
    head:SetTexture(t.headerTex)
    head:SetVertexColor(unpack(t.headerColor))
    local line = b:CreateTexture(nil, "OVERLAY")
    line:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 0.9)
    local name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", head, "LEFT", 5, 0)
    name:SetText(preset.name)
    local icon = b:CreateTexture(nil, "OVERLAY")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 6, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local bar = b:CreateTexture(nil, "OVERLAY")
    bar:SetSize(2, 26)
    bar:SetPoint("RIGHT", icon, "LEFT", -3, 0)
    bar:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 1)
    local l1 = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l1:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
    l1:SetText("Addon")
    local l2 = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -1)
    l2:SetText(TR.PREVIEW_LEFTCLICK)
    l2:SetTextColor(0.8, 0.8, 0.8)

    local sel = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    sel:SetPoint("TOPLEFT", -3, 3)
    sel:SetPoint("BOTTOMRIGHT", 3, -3)
    sel:SetColorTexture(1, 0.82, 0, 0.9)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    b:SetScript("OnClick", function()
        db.theme = preset.key
        wipe(db.custom)
        Changed()
    end)
    function b:Refresh()
        sel:SetShown(db.theme == preset.key)
    end
    widgets[#widgets + 1] = b
end

local function BuildPanel()
    if panel.built then return end
    panel.built = true

    local sf = CreateFrame("ScrollFrame", nil, panel)
    sf:SetPoint("TOPLEFT", 0, -4)
    sf:SetPoint("BOTTOMRIGHT", -4, 4)
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(600, 940)
    sf:SetScrollChild(c)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, c:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
    end)
    sf:SetScript("OnSizeChanged", function(self, w) if w and w > 0 then c:SetWidth(w) end end)

    local titleFS = c:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", 16, -16)
    titleFS:SetText("Albis Minimap Buttons  |cff999999v" .. VERSION .. "|r")
    local sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -6)
    sub:SetText(TR.OPT_SUBTITLE)

    SectionHeader(c, TR.SEC_THEME, -66)
    for i, p in ipairs(PRESETS) do
        CreateThemeTile(c, p, 16 + ((i - 1) % 3) * 190, -94 - math.floor((i - 1) / 3) * 72)
    end

    local L, R = 16, 316
    SectionHeader(c, TR.SEC_CUSTOMIZE, -248)
    CreateSelector(c, TR.OPT_BACKGROUND, L, -276, "background", "bg", "bg")
    CreateSelector(c, TR.OPT_BORDER, L, -324, "border", "edge", "edge")
    CreateSelector(c, TR.OPT_HEADER, L, -372, "statusbar", "headerTex", "headerTex")
    CreateSelector(c, TR.OPT_FONT, L, -420, "font", "font", "font")

    CreateColor(c, TR.OPT_BGCOLOR, R, -280, "bgColor")
    CreateColor(c, TR.OPT_BORDERCOLOR, R, -306, "borderColor")
    CreateColor(c, TR.OPT_ACCENT, R, -332, "accent")
    CreateColor(c, TR.OPT_HEADERCOLOR, R, -358, "headerColor")
    CreateColor(c, TR.OPT_NAMECOLOR, R, -384, "nameColor")
    CreateColor(c, TR.OPT_TEXTCOLOR, R, -410, "descColor")
    CreateCheck(c, TR.OPT_OUTLINE, R, -438,
        function() return AMB.theme.outline end,
        function(v) Custom().outline = v; Changed() end)

    CreateSlider(c, TR.OPT_BGALPHA, L, -474, 0, 1, 0.05,
        function() return AMB.theme.bgColor[4] or 1 end,
        function(v)
            local r, g, b = CurrentColor("bgColor")
            Custom().bgColor = { r, g, b, v }
            AMB:ApplyTheme()
        end,
        function(v) return math.floor(v * 100 + 0.5) .. " %" end)
    CreateSlider(c, TR.OPT_BORDERSIZE, L, -518, 1, 32, 1,
        function() return AMB.theme.edgeSize or 1 end,
        function(v) Custom().edgeSize = v; AMB:ApplyTheme() end)
    CreateSlider(c, TR.OPT_FONTSIZE, R, -474, 8, 18, 1,
        function() return AMB.theme.fontSize end,
        function(v) Custom().fontSize = v; AMB:ApplyTheme() end)

    SectionHeader(c, TR.SEC_BEHAVIOR, -572)
    CreateSlider(c, TR.OPT_ROWS_COMPACT, L, -600, 2, MAX_ROWS, 1,
        function() return db.rowsCompact end,
        function(v) db.rowsCompact = v; if menu:IsShown() then AMB:Layout(); AMB:Refresh() end end)
    CreateSlider(c, TR.OPT_ROWS_EXPANDED, L, -644, 2, MAX_ROWS, 1,
        function() return db.rowsExpanded end,
        function(v) db.rowsExpanded = v; if menu:IsShown() then AMB:Layout(); AMB:Refresh() end end)
    CreateSlider(c, TR.OPT_WIDTH, R, -600, MIN_WIDTH, MAX_WIDTH, 10,
        function() return db.width end,
        function(v) db.width = v; if menu:IsShown() then AMB:Layout(); AMB:Refresh() end end,
        function(v) return v .. " px" end)
    CreateSlider(c, TR.OPT_DELAY, R, -644, 1, 30, 1,
        function() return db.delay end,
        function(v) db.delay = v end,
        function(v) return v .. " s" end)

    local reset = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    reset:SetSize(200, 24)
    reset:SetPoint("TOPLEFT", L, -692)
    reset:SetText(TR.OPT_RESET)
    -- Icon des Buttons
    SectionHeader(c, TR.SEC_ICON, -740)
    local per = 10
    for i, path in ipairs(ANCHOR_ICONS) do
        local b = CreateFrame("Button", nil, c)
        b:SetSize(36, 36)
        b:SetPoint("TOPLEFT", L + ((i - 1) % per) * 42, -768 - math.floor((i - 1) / per) * 42)
        local sel = b:CreateTexture(nil, "BACKGROUND")
        sel:SetPoint("TOPLEFT", -3, 3)
        sel:SetPoint("BOTTOMRIGHT", 3, -3)
        sel:SetColorTexture(1, 0.82, 0, 0.9)
        local bg = b:CreateTexture(nil, "BORDER")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 1)
        local ic = b:CreateTexture(nil, "ARTWORK")
        ic:SetPoint("TOPLEFT", 1, -1)
        ic:SetPoint("BOTTOMRIGHT", -1, 1)
        SetIconTexture(ic, path)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(ic)
        hl:SetColorTexture(1, 1, 1, 0.2)
        b:SetScript("OnClick", function()
            db.anchorIcon = (path ~= LOGO) and path or nil
            AMB:ApplyAnchorIcon()
            Changed()
        end)
        function b:Refresh() sel:SetShown((db.anchorIcon or LOGO) == path) end
        widgets[#widgets + 1] = b
    end

    local hint = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", L, -858)
    hint:SetWidth(285)
    hint:SetJustifyH("LEFT")
    hint:SetText(TR.OPT_CUSTOM_ICON)
    local eb = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    eb:SetSize(240, 20)
    eb:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -4)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self)
        local txt = (self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if txt ~= "" then
            if not txt:find("\\") then txt = "Interface\\Icons\\" .. txt end
            db.anchorIcon = txt
            AMB:ApplyAnchorIcon()
            Changed()
        end
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    function eb:Refresh()
        local cur = db.anchorIcon
        self:SetText(cur and cur:gsub("^[Ii]nterface\\[Ii]cons\\", "") or "")
    end
    widgets[#widgets + 1] = eb

    CreateSlider(c, TR.OPT_BUTTONSIZE, R, -858, 24, 64, 2,
        function() return db.anchorSize end,
        function(v) db.anchorSize = v; AMB:ApplyAnchorIcon() end,
        function(v) return v .. " px" end)
    CreateCheck(c, TR.OPT_GLOW, R, -904,
        function() return db.anchorGlow end,
        function(v) db.anchorGlow = v; AMB:ApplyAnchorIcon() end)

    reset:SetScript("OnClick", function()
        db.theme = "dark"
        wipe(db.custom)
        Changed()
    end)
end

local function PreviewHost()
    if SettingsPanel and SettingsPanel:IsShown() then return SettingsPanel end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then return InterfaceOptionsFrame end
    return panel
end

panel:SetScript("OnShow", function()
    BuildPanel()
    for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
    AMB:OpenPreview(PreviewHost())
end)
panel:SetScript("OnHide", function()
    popup:Hide()
    AMB:ClosePreview()
end)

function AMB:RegisterOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
        self.category = cat
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function AMB:OpenOptions()
    if self.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

------------------------------------------------------------------------
-- Slash-Befehle
------------------------------------------------------------------------
SLASH_ALBISMINIMAPBUTTONS1 = "/amb"
local function SlashHandler(msg)
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local num = tonumber(arg)
    if cmd == "rows" and num then
        SetNumRows(math.max(2, math.min(MAX_ROWS, math.floor(num))))
        Print(TR.MSG_ROWS:format(db.expanded and TR.MODE_EXPANDED or TR.MODE_COMPACT, NumRows()))
        if menu:IsShown() then AMB:Open() end
    elseif cmd == "delay" and num then
        db.delay = math.max(0.5, num)
        Print(TR.MSG_DELAY:format(db.delay))
    elseif cmd == "width" and num then
        db.width = math.floor(math.max(MIN_WIDTH, math.min(MAX_WIDTH, num)))
        Print(TR.MSG_WIDTH:format(db.width))
        if menu:IsShown() then AMB:Open() end
    elseif cmd == "config" or cmd == "options" or cmd == "design" then
        AMB:OpenOptions()
    elseif cmd == "reset" then
        db.point = nil
        PlaceAnchor()
        Print(TR.MSG_RESET)
    elseif cmd == "scan" then
        AMB:Scan()
        Print(TR.MSG_FOUND:format(#entries))
    elseif cmd == "version" or cmd == "ver" then
        Print(TR.MSG_VERSION:format(VERSION))
        local names = {}
        for name, v in pairs(AMB.groupVersions or {}) do names[#names + 1] = name .. " " .. v end
        table.sort(names)
        if #names > 0 then Print(TR.MSG_VERSIONS_GROUP:format(table.concat(names, ", "))) end
    elseif cmd == "list" then
        AMB:Scan()
        for _, e in ipairs(entries) do
            Print(e.name .. "  |cff888888(" .. (e.ldbName or e.btn:GetName() or "?") .. ")|r")
        end
    elseif cmd == "ignore" and arg ~= "" then
        db.ignore[arg] = true
        Print(TR.MSG_IGNORE:format(arg))
        AMB:Scan()
    elseif cmd == "unignore" and arg ~= "" then
        db.ignore[arg] = nil
        Print(TR.MSG_UNIGNORE:format(arg))
        AMB:Scan()
    else
        Print(TR.HELP_TITLE)
        Print(TR.HELP_CONFIG)
        Print(TR.HELP_ROWS:format(NumRows()))
        Print(TR.HELP_WIDTH:format(db.width))
        Print(TR.HELP_DELAY:format(db.delay))
        Print(TR.HELP_LIST)
        Print(TR.HELP_IGNORE)
        Print(TR.HELP_SCAN)
        Print(TR.HELP_VERSION)
    end
end

SlashCmdList.ALBISMINIMAPBUTTONS = function(msg)
    -- Fehler duerfen niemals die Chat-Eingabe blockieren
    xpcall(function() SlashHandler(msg) end, geterrorhandler())
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------
AMB:RegisterEvent("PLAYER_LOGIN")
AMB:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        AlbisMinimapButtonsDB = AlbisMinimapButtonsDB or {}
        db = AlbisMinimapButtonsDB
        -- alte Einstellungen aus Version 1 entfernen
        if db.rows then db.rows = nil; db.width = nil end
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = type(v) == "table" and {} or v end
        end
        RegisterFontsWithLSM()
        AMB:ApplyTheme()
        AMB:ApplyAnchorIcon()
        AMB:RegisterOptions()
        PlaceAnchor()
        self:Scan()
        -- Manche Addons erzeugen ihre Buttons erst spaeter
        if C_Timer then
            for _, t in ipairs({ 2, 5, 10, 20, 45 }) do
                C_Timer.After(t, function() AMB:Scan() end)
            end
        end
        AMB:HookLibDBIcon()
        AMB:HookFrameCreation()
        AMB:WarnConflicts()
        AMB:StartWatcher()
        AMB:InitVersionCheck()
        self:RegisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
    elseif event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        -- nachgeladene Addons (Load-on-Demand) bringen evtl. LibDBIcon
        -- oder einen eigenen Button mit
        AMB:HookLibDBIcon()
        AMB:ScanSoon(1)
        if event == "PLAYER_ENTERING_WORLD" then AMB:SendVersionSoon(5) end
    elseif event == "GROUP_ROSTER_UPDATE" then
        AMB:OnRosterUpdate()
    elseif event == "CHAT_MSG_ADDON" then
        AMB:OnAddonMessage(...)
    end
end)

-- LibDBIcon meldet neu erzeugte Buttons; der Callback wird registriert,
-- sobald irgendein Addon die Bibliothek mitbringt
function AMB:HookLibDBIcon()
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBIcon and LDBIcon.RegisterCallback and self.ldbHooked ~= LDBIcon then
        self.ldbHooked = LDBIcon
        LDBIcon.RegisterCallback(AMB, "LibDBIcon_IconCreated", function() AMB:ScanSoon(0.1) end)
    end
end

-- Andere Button-Sammler nehmen uns die Buttons weg
local CONFLICTS = { "MinimapButtonButton", "MBB", "MinimapButtonBag", "MinimapButtonFrame", "SexyMap", "HidingBar" }
function AMB:WarnConflicts()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not isLoaded then return end
    for _, name in ipairs(CONFLICTS) do
        local ok, loaded = pcall(isLoaded, name)
        if ok and loaded then Print(TR.MSG_CONFLICT:format(AddonTitleFor(name) or name)) end
    end
end

-- Mehrere Anfragen kurz hintereinander werden zu einem (guenstigen) Scan
-- zusammengefasst
local scanPending = false
function AMB:ScanSoon(delay)
    if not C_Timer then self:Scan(false); return end
    if scanPending then return end
    scanPending = true
    C_Timer.After(delay or 0.5, function()
        scanPending = false
        AMB:Scan(false)
    end)
end

-- Sofort reagieren, wenn ein Addon einen Frame an der Minimap erzeugt
-- oder einen Button nachtraeglich an die Minimap haengt. Die Hooks tun
-- nichts weiter als einen Scan anzustossen.
local function IsMinimapParent(p)
    return p ~= nil and (p == Minimap or p == MinimapBackdrop or p == MinimapCluster)
end
function AMB:HookFrameCreation()
    if self.creationHooked then return end
    self.creationHooked = true
    hooksecurefunc("CreateFrame", function(_, _, parent)
        if IsMinimapParent(parent) then AMB:ScanSoon(0.5) end
    end)
    for _, t in ipairs({ "Button", "Frame", "CheckButton" }) do
        local ok, probe = pcall(CreateFrame, t)
        local mt = ok and probe and getmetatable(probe)
        local methods = mt and mt.__index
        if type(methods) == "table" and methods.SetParent then
            hooksecurefunc(methods, "SetParent", function(f, parent)
                -- Kartenpins werden oft umgehaengt: erst den einen Frame pruefen
                if IsMinimapParent(parent) and not grabbed[f] and IsShownCandidate(f) then
                    AMB:ScanSoon(0.5)
                end
            end)
        end
    end
end

-- Waechter als Rueckfall fuer Buttons, die erst spaeter eingeblendet
-- werden: alle 10 s eine guenstige Pruefung, jede Minute (nicht im
-- Kampf) auch die Frames an UIParent. Neu gesucht wird nur bei Bedarf.
local watchTicks = 0
local function WatchTick()
    watchTicks = watchTicks + 1
    local full = watchTicks % 6 == 0 and not (InCombatLockdown and InCombatLockdown())
    if NeedsRescan(full) then AMB:Scan(full) end
end
function AMB:StartWatcher()
    if self.watching then return end
    self.watching = true
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(10, WatchTick)
    else
        local f, acc = CreateFrame("Frame"), 0
        f:SetScript("OnUpdate", function(_, e)
            acc = acc + e
            if acc >= 10 then acc = 0; WatchTick() end
        end)
    end
end

------------------------------------------------------------------------
-- Versionsabgleich in Gruppe/Raid
-- Jeder mit dem Addon schickt beim Betreten der Welt und beim Beitritt
-- zu einer Gruppe einmal seine Version (eine kurze Addon-Nachricht).
-- Wer eine aeltere Version hat, bekommt einen Hinweis im Chat.
------------------------------------------------------------------------
local PREFIX = "AlbisMMB"
local SendAddonMessage = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
AMB.groupVersions = {}
local notifiedVersion       -- hoechste Version, auf die schon hingewiesen wurde
local lastSend, sendPending = 0, false
local lastGroupSize = 0

local function ParseVersion(v)
    local t = {}
    for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end

-- true, wenn Version a neuer ist als b
local function IsNewer(a, b)
    local x, y = ParseVersion(a), ParseVersion(b)
    if #x == 0 or #y == 0 then return false end
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

local function GroupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

local function GroupSize()
    return (GetNumGroupMembers and GetNumGroupMembers()) or 0
end

function AMB:InitVersionCheck()
    if not (SendAddonMessage and RegisterPrefix) then return end
    pcall(RegisterPrefix, PREFIX)
    self:RegisterEvent("CHAT_MSG_ADDON")
    lastGroupSize = GroupSize()
end

function AMB:SendVersion()
    local channel = GroupChannel()
    if not channel or not SendAddonMessage then return end
    -- hoechstens alle 15 Sekunden
    if GetTime() - lastSend < 15 then return end
    lastSend = GetTime()
    pcall(SendAddonMessage, PREFIX, "V:" .. VERSION, channel)
end

function AMB:SendVersionSoon(delay)
    if sendPending then return end
    if not C_Timer then self:SendVersion(); return end
    sendPending = true
    C_Timer.After(delay or 3, function()
        sendPending = false
        AMB:SendVersion()
    end)
end

function AMB:OnRosterUpdate()
    local n = GroupSize()
    -- nur wenn jemand dazukommt (oder man selbst beitritt)
    if n > lastGroupSize then self:SendVersionSoon(4) end
    if n == 0 then wipe(self.groupVersions) end
    lastGroupSize = n
end

local function StripRealm(name)
    return name and (name:match("^([^%-]+)") or name)
end

function AMB:OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= PREFIX or type(msg) ~= "string" then return end
    local v = msg:match("^V:(.+)$")
    if not v then return end
    local me = UnitName and UnitName("player")
    local who = StripRealm(sender)
    if who == me then return end
    self.groupVersions[who or "?"] = v
    if IsNewer(v, VERSION) then
        if not notifiedVersion or IsNewer(v, notifiedVersion) then
            notifiedVersion = v
            Print(TR.MSG_UPDATE:format(v, VERSION, who or "?"))
        end
    elseif IsNewer(VERSION, v) then
        -- der andere hat eine aeltere Version: unsere schicken, damit er
        -- den Hinweis bekommt
        self:SendVersionSoon(2)
    end
end
