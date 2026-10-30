-- Theme.lua: the looks of the glass, repainted live (Glass MiniMap's Theme.lua).
--
-- clear   the reflective shell's body (References\Docs\LIBGLASS-WINDOW-STYLING.md)
-- smoked  darker: the recipe's internal-panel body
-- class   the shell's body in the player's class colour, shaded by classShade.
--         The class colour may be unreadable early in a login; the surface
--         then stays clear and PLAYER_ENTERING_WORLD paints it again.
-- stock   no glass: Blizzard's tracker exactly as it ships (Skin.lua restores it)
--
-- Only the body is touched (its tint, colour and alpha, and the wash): the
-- rims and the reflection are Panel's. The opaque backing under the glass
-- has its own alpha, the opacity setting (Theme.BackingAlpha); medium is the
-- recipe's.
--
-- No wash (outside critique, 2026-10-15): over a panel as tall as the
-- tracker its gradient greyed the whole body. It is a gradient, which
-- ignores SetAlpha on Forever (LibGlass #47), so it goes through SetWash.

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
    clear  = { tint = { 0.085, 0.095, 0.115, 0.78 } },
    smoked = { tint = { 0.055, 0.07, 0.09, 0.86 } },
    class  = { classShade = 0.6, alpha = 0.78 },
    stock  = {},
}

-- The backing under the glass: the tracker sits over the world, and its text
-- has to read over bright terrain (plan risk 4).
Theme.OPACITY_NAMES = { "light", "medium", "solid" }
Theme.OPACITY = { light = 0.35, medium = 0.55, solid = 0.82 }
Theme.BACKING = { 0.03, 0.03, 0.035 }

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
        return { r * p.classShade, g * p.classShade, b * p.classShade, p.alpha }, true
    end
    return p.tint, true
end

local function paint(g, name, tint)
    if tint then
        Glass.SetSurfaceTint(g, tint[1], tint[2], tint[3], tint[4])
    else
        Glass.SetSurfaceTint(g)
    end
    Glass.SetWash(g, 0)
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
