-- Theme.lua: the looks of the glass, repainted live (Glass MiniMap's Theme.lua).
--
-- clear   the material's light body, in charcoal
-- smoked  AltStable's darker body (its numbers, as GlassPanel and GlassMail use them)
-- class   the clear body tinted by the player's class colour, shaded by
--         classShade. The class colour may be unreadable early in a login; the
--         surface then stays clear and PLAYER_ENTERING_WORLD paints it again.
-- stock   no glass: Blizzard's tracker exactly as it ships (Skin.lua restores it)
--
-- Only body regions are touched (tint colour, grain and wash alpha): the rims
-- and edge are Panel's. The opaque backing under the glass has its own alpha,
-- the opacity setting (Theme.BackingAlpha).
--
-- Charcoal, not milky (two rounds of outside critique, 2026-10-15, as
-- GlassChat's second pass): no white wash (over a panel as tall as the
-- tracker its gradient greyed the whole body), a near-black neutral backing,
-- and clear's tint charcoal instead of the material's cool grey-blue, which
-- lifted the backing towards "grey acrylic". The backing is more opaque than
-- first shipped: NPC names showed through the first quest.

GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local API = GQT.API
local Glass = GQT.Glass
local Theme = {}
GQT.Theme = Theme

Theme.NAMES = { "clear", "smoked", "class", "stock" }
Theme.LABELS = { clear = "Clear glass", smoked = "Smoked glass", class = "Class colour glass",
                 stock = "Blizzard's own" }
Theme.PRESETS = {
    clear  = { tint = { 0.06, 0.06, 0.07 } },   -- alpha: the material's own
    smoked = { tint = { 0.05, 0.06, 0.08, 0.62 } },
    class  = { classShade = 0.6 },
    stock  = {},
}

-- The backing under the glass: the tracker sits over the world, and its text
-- has to read over bright terrain (plan risk 4).
Theme.OPACITY_NAMES = { "light", "medium", "solid" }
Theme.OPACITY = { light = 0.65, medium = 0.82, solid = 0.92 }
Theme.BACKING = { 0.03, 0.03, 0.035 }
Theme.WASH = 0   -- a fraction of the material's wash

local surfaces = {}   -- LibGlass g tables
Theme.pending = false

function Theme.IsValid(name) return Theme.PRESETS[name] ~= nil end
function Theme.IsValidOpacity(name) return Theme.OPACITY[name] ~= nil end

function Theme.Name()
    local name = GQT.db and GQT.db.theme
    return Theme.PRESETS[name] and name or "clear"
end

function Theme.IsStock() return Theme.Name() == "stock" end

function Theme.BackingAlpha()
    local name = GQT.db and GQT.db.opacity
    return Theme.OPACITY[name] or Theme.OPACITY.medium
end

-- The tint for this theme as r, g, b, a (a nil: the surface's own), or
-- nothing for "as built". Second return: false while the class colour is
-- wanted but unreadable.
local function tintFor(name)
    local p = Theme.PRESETS[name]
    if name == "class" then
        local r, g, b = API.ClassColor()
        if not r then return nil, false end
        return { r * p.classShade, g * p.classShade, b * p.classShade }, true
    end
    return p.tint, true
end

local function paint(g, name, tint)
    if tint then
        Glass.SetSurfaceTint(g, tint[1], tint[2], tint[3], tint[4])
    else
        Glass.SetSurfaceTint(g)
    end
    if g.grain then g.grain:SetAlpha(Glass.STYLE.grain or 0) end
    -- The wash is a gradient (LibGlass: clear at the bottom to STYLE.wash
    -- white at the top), and a gradient texture ignores SetAlpha on this
    -- client: /run read it at 1 right after SetAlpha(0) (70374, 2026-10-15;
    -- GlassActionBars measured the same on 2026-10-13). So it is painted
    -- through its gradient's colours, and hidden outright at zero.
    if g.wash then
        local top = (Glass.STYLE.wash or 0) * Theme.WASH
        g.wash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, top))
        g.wash:SetShown(top > 0)
    end
end

-- Add a surface and paint it with the current theme.
function Theme.Register(g)
    if type(g) ~= "table" or not g.tint then return end
    surfaces[#surfaces + 1] = g
    local name = Theme.Name()
    API.Try("theme:paint", paint, g, name, (tintFor(name)))
end

-- Repaint every surface. Returns false while the class colour is unreadable.
function Theme.Refresh()
    local name = Theme.Name()
    local tint, known = tintFor(name)
    for _, g in ipairs(surfaces) do API.Try("theme:paint", paint, g, name, tint) end
    Theme.pending = not known
    return known
end

-- PLAYER_ENTERING_WORLD: the class colour can be read by now.
function Theme.Retry()
    if Theme.pending then Theme.Refresh() end
end

Theme._test = { surfaces = surfaces }
