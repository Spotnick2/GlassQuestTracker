-- Blizzard.lua: the tracker's stock art steps aside for the glass.
--
-- Nothing here hides, moves or drives the tracker (CLAUDE.md, "The UI
-- contract"). Each piece is changed with C widget methods only, through
-- Compat's Fade, Blank and Tint, and every piece touched is remembered so the
-- "stock" theme can give it all back (Restore).
--
--   FADED    the NineSlice (Edit Mode's Opacity background) and the container
--            header's gold bar; item and find-group button frames (icon,
--            count and cooldown stay); progress-bar borders
--   BLANKED  module header Background, Shine and Glow: AddAnim animates their
--            alpha with setToFinalAlpha, which a fade can't hold
--   TINTED   the minimize (and filter) buttons, cool instead of gold/red
--
-- Left stock: text (Blizzard's colours and fonts: Edit Mode's Text Size works
-- through the font objects, and difficulty colours carry information), POI
-- buttons and auto-quest popups.

GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local API = GQT.API
local Tracker = GQT.Tracker
local Blizzard = {}
GQT.Blizzard = Blizzard

Blizzard.TINT = { 0.75, 0.9, 1 }

local touched = setmetatable({}, { __mode = "k" })   -- region -> "fade" | "blank" | "tint"

local function fade(region)
    if API.Try("fade", API.Fade, region) then touched[region] = "fade" end
end

local function blank(tex)
    if type(tex) ~= "table" then return end
    if API.IsBlanked(tex) or API.Try("blank", API.Blank, tex) then touched[tex] = "blank" end
end

local function call(obj, getter)
    if type(obj) ~= "table" or type(obj[getter]) ~= "function" then return nil end
    local ok, v = pcall(obj[getter], obj)
    return ok and v or nil
end

-- A stock button's art in our colour. The highlight too: Blizzard's is red
-- or yellow ADD.
local function tintButton(b)
    if type(b) ~= "table" then return end
    local c = Blizzard.TINT
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local tex = call(b, getter)
        if tex and API.Try("tint", API.Tint, tex, c[1], c[2], c[3]) then touched[tex] = "tint" end
    end
end

-- A button's frame art faded; its icon, count and cooldown are other regions.
local function fadeButtonArt(b)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local tex = call(b, getter)
        if tex then fade(tex) end
    end
end

-- The container: its NineSlice, the "All Objectives" bar and its buttons.
function Blizzard.Container()
    local nine, header = Tracker.NineSlice(), Tracker.Header()
    if nine then fade(nine) end
    if header then
        if type(header.Background) == "table" then fade(header.Background) end
        tintButton(header.MinimizeButton)
        tintButton(header.FilterButton)
    end
end

-- One module: its header, and whatever pooled extras this layout shows.
-- Safe to repeat: every helper skips what it already holds.
function Blizzard.Module(m)
    local h = type(m.Header) == "table" and m.Header or nil
    if h then
        blank(h.Background)
        blank(h.Shine)
        blank(h.Glow)
        tintButton(h.MinimizeButton)
    end
    Tracker.EachRightEdgeFrame(m, fadeButtonArt)
    Tracker.EachProgressBar(m, function(p)
        local bar = type(p.Bar) == "table" and p.Bar or nil
        if not bar then return end
        for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do
            if type(bar[key]) == "table" then fade(bar[key]) end
        end
    end)
end

-- Everything back as Blizzard had it (the "stock" theme).
function Blizzard.Restore()
    for region, kind in pairs(touched) do
        if kind == "fade" then API.Try("unfade", API.Unfade, region)
        elseif kind == "blank" then API.Try("unblank", API.Unblank, region)
        else API.Try("untint", API.Untint, region) end
        touched[region] = nil
    end
end

Blizzard._test = { touched = touched }
