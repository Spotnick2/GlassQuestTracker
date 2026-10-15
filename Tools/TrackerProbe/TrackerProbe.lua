-- TrackerProbe: Glass Quest Tracker's developer probe, a ForeverProbe module
-- (/fp gqt). Never shipped. Its lines go to the ForeverProbe console and to
-- TrackerProbeDB.log, never to chat; read them from
-- WTF\Account\<account>\SavedVariables\TrackerProbe.lua after a /reload.
--
--   /fp gqt frames       P1 P2 P8 P9: the tracker, its modules, blocks and lines, fonts, other addons
--   /fp gqt nine         P3: NineSlice and Header anchors, collapsed state; toggles a red overlay on NineSlice
--   /fp gqt cvars        P4: autoQuestWatch, questPOI, the watch limit
--   /fp gqt accept on|off|watch   P5: log QUEST_ACCEPTED (watch: also AddQuestWatch from addon code)
--   /fp gqt hook         P6: taint pass A (hooks + a child panel), kept across /reload
--   /fp gqt restyle      P7: taint pass B (pass A + fade, blank, shadows, tint), kept across /reload
--   /fp gqt off          no pass at the next /reload
--   /fp gqt counts       how often each hook ran
--   /fp gqt routine      which taint-pass steps this session has covered (also logged at logout)
--   /fp gqt state        Glass Quest Tracker's look as the addon holds it
--   /fp gqt clear        empty the log
--   /fp steps gqt look   #3's in-game checks, a guided procedure with screenshots
--
-- The passes are the probe's own stand-ins for the skin (#2). They refuse to
-- install while Glass Quest Tracker is loaded: two skins on one tracker
-- measure nothing, and the probe no longer has to be disabled to test the
-- addon. The host logs ADDON_ACTION_BLOCKED / FORBIDDEN itself.
--
-- It follows the addon's own rule: only C widget methods on Blizzard objects,
-- no field writes on their tables, state in our own tables. The addon's
-- state is read through its global table; the look procedure changes it
-- only with /gqt, as typed, and puts the owner's theme and opacity back.

local ADDON, NS = ...
local MAX_LOG = 3000
local Probe = ForeverProbe:Module("TrackerProbe", { api = 1, cmd = "gqt" })

local LOADED_AT_FILE_SCOPE = {
    tracker = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker"),
    frame = rawget(_G, "ObjectiveTrackerFrame") ~= nil,
}

local db
local function str(v) return Probe.Show(v, true) end
local function say(msg) Probe:Say(msg) end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) == true end

