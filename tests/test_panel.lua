-- The glass panel: a child of the tracker under its modules, with its bottom
-- edge chosen by state, repainted by theme and opacity.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GQT = loadAddon()
local Panel, Theme = GQT.Panel, GQT.Theme
local t = ObjectiveTrackerFrame
local p, g, backing = Panel._test.frame(), Panel._test.g(), Panel._test.backing()

check(p ~= nil, "the panel is built")
eq(p:GetParent(), t, "parented to the tracker: it shows, hides, moves and scales with it")
eq(p:GetName(), nil, "unnamed")
check(not p:IsMouseEnabled(), "takes no mouse: the tracker's clicks stay Blizzard's")
eq(p:GetFrameLevel(), t:GetFrameLevel() - 1, "one level under the tracker")
eq(g.top:GetFrameLevel(), t:GetFrameLevel(), "the rim at the tracker's level, under its modules")
check(g.top:GetFrameLevel() < QuestObjectiveTracker:GetFrameLevel(), "modules draw above the glass")

-- The surface: rims nearly off, no shadow, a dark bottom line, our tapered
-- top hairline in place of the library's straight one, no wash.
local L = Panel.LOOK
eq(g.shadow:GetAlpha(), L.shadow, "no drop shadow")
near(g.rim:GetAlpha(), L.rim, "the rim nearly off")
near(g.dark:GetAlpha(), L.dark, "the dark rim nearly off")
check(g.edge and g.edge.custom, "the panel's own edge")
check(not g.edge.top:IsShown() and not g.edge.glow:IsShown(), "the library's straight top line and glow off")
near(g.edge.bottom._color[4], L.bottom, "a darker bottom line")
check(g.edge.bottom:IsShown(), "the bottom line shows")
-- (The wash is a gradient, which ignores SetAlpha on this client: hidden,
-- and clear at its top.)
check(not g.wash:IsShown(), "no milky wash: hidden")
near(g.wash._gradient[3].a, 0, "no milky wash: its gradient clear at the top too")

local taper = Panel._test.taper()
check(taper ~= nil, "the tapered top line is built")
-- A half: on g.top, over the library's line from `from` to `to`, fading
-- horizontally from alpha a1 to a2.
local function half(tex, from, to, a1, a2, msg)
    check(tex:GetParent() == g.top, msg .. ": above the body, on g.top")
    local p1, p2 = tex._points[1], tex._points[2]
    check(p1 and p1[1] == "TOPLEFT" and p1[2] == g.edge.top and p1[3] == from, msg .. ": starts at the line's " .. from)
    check(p2 and p2[1] == "BOTTOMRIGHT" and p2[2] == g.edge.top and p2[3] == to, msg .. ": ends at the line's " .. to)
    local gr = tex._gradient or {}
    check(gr[1] == "HORIZONTAL", msg .. ": a horizontal fade")
    near(gr[2] and gr[2].a or -1, a1, msg .. ": alpha at its left")
    near(gr[3] and gr[3].a or -1, a2, msg .. ": alpha at its right")
end
half(taper.left, "TOPLEFT", "BOTTOM", 0, L.top, "left half: nothing at the corner, brightest at the middle")
half(taper.right, "TOP", "BOTTOMRIGHT", L.top, 0, "right half: brightest at the middle, nothing at the corner")

-- The point a panel corner is anchored to, as { relativeTo, relativePoint, x, y }.
local function anchor(point)
    for _, pt in ipairs(p._points) do
        if pt[1] == point then return { pt[2], pt[3], pt[4], pt[5] } end
    end
end
local function at(point, rel, relPoint, x, y, msg)
    local a = anchor(point) or {}
    check(a[1] == rel and a[2] == relPoint and a[3] == x and a[4] == y,
          string.format("%s: %s to %s %s (%s, %s), got %s %s (%s, %s)", msg, point, tostring(rel), relPoint,
                        tostring(x), tostring(y), tostring(a[1]), tostring(a[2]), tostring(a[3]), tostring(a[4])))
