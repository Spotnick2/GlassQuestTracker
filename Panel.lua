-- Panel.lua: the glass behind the tracker.
--
-- An unnamed, mouse-off frame parented to ObjectiveTrackerFrame: it shows,
-- hides, moves and scales with the tracker, and Edit Mode never sees it.
-- Measured clean in taint passes A and B (70374, docs/FOREVER-PROBE.md).
--
-- It sits under the modules: the panel one level below the tracker, the
-- glass's rim frame (g.top) at the tracker's level, the modules above both.
--
-- The bottom edge is chosen by state, never read from a position:
--   populated            the NineSlice's bottom, which Blizzard anchors under
--                        the last module after every layout (Container.lua:117)
--   collapsed or empty   the Header's bottom: while collapsed the NineSlice
--                        keeps its old full size (70374: the probe's overlay
--                        stayed big), and empty (Edit Mode only: otherwise
--                        the tracker hides) it has top anchors only.
-- Skin.lua calls Place after every module layout, collapse and Edit Mode exit.

GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local Glass = GQT.Glass
local Theme = GQT.Theme
local Tracker = GQT.Tracker
local Panel = {}
GQT.Panel = Panel

-- Offsets from the NineSlice, whose left runs 30 px past the tracker for the
-- POI buttons and whose right runs 5 px past it. The right edge stops 2 px
-- inside the tracker (it first ran 3 px past it): a tracker snapped beside the
-- action bars otherwise merged with their glass slots (outside critique,
-- 2026-10-15). The header offsets keep the same right edge when collapsed.
Panel.LEFT, Panel.RIGHT, Panel.BOTTOM = 16, -7, 0
Panel.HEADER_RIGHT, Panel.HEADER_BOTTOM = -2, -4

-- The surface: the suite's reflective shell (References\Docs\LIBGLASS-
-- WINDOW-STYLING.md, LibGlass r9's Glass.Reflect; the owner's choice, 2026-10-18),
-- the window look GlassRaidFrames and PetStable share. The library's rims
-- low, with Reflect's lit rim, a top hairline brightest at the left and a
-- short reflection over the header in their place; the edge off; the bottom
-- quiet. The body's tint and wash are Theme's, the backing's opacity the
-- setting's.
Panel.SHELL = { rim = 0.12, dark = 0.55, grain = 0, shadow = 0.18 }
-- The header reflection's height, fitted to the tracker's "All Objectives"
-- band (32 px on 70374: the tracker's top 884.5, the Header's bottom 852.5):
-- it fades out over the section title, before the first quest line.
Panel.HEADER = 36

local panel, g, backing, reflect
Panel.state = nil   -- "populated" | "header", after the last Place

function Panel.Build()
    local t = Tracker.Frame()
    if panel or not t then return panel end
    panel = CreateFrame("Frame", nil, t)
    local level = t:GetFrameLevel()
    panel:SetFrameLevel(math.max(0, level - 1))
    g = Glass.Apply(panel, "large")
    g.top:SetFrameLevel(level)
    for part, a in pairs(Panel.SHELL) do Glass.SetSurfaceAlpha(g, part, a) end
    Glass.SetEdge(g, 0, 0, 0)   -- Reflect's top hairline takes its place
    reflect = Glass.Reflect(g, panel, { header = Panel.HEADER })
    Theme.Register(g)
    -- The opaque backing (GlassMiniMap's tracking menu): above the shadow
    -- (-8), under the tint (-6), clipped by the glass's own mask.
    backing = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    backing:SetAllPoints(panel)
    backing:AddMaskTexture(g.mask)
    Panel.Repaint()
    return panel
end

function Panel.Repaint()
    if not backing then return end
    local c = Theme.BACKING
    backing:SetColorTexture(c[1], c[2], c[3], Theme.BackingAlpha())
end

function Panel.Place()
    local nine, header = Tracker.NineSlice(), Tracker.Header()
    if not (panel and nine and header) then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", nine, "TOPLEFT", Panel.LEFT, 0)
    if Tracker.IsCollapsed() or not Tracker.Populated() then
        panel:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", Panel.HEADER_RIGHT, Panel.HEADER_BOTTOM)
        Panel.state = "header"
    else
        panel:SetPoint("BOTTOMRIGHT", nine, "BOTTOMRIGHT", Panel.RIGHT, Panel.BOTTOM)
        Panel.state = "populated"
    end
end

-- Our own frame: Show/Hide are ours to call.
function Panel.SetShown(on)
    if panel then panel:SetShown(on) end
end

Panel._test = { frame = function() return panel end, g = function() return g end,
                backing = function() return backing end, reflect = function() return reflect end }