-- A method's results, or "err:..." when it throws.
local function call(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return "n/a" end
    local r = { pcall(obj[method], obj, ...) }
    if not r[1] then return "err:" .. str(r[2]) end
    local out = {}
    for i = 2, #r do out[#out + 1] = str(r[i]) end
    if #out == 0 then return "nil" end
    return table.concat(out, ",")
end

-- A getter's first result as a plain value, or nil (missing, throws, secret).
local function get(obj, method)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return nil end
    local ok, v = pcall(obj[method], obj)
    if not ok or secret(v) then return nil end
    return v
end

local function tracker() return rawget(_G, "ObjectiveTrackerFrame") end
local function addon() return rawget(_G, "GlassQuestTracker") end

local FALLBACK_MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

-- The modules the container holds, else every known global module.
local function modules()
    local t, list = tracker(), {}
    if t and type(t.modules) == "table" and #t.modules > 0 then
        for _, m in ipairs(t.modules) do list[#list + 1] = m end
        return list, "container"
    end
    for _, name in ipairs(FALLBACK_MODULES) do
        local m = rawget(_G, name)
        if m then list[#list + 1] = m end
    end
    return list, "globals"
end

local function moduleName(m)
    for _, name in ipairs(FALLBACK_MODULES) do
        if rawget(_G, name) == m then return name end
    end
    return call(m, "GetName")
end

local function eachBlock(m, fn)
    if type(m.usedBlocks) ~= "table" then return end
    for _, blocks in pairs(m.usedBlocks) do
        if type(blocks) == "table" then
            for _, block in pairs(blocks) do fn(block) end
        end
    end
end

local function eachLine(block, fn)
    if type(block.usedLines) ~= "table" then return end
    for _, line in pairs(block.usedLines) do fn(line) end
end

--------------------------------------------------------------------------------
-- P1 P2 P8 P9: frames
--------------------------------------------------------------------------------

local function frames()
    local t = tracker()
    say("build " .. table.concat({ GetBuildInfo() }, " "))
    say("P1 at file scope: Blizzard_ObjectiveTracker loaded=" .. str(LOADED_AT_FILE_SCOPE.tracker)
        .. " ObjectiveTrackerFrame exists=" .. str(LOADED_AT_FILE_SCOPE.frame))
    if not t then return say("P1 ObjectiveTrackerFrame: MISSING") end
    say("P1 tracker: protected=" .. call(t, "IsProtected") .. " strata=" .. call(t, "GetFrameStrata")
        .. " level=" .. call(t, "GetFrameLevel") .. " size=" .. call(t, "GetSize") .. " scale=" .. call(t, "GetScale")
        .. " shown=" .. call(t, "IsShown") .. " visible=" .. call(t, "IsVisible") .. " alpha=" .. call(t, "GetAlpha"))
    say("P1 tracker: inDefault=" .. call(t, "IsInDefaultPosition") .. " editModeHeight=" .. str(t.editModeHeight)
        .. " isCollapsed=" .. str(t.isCollapsed) .. " points=" .. call(t, "GetNumPoints")
        .. " top=" .. call(t, "GetTop") .. " bottom=" .. call(t, "GetBottom"))
    if t.NineSlice then
        say("P2 NineSlice: alpha=" .. call(t.NineSlice, "GetAlpha") .. " level=" .. call(t.NineSlice, "GetFrameLevel")
            .. " top=" .. call(t.NineSlice, "GetTop") .. " bottom=" .. call(t.NineSlice, "GetBottom")
            .. " shown=" .. call(t.NineSlice, "IsShown"))
    end
    local h = t.Header
    if h then
        say("P2 Header: text=" .. call(h.Text, "GetText") .. " bg atlas=" .. call(h.Background, "GetAtlas")
            .. " minimize=" .. str(h.MinimizeButton ~= nil) .. " filter shown=" .. call(h.FilterButton, "IsShown"))
    end
    local list, from = modules()
    say("P2 modules (" .. from .. "): " .. #list)
    for _, m in ipairs(list) do
        local blocks, lines, items = 0, 0, 0
        eachBlock(m, function(b)
            blocks = blocks + 1
            if b.ItemButton then items = items + 1 end
            eachLine(b, function() lines = lines + 1 end)
        end)
        say(("P2  %s order=%s shown=%s collapsed=%s contentsHeight=%s headerHeight=%s blocks=%d lines=%d items=%d")
            :format(moduleName(m), str(m.uiOrder), call(m, "IsShown"), str(m.isCollapsed), str(m.contentsHeight),
                str(m.headerHeight), blocks, lines, items))
        if m.Header then
            say("P2    header: text=" .. call(m.Header.Text, "GetText") .. " bg=" .. call(m.Header.Background, "GetAtlas")
                .. " AddAnim=" .. str(m.Header.AddAnim ~= nil))
        end
        local shown = 0
        eachBlock(m, function(b)
            shown = shown + 1
            if shown > 2 then return end
            say("P2    block: header=" .. call(b.HeaderText, "GetText") .. " top=" .. call(b, "GetTop")
                .. " shown=" .. call(b, "IsShown") .. " item=" .. str(b.ItemButton ~= nil))
            if b.ItemButton then
                say("P2      item: normal=" .. call(b.ItemButton:GetNormalTexture(), "GetTexture")
                    .. " pushed=" .. str(b.ItemButton:GetPushedTexture() ~= nil) .. " protected="
                    .. call(b.ItemButton, "IsProtected"))
            end
            eachLine(b, function(line)
                say("P2      line: text=" .. call(line.Text, "GetText") .. " dash=" .. str(line.Dash ~= nil)
                    .. " icon=" .. str(line.Icon ~= nil))
            end)
        end)
        if type(m.usedRightEdgeFrames) == "table" then
            local n = 0
            for _ in pairs(m.usedRightEdgeFrames) do n = n + 1 end
            say("P2    right-edge frames: " .. n)
        end
    end
    -- P8 fonts.
    for _, name in ipairs({ "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont" }) do
        local f = rawget(_G, name)
        say("P8 " .. name .. ": font=" .. call(f, "GetFont") .. " shadow=" .. call(f, "GetShadowOffset")
            .. " color=" .. call(f, "GetShadowColor"))
    end
    -- P9 other trackers.
    for _, a in ipairs({ "Questie", "RXPGuides", "ForeverUI", "DialogueUI", "Leatrix_Plus", "ElvUI" }) do
        local ok, on = pcall(C_AddOns.IsAddOnLoaded, a)
        if ok and on then say("P9 loaded: " .. a) end
    end
end

--------------------------------------------------------------------------------
-- P3: NineSlice
--------------------------------------------------------------------------------

local overlay
local function points(f)
    if not f then return "n/a" end
    local ok, n = pcall(f.GetNumPoints, f)
    if not ok then return "err" end
    if secret(n) then return "<secret>" end
    local out = {}
    for i = 1, (type(n) == "number" and n or 0) do
        local p = { pcall(f.GetPoint, f, i) }
        if p[1] then
            -- GetPoint: point, relativeTo, relativePoint, x, y. Its results are
            -- SecretWhenAnchoringSecret (70374 docs): never compare a secret anchor.
            local rel = p[3]
            local t = tracker() or {}
            local relName
            if secret(rel) then relName = "<secret>"
            elseif rel == nil then relName = "nil"
            elseif rel == t then relName = "tracker"
            elseif rel == t.Header then relName = "Header"
            elseif rel == t.NineSlice then relName = "NineSlice"
            else relName = call(rel, "GetName") end
            out[#out + 1] = ("%s->%s.%s(%s,%s)"):format(str(p[2]), relName, str(p[4]), str(p[5]), str(p[6]))
        end
    end
    return n .. ": " .. table.concat(out, " ")
end

local function nine()
    local t = tracker()
    if not t then return say("P3 no tracker") end
    -- Edit Mode's frame being shown, not IsEditModeActive: that's Blizzard Lua.
    say("P3 isCollapsed=" .. str(t.isCollapsed) .. " editMode=" .. call(rawget(_G, "EditModeManagerFrame"), "IsShown")
        .. " shown=" .. call(t, "IsShown"))
    say("P3 NineSlice points " .. points(t.NineSlice))
    say("P3 NineSlice top=" .. call(t.NineSlice, "GetTop") .. " bottom=" .. call(t.NineSlice, "GetBottom")
        .. " height=" .. call(t.NineSlice, "GetHeight"))
    say("P3 Header points " .. points(t.Header) .. " bottom=" .. call(t.Header, "GetBottom"))
    if not overlay then
        overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetFrameStrata("HIGH")
        local tex = overlay:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 0, 0, 0.25)
        overlay:SetPoint("TOPLEFT", t.NineSlice, "TOPLEFT")
        overlay:SetPoint("BOTTOMRIGHT", t.NineSlice, "BOTTOMRIGHT")
        overlay:Hide()
    end
    overlay:SetShown(not overlay:IsShown())
    say("P3 red overlay on NineSlice: " .. (overlay:IsShown() and "on (look at it collapsed, empty, in Edit Mode)" or "off"))
    say("P3 overlay IsMouseOver=" .. call(overlay, "IsMouseOver"))
end

--------------------------------------------------------------------------------
-- P4 P5: watches
--------------------------------------------------------------------------------

local function cvars()
    for _, name in ipairs({ "autoQuestWatch", "questPOI" }) do
        local info = C_CVar and C_CVar.GetCVarInfo and { pcall(C_CVar.GetCVarInfo, name) }
        say("P4 " .. name .. ": GetCVar=" .. str(GetCVar(name)) .. " info=" .. (info and info[1]
            and (str(info[2]) .. " default=" .. str(info[3])) or "n/a"))
    end
    local c = Constants and Constants.QuestWatchConsts
    say("P4 Constants.QuestWatchConsts.MAX_QUEST_WATCHES=" .. str(c and c.MAX_QUEST_WATCHES)
        .. " MAX_WATCHABLE_QUESTS=" .. str(rawget(_G, "MAX_WATCHABLE_QUESTS"))
        .. " GetNumQuestWatches=" .. str(C_QuestLog.GetNumQuestWatches()))
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    say("P4 quests in log=" .. str(numQuests))
end

local function watchType(questID) return str(C_QuestLog.GetQuestWatchType(questID)) end

local function onAccepted(...)
    if not db.accept then return end
    local n = select("#", ...)
    local questID = ...
    say("P5 QUEST_ACCEPTED args=" .. n .. " questID=" .. str(questID) .. " type=" .. type(questID)
        .. " watchType now=" .. watchType(questID) .. " logIndex=" .. str(C_QuestLog.GetLogIndexForQuestID(questID)))
    if db.accept == "watch" then
        local ok, r = pcall(C_QuestLog.AddQuestWatch, questID)
        say("P5 AddQuestWatch now: ok=" .. str(ok) .. " returned=" .. str(r) .. " watchType=" .. watchType(questID))
    end
    C_Timer.After(0, function()
        say("P5 next frame: watchType=" .. watchType(questID) .. " watches=" .. str(C_QuestLog.GetNumQuestWatches()))
        if db.accept == "watch" and C_QuestLog.GetQuestWatchType(questID) == nil then
            local ok, r = pcall(C_QuestLog.AddQuestWatch, questID)
            say("P5 AddQuestWatch next frame: ok=" .. str(ok) .. " returned=" .. str(r) .. " watchType=" .. watchType(questID))
        end
    end)
end

--------------------------------------------------------------------------------
-- P6 P7: taint passes
--------------------------------------------------------------------------------

local counts = {}
local installed = false
local panel
local styled = setmetatable({}, { __mode = "k" })
local faded = setmetatable({}, { __mode = "k" })

-- The routine, recorded as it happens: a short run shows as unchecked steps
-- instead of passing for a clean one.
local ROUTINE = {
    { "accept",   "accept a quest" },
    { "progress", "advance an objective (kill, loot or talk for a tracked quest)" },
    { "turnin",   "turn a quest in" },
    { "collapse", "collapse and expand the tracker (the button at its top right) and a section (Quests)" },
    { "editmode", "Edit Mode: select the tracker, move it, change Height, Text Size and Opacity, save, close" },
    { "combat",   "fight something" },
    { "instance", "enter a dungeon (any instance) with quests tracked" },
}
local seen = {}
-- Collapse is only done when both headers went both ways: the container's
-- expand is what re-anchors the panel to the NineSlice (Codex, PR #10).
local collapses = { container = {}, section = {} }

-- A step counts only once a pass is installed: the routine has to exercise
-- the hooks, not happen before them (Codex, PR #10).
local function credit(step)
    if installed then seen[step] = true end
end

local function collapsed(kind, down)
    if not installed then return end
    collapses[kind][down and "collapsed" or "expanded"] = true
    local c, s = collapses.container, collapses.section
    if c.collapsed and c.expanded and s.collapsed and s.expanded then seen.collapse = true end
end

local function count(key)
    counts[key] = (counts[key] or 0) + 1
    if key == "EditMode:hide" then credit("editmode") end
end

local function showRoutine()
    local missing = 0
    for _, step in ipairs(ROUTINE) do
        if not seen[step[1]] then missing = missing + 1 end
        say("routine [" .. (seen[step[1]] and "x" or " ") .. "] " .. step[2])
    end
    if not seen.collapse then
        local function done(kind, dir) return collapses[kind][dir] and dir or ("not " .. dir) end
        say("  collapse so far: tracker " .. done("container", "collapsed") .. ", " .. done("container", "expanded")
            .. "; section " .. done("section", "collapsed") .. ", " .. done("section", "expanded"))
    end
    say(missing == 0 and "routine complete: log out (don't just /reload) so taint.log is written"
        or ("routine: " .. missing .. " step(s) left"))
end

-- Something is laid out: any module the container shows.
local function populated()
    for _, m in ipairs((modules())) do
        local ok, shown = pcall(m.IsShown, m)
        if ok and not secret(shown) and shown then return true end
    end
    return false
end

-- The child panel, anchored the way Panel.lua will be.
local function placePanel()
    local t = tracker()
    if not (t and panel) then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", t.NineSlice, "TOPLEFT", 16, 0)
    local down = t.isCollapsed == true
    if down or not populated() then
        panel:SetPoint("BOTTOMRIGHT", t.Header, "BOTTOMRIGHT", 0, -4)
        count("panel:header")
    else
        panel:SetPoint("BOTTOMRIGHT", t.NineSlice, "BOTTOMRIGHT", -2, 0)
        count("panel:nineslice")
    end
end

local function refade(region)
    local s = faded[region]
    if not s or s.busy then return end
    s.busy = true
    pcall(region.SetAlpha, region, 0)
    s.busy = false
end

local function fade(region)
    if type(region) ~= "table" or faded[region] then return end
    faded[region] = {}
    for _, m in ipairs({ "Show", "SetShown", "SetAlpha" }) do
        if type(region[m]) == "function" then
            hooksecurefunc(region, m, function(self) count("refade"); refade(self) end)
        end
    end
    refade(region)
end

local function shade(fs)
    if type(fs) ~= "table" or styled[fs] or not fs.SetShadowOffset then return end
    styled[fs] = true
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
end

local function blank(tex)
    if type(tex) ~= "table" or styled[tex] or not tex.SetTexture then return end
    styled[tex] = true
    tex:SetTexture(nil)
end

local function tint(button)
    if type(button) ~= "table" or styled[button] then return end
    styled[button] = true
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local tex = button[getter] and button[getter](button)
        if tex then tex:SetDesaturated(true); tex:SetVertexColor(0.75, 0.9, 1) end
    end
    local hl = button.GetHighlightTexture and button:GetHighlightTexture()
    if hl then hl:SetAlpha(0.3) end
end

local function restyleModule(m)
    if m.Header then
        blank(m.Header.Background); blank(m.Header.Shine); blank(m.Header.Glow)
        shade(m.Header.Text)
        tint(m.Header.MinimizeButton)
    end
    eachBlock(m, function(b)
        shade(b.HeaderText)
        if b.ItemButton then
            local n, p = b.ItemButton:GetNormalTexture(), b.ItemButton:GetPushedTexture()
            if n then fade(n) end
            if p then fade(p) end
        end
        eachLine(b, function(line) shade(line.Text); shade(line.Dash) end)
    end)
end

local function restyleAll()
    local t = tracker()
    fade(t.NineSlice)
    if t.Header then
        fade(t.Header.Background)
        shade(t.Header.Text)
        tint(t.Header.MinimizeButton)
    end
    for _, m in ipairs((modules())) do restyleModule(m) end
end

-- True when the pass is on (installed now, or already this session).
local function install(mode)
    if installed then say("pass already installed this session; /reload to change it"); return true end
    if addon() then
        say("pass " .. mode .. " refused: Glass Quest Tracker is loaded, and its own skin is on the tracker."
            .. " Disable the addon to run a probe pass.")
        return false
    end
    local t = tracker()
    if not t then say("P6 no tracker"); return false end
    installed = true   -- from here on the routine counts (credit)
    panel = CreateFrame("Frame", nil, t)
    panel:SetFrameLevel(t:GetFrameLevel())
    local tex = panel:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(0.1, 0.5, 1, 0.18)
    local list, from = modules()
    for _, m in ipairs(list) do
        local name = moduleName(m)
        hooksecurefunc(m, "EndLayout", function(self)
            count("EndLayout:" .. name)
            placePanel()
            if mode == "B" then restyleModule(self) end
        end)
        if m.Header and m.Header.SetCollapsed then
            hooksecurefunc(m.Header, "SetCollapsed", function(_, down)
                count("SetCollapsed:" .. name)
                collapsed("section", down)
            end)
        end
    end
    if t.Header and t.Header.SetCollapsed then
        hooksecurefunc(t.Header, "SetCollapsed", function(_, down)
            count("SetCollapsed:container")
            collapsed("container", down)
            placePanel()
        end)
    end
    local em = rawget(_G, "EditModeManagerFrame")
    if em then
        em:HookScript("OnShow", function() count("EditMode:show") end)
        em:HookScript("OnHide", function() count("EditMode:hide"); placePanel() end)
    end
    placePanel()
    if mode == "B" then restyleAll() end
    if IsInInstance() then credit("instance") end   -- installed after entering one
    say("pass " .. mode .. " installed on " .. #list .. " modules (" .. from .. "). Now /console taintLog 1 and run the routine.")
    return true
end

local function showCounts()
    local keys = {}
    for k in pairs(counts) do keys[#keys + 1] = k end
    table.sort(keys)
    if #keys == 0 then return say("no hook has run") end
    for _, k in ipairs(keys) do say(k .. " = " .. counts[k]) end
end

--------------------------------------------------------------------------------
-- Glass Quest Tracker's look, as the addon holds it (#3)
--------------------------------------------------------------------------------

-- Plain values only, nil where the addon or a region is missing.
local function lookState()
    local G = addon()
    if type(G) ~= "table" or type(G.Panel) ~= "table" or type(G.Panel._test) ~= "table" then return nil end
    local p, g, t = G.Panel._test.frame(), G.Panel._test.g(), tracker()
    local failures = 0
    for _ in pairs(G.failures or {}) do failures = failures + 1 end
    return {
        started = G.Skin ~= nil and G.Skin.started == true,
        theme = G.Theme.Name(),
        backing = G.Theme.BackingAlpha(),
        glass = p ~= nil and get(p, "IsShown") == true,
        panel = G.Panel.state,
        wash = g ~= nil and get(g.wash, "IsShown") == true,
        nine = t and get(t.NineSlice, "GetAlpha"),
        bar = t and t.Header and get(t.Header.Background, "GetAlpha"),
        collapsed = G.Tracker.IsCollapsed() == true,
        failures = failures,
    }
end

local function describe(s)
    if not s then return "Glass Quest Tracker isn't loaded" end
    return ("theme=%s backing=%s glass=%s panel=%s wash=%s nineslice=%s headerbar=%s collapsed=%s failures=%d")
        :format(str(s.theme), str(s.backing), str(s.glass), str(s.panel), str(s.wash), str(s.nine), str(s.bar),
            str(s.collapsed), s.failures)
end

-- The addon's own command, as the owner would type it.
local function gqt(args)
    local cmd = SlashCmdList and SlashCmdList.GLASSQUESTTRACKER
    if type(cmd) ~= "function" then error("/gqt isn't registered: is Glass Quest Tracker loaded?", 0) end
    cmd(args)
    local s = lookState()
    say("/gqt " .. args .. " -> " .. describe(s))
    return describe(s)
end

-- Checks: the state, then whether it is what the step wanted.
local function expect(want)
    return function()
        local s = lookState()
        if not s then return false, describe(s) end
        for k, v in pairs(want) do
            if s[k] ~= v then return false, "want " .. k .. "=" .. str(v) .. ": " .. describe(s) end
        end
        return true, describe(s)
    end
end

-- The glass on: the panel shown, the wash hidden (a gradient ignores
-- SetAlpha on 70374), the stock background and header bar faded.
local function glassOn(extra)
    local want = { started = true, glass = true, wash = false, nine = 0, bar = 0 }
    for k, v in pairs(extra or {}) do want[k] = v end
    return expect(want)
end

local function opacity(name)
    local G = addon()
    return G and G.Theme and G.Theme.OPACITY and G.Theme.OPACITY[name]
end

Probe:Steps("look", {
    title = "Glass Quest Tracker: the glass look (#3)",
    rev = 1,
    { text = "Reading Glass Quest Tracker's state, and your theme and opacity, to put back at the end.",
      auto = true, run = function()
          local G, s = addon(), lookState()
          if G and G.db then db.look = { theme = G.Theme.Name(), opacity = G.db.opacity or "medium" } end
          return describe(s)
      end,
      check = function()
          local s = lookState()
          return s ~= nil and s.started, describe(s)
      end },
    { text = "Clear glass at medium opacity: the baseline. Have a few quests tracked and the tracker expanded, then press Clear.",
      button = "Clear", run = function() gqt("theme clear"); return gqt("opacity medium") end,
      check = glassOn({ theme = "clear" }), screenshot = "clear, medium" },
    { text = "Smoked glass.", button = "Smoked", run = function() return gqt("theme smoked") end,
      check = glassOn({ theme = "smoked" }), screenshot = "smoked" },
    { text = "Class colour glass.", button = "Class", run = function() return gqt("theme class") end,
      check = glassOn({ theme = "class" }), screenshot = "class" },
    { text = "Blizzard's own tracker: the stock theme.", button = "Stock", run = function() return gqt("theme stock") end,
      check = expect({ theme = "stock", glass = false, bar = 1 }), screenshot = "stock" },
    { text = "Does it look exactly like Blizzard's own tracker: the gold header bars and gold buttons back, no glass?",
      ask = true },
    { text = "Back to clear glass.", button = "Clear", run = function() return gqt("theme clear") end,
      check = glassOn({ theme = "clear" }) },
    { text = "Opacity light: more of the world shows through.", button = "Light",
      run = function() return gqt("opacity light") end,
      check = function()
          local s = lookState()
          return s ~= nil and s.backing == opacity("light"), describe(s)
      end, screenshot = "opacity light" },
    { text = "Opacity solid.", button = "Solid", run = function() return gqt("opacity solid") end,
      check = function()
          local s = lookState()
          return s ~= nil and s.backing == opacity("solid"), describe(s)
      end, screenshot = "opacity solid" },
    { text = "Back to medium.", button = "Medium", run = function() return gqt("opacity medium") end,
      check = function()
          local s = lookState()
          return s ~= nil and s.backing == opacity("medium"), describe(s)
      end },
    { text = "Look at the '-' button right of the 'Quests' section title. Is it fully on the glass, with a little glass to its right?",
      ask = true, screenshot = "right edge" },
    { text = "Collapse the whole tracker: click the button at the top right, beside 'All Objectives'. Then press Next.",
      check = glassOn({ collapsed = true, panel = "header" }), screenshot = "collapsed" },
    { text = "Expand it again, then press Next.",
      check = glassOn({ collapsed = false, panel = "populated" }) },
    { text = "Collapse the 'Quests' section with its '-' button, then press Next.",
      check = glassOn({ panel = "populated" }), screenshot = "section collapsed" },
    { text = "Expand the section again, then press Next.",
      check = glassOn({ panel = "populated" }) },
    { text = "While you did that (or when a section first appeared), did you see any gold bar or shine flash behind a section title? Note when.",
      ask = true },
    { text = "Open Edit Mode, click the tracker, drag it a little and change its Height. Then close Edit Mode (Save or Revert) and press Next.",
      check = glassOn({ panel = "populated" }), screenshot = "after Edit Mode" },
    { text = "Stand or turn so the tracker is over bright ground or sky. Is every line easy to read?",
      ask = true, screenshot = "bright background" },
    { text = "Glass Quest Tracker's failures (/gqt failures).", auto = true,
      run = function()
          local G, keys = addon(), {}
          for k, v in pairs(G and G.failures or {}) do keys[#keys + 1] = k .. ": " .. str(v) end
          table.sort(keys)
          for _, k in ipairs(keys) do say("failure " .. k) end
          return #keys
      end,
      check = function()
          local s = lookState()
          return s ~= nil and s.failures == 0, describe(s)
      end },
    { text = "Putting your theme and opacity back.", auto = true,
      run = function()
          local was = db.look or {}
          gqt("theme " .. (was.theme or "clear"))
          return gqt("opacity " .. (was.opacity or "medium"))
      end,
      check = function()
          local was, s = db.look or {}, lookState()
          return s ~= nil and s.theme == (was.theme or "clear") and s.backing == opacity(was.opacity or "medium"),
              describe(s)
      end },
    { text = "That's all. Type /reload (or press Reload now) so the results and the screenshot names are saved.",
      reload = true },
})

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

Probe:Command("frames", function() frames() end, "P1 P2 P8 P9: the tracker, modules, blocks, fonts, other addons")
Probe:Command("nine", function() nine() end, "P3: NineSlice and Header anchors; toggles a red overlay")
Probe:Command("cvars", function() cvars() end, "P4: autoQuestWatch, questPOI, the watch limit")
Probe:Command("accept", function(args)
    local arg = (args or ""):lower():match("^%s*(%S*)")
    db.accept = (arg == "on" and true) or (arg == "watch" and "watch") or nil
    say("accept logging: " .. str(db.accept))
end, "on|off|watch - P5: log QUEST_ACCEPTED (watch: also AddQuestWatch)")
-- Kept across /reload only when it installed: a refused pass isn't retried.
Probe:Command("hook", function() if install("A") then db.mode = "A" end end, "P6: taint pass A, kept across /reload")
Probe:Command("restyle", function() if install("B") then db.mode = "B" end end, "P7: taint pass B, kept across /reload")
Probe:Command("off", function() db.mode = nil; say("no pass at the next /reload") end, "no pass at the next /reload")
Probe:Command("counts", function() showCounts() end, "how often each hook ran")
Probe:Command("routine", function() showRoutine() end, "which taint-pass steps this session has covered")
Probe:Command("state", function() say(describe(lookState())) end, "Glass Quest Tracker's look as the addon holds it")
Probe:Command("clear", function() Probe:ClearLog(); say("log cleared") end, "empty the saved log")

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

local boot = CreateFrame("Frame")
Probe:RegisterEvents(boot, { "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "QUEST_ACCEPTED",
    "QUEST_WATCH_UPDATE", "QUEST_TURNED_IN", "PLAYER_REGEN_DISABLED", "LUA_WARNING" })
boot:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON then
        Probe:Ready()
        if type(TrackerProbeDB) ~= "table" then TrackerProbeDB = {} end
        db = TrackerProbeDB
        if type(db.log) ~= "table" then db.log = {} end
        Probe:UseLog(db.log, MAX_LOG)
        say("session start, build " .. table.concat({ GetBuildInfo() }, " ") .. ", pass=" .. str(db.mode)
            .. ", accept=" .. str(db.accept) .. ", Glass Quest Tracker " .. (addon() and "loaded" or "not loaded"))
    elseif not db or event == "ADDON_LOADED" then
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- taint.log is only written while this is on; it isn't saved across sessions.
        local taintLog, inInstance, kind = GetCVar("taintLog"), IsInInstance()
        if inInstance then credit("instance") end
        say("world: taintLog=" .. str(taintLog) .. " instance=" .. str(inInstance) .. "," .. str(kind))
        if db.mode and taintLog == "0" then say("taintLog is OFF: /console taintLog 1 before the routine") end
        -- The tracker's modules arrive after PLAYER_ENTERING_WORLD + VARIABLES_LOADED.
        if db.mode and not installed then
            C_Timer.After(1, function()
                if not install(db.mode) then db.mode = nil end   -- refused: forget it
            end)
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Also runs on /reload: every session leaves its counts and routine in the log.
        if installed then showCounts(); showRoutine() end
    elseif event == "QUEST_ACCEPTED" then
        credit("accept")
        onAccepted(...)
    elseif event == "QUEST_WATCH_UPDATE" then
        credit("progress")
    elseif event == "QUEST_TURNED_IN" then
        credit("turnin")
    elseif event == "PLAYER_REGEN_DISABLED" then
        credit("combat")
    elseif event == "LUA_WARNING" then
        say("LUA_WARNING " .. str((select(2, ...)) or (...)))
    end
end)

NS._test = { Probe = Probe, lookState = lookState, credit = credit, seen = seen }