end

-- Nothing tracked yet: the header only.
eq(Panel.state, "header", "empty: the header")
at("BOTTOMRIGHT", t.Header, "BOTTOMRIGHT", Panel.HEADER_RIGHT, Panel.HEADER_BOTTOM, "empty")

-- Populated: down to the NineSlice, which Blizzard anchors under the last module.
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
eq(Panel.state, "populated", "a shown module: populated")
at("TOPLEFT", t.NineSlice, "TOPLEFT", Panel.LEFT, 0, "populated")
at("BOTTOMRIGHT", t.NineSlice, "BOTTOMRIGHT", Panel.RIGHT, Panel.BOTTOM, "populated")
eq(#p._points, 2, "two anchors, re-made each time (no stale third)")

-- One section collapsed: the module still shows its header, still populated.
WoW.collapseModule("QuestObjectiveTracker", true)
WoW.layout("QuestObjectiveTracker", { shown = true })
eq(Panel.state, "populated", "a collapsed section is still laid out")

-- The container collapsed: placed at the click, while the modules still read
-- shown, and again by the layouts that hide them.
WoW.collapse(true)
eq(Panel.state, "header", "collapsed: the header at once, though the NineSlice keeps its old size")
at("BOTTOMRIGHT", t.Header, "BOTTOMRIGHT", Panel.HEADER_RIGHT, Panel.HEADER_BOTTOM, "collapsed")
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
eq(Panel.state, "header", "a layout while collapsed stays on the header")
WoW.collapse(false)
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
eq(Panel.state, "populated", "expanded and laid out: populated again")

-- Empty in Edit Mode (the only time an empty tracker shows), and leaving it.
WoW.editMode(true)
WoW.layout("QuestObjectiveTracker", { shown = false })
eq(Panel.state, "header", "empty in Edit Mode: the header")
WoW.asBlizzard(function() QuestObjectiveTracker._shown = true end)
WoW.editMode(false)
eq(Panel.state, "populated", "leaving Edit Mode places it again")

-- The backing: medium by default, repainted on /gqt opacity.
near(backing._color[4], Theme.OPACITY.medium, "backing medium by default")
check(backing._masks and backing._masks[1] == g.mask, "the backing is clipped by the glass's mask")
GQT._test.slash("opacity solid")
near(backing._color[4], Theme.OPACITY.solid, "opacity solid")
GQT._test.slash("opacity light")
near(backing._color[4], Theme.OPACITY.light, "opacity light")
eq(GlassQuestTrackerDB.opacity, "light", "opacity saved")
GQT._test.slash("opacity murky")
eq(GlassQuestTrackerDB.opacity, "light", "an unknown opacity is refused")

-- Themes paint the glass; stock hides it.
GQT._test.slash("theme smoked")
near(g.tint._color[4], Theme.PRESETS.smoked.tint[4], "smoked tint")
check(not g.wash:IsShown(), "smoked: no wash either")
GQT._test.slash("theme class")
near(g.tint._color[1], 0.25 * Theme.PRESETS.class.classShade, "class tint (mage)")
GQT._test.slash("theme stock")
check(not p:IsShown(), "stock: no glass")
WoW.layout("QuestObjectiveTracker", { blocks = 1 })
check(not p:IsShown(), "stock: a layout doesn't bring it back")
GQT._test.slash("theme clear")
check(p:IsShown(), "glass again")
near(g.tint._color[1], Theme.PRESETS.clear.tint[1], "clear: charcoal")
near(g.tint._color[4], g.tint.glassColor[4], "clear: at the material's own alpha")

-- A saved stock theme starts without glass.
GQT = loadAddon({ db = { theme = "stock" } })
check(not GQT.Panel._test.frame():IsShown(), "stock from login: no glass")

done("test_panel")
