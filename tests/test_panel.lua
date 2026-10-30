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

-- The surface: the suite's reflective shell (LIBGLASS-WINDOW-STYLING.md).
-- The library's rims low, its edge off, no wash; Reflect's three layers.
local S = Panel.SHELL
near(g.rim:GetAlpha(), S.rim, "the library's rim low")
near(g.dark:GetAlpha(), S.dark, "its dark rim at the recipe's")
near(g.shadow:GetAlpha(), S.shadow, "a faint shadow")
eq(g.grain:GetAlpha(), 0, "no grain")
check(not g.edge.top:IsShown() and not g.edge.glow:IsShown() and not g.edge.bottom:IsShown(),
      "the library's edge off: the reflection's hairline takes its place, the bottom stays quiet")
-- (The wash is a gradient, which ignores SetAlpha on Forever: SetWash hides it.)
check(not g.wash:IsShown(), "no milky wash")

local rf = Panel._test.reflect()
check(rf ~= nil and g.reflect == rf, "the reflection is built, once")
local function grad(tex) local gr = tex and tex._gradient or {}; return gr[1], gr[2] and gr[2].a, gr[3] and gr[3].a end
local o, a1, a2 = grad(rf.rim)
check(rf.rim:GetParent() == g.top and o == "VERTICAL" and a2 > a1, "a lit rim on g.top, brighter at the top")
o, a1, a2 = grad(rf.top)
check(rf.top:GetParent() == g.top and o == "HORIZONTAL" and a1 > a2, "a top hairline, brightest at the left")
o, a1, a2 = grad(rf.header)
check(o == "VERTICAL" and a1 == 0 and a2 > 0, "a header reflection, gone at its bottom")
eq(rf.header._height, Panel.HEADER, "fitted to the tracker's header band")
check(rf.header._masks and rf.header._masks[1] == g.mask, "inside the glass's rounded mask")
check(Panel.HEADER > 32 and Panel.HEADER < 32 + 25,
      "past the 'All Objectives' band (32 px), gone before the section title ends (25 px more)")

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
near(g.tint._color[4], Theme.PRESETS.class.alpha, "class: at the shell's alpha too")
GQT._test.slash("theme stock")
check(not p:IsShown(), "stock: no glass")
WoW.layout("QuestObjectiveTracker", { blocks = 1 })
check(not p:IsShown(), "stock: a layout doesn't bring it back")
GQT._test.slash("theme clear")
check(p:IsShown(), "glass again")
near(g.tint._color[1], Theme.PRESETS.clear.tint[1], "clear: charcoal")
near(g.tint._color[4], Theme.PRESETS.clear.tint[4], "clear: at the shell's alpha, not the material's 0.24")

-- A saved stock theme starts without glass.
GQT = loadAddon({ db = { theme = "stock" } })
check(not GQT.Panel._test.frame():IsShown(), "stock from login: no glass")

done("test_panel")
