-- GlassQuestTracker.lua: bootstrap, saved settings and the /gqt command.
-- Loads last: every module is defined by now.

local ADDON = ...
GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local API = GQT.API
local say = API.Print

-- GlassQuestTrackerDB, account-wide. Only what the player SET is saved: the
-- rest falls through to DEFAULTS, so a changed default reaches everyone
-- (GlassMail's rule).
local DEFAULTS = {
    theme = "clear",      -- Theme.NAMES
    opacity = "medium",   -- Theme.OPACITY_NAMES: the backing under the glass
}
GQT.DEFAULTS = DEFAULTS

local function ensureDefaults()
    if type(GlassQuestTrackerDB) ~= "table" then GlassQuestTrackerDB = {} end
    local db = setmetatable(GlassQuestTrackerDB, nil)
    for k, v in pairs(DEFAULTS) do
        if db[k] == v then db[k] = nil end
    end
    setmetatable(db, { __index = DEFAULTS })
    return db
end

-- Save a setting: a value equal to its default is not stored.
function GQT.Set(key, value)
    if DEFAULTS[key] == value then GQT.db[key] = nil else GQT.db[key] = value end
end

-- A dev build, by its version: "dev" from the deploy script, or the
-- packager's token left unreplaced (matched as a pattern, never written whole:
-- the packager would replace it here too). Unreadable is NOT dev.
function GQT.IsDev()
    local v = API.AddOnVersion(ADDON or "GlassQuestTracker")
    return v ~= nil and (v == "dev" or v:find("@project%-version@") ~= nil)
end

function GQT.VersionText()
    local v = API.AddOnVersion(ADDON or "GlassQuestTracker")
    if v == nil or v == "" or GQT.IsDev() then return "dev" end
    return v
end

local function failures()
    local any = false
    for key, err in pairs(GQT.failures) do
        any = true
        say(key .. ": " .. err)
    end
    if not any then say("no failures recorded") end
end

-- The command list: /gqt help prints it.
local function helpLines()
    return {
        "/gqt theme clear|smoked|class|stock - the glass, or Blizzard's own tracker",
        "/gqt opacity light|medium|solid - the backing under the glass",
        "/gqt failures - what failed to build or register",
        "/gqt version - client build vs the measured one",
    }
end
GQT.HelpLines = helpLines

-- /gqt theme and /gqt opacity: one of `names`, saved and applied now.
local function choose(key, arg, valid, names)
    if not valid(arg) then
        say(key .. " is " .. GQT.db[key] .. " (" .. table.concat(names, ", ") .. ")")
        return
    end
    GQT.Set(key, arg)
    GQT.Skin.Apply()
    say(key .. ": " .. arg)
end

local function slash(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if cmd == "theme" then
        choose("theme", arg, GQT.Theme.IsValid, GQT.Theme.NAMES)
    elseif cmd == "opacity" then
        choose("opacity", arg, GQT.Theme.IsValidOpacity, GQT.Theme.OPACITY_NAMES)
    elseif cmd == "failures" then
        failures()
    elseif cmd == "version" then
        say("version " .. GQT.VersionText() .. ", client " .. API.ClientBuild()
            .. ", measured on " .. GQT.MEASURED_ON_BUILD)
    else
        for _, line in ipairs(helpLines()) do say(line) end
    end
end

SLASH_GLASSQUESTTRACKER1 = "/gqt"
SLASH_GLASSQUESTTRACKER2 = "/glassquesttracker"
SlashCmdList.GLASSQUESTTRACKER = slash

local boot = CreateFrame("Frame")
boot:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then GQT.db = ensureDefaults() end
    elseif event == "PLAYER_LOGIN" then
        -- SavedVariables are read here at the latest (porting guide: not at file scope).
        if not GQT.db then GQT.db = ensureDefaults() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The module instances exist from load; one frame later the tracker's
        -- own PLAYER_ENTERING_WORLD work has run. Start is once a session.
        C_Timer.After(0, function()
            GQT.Skin.Start()
            GQT.Theme.Retry()
        end)
        -- arg1 = isInitialLogin. The build warning asks the developer to re-measure.
        if arg1 and GQT.IsDev() and API.ClientBuild() ~= GQT.MEASURED_ON_BUILD then
            say("client build " .. API.ClientBuild() .. " differs from the one this addon was measured on ("
                .. GQT.MEASURED_ON_BUILD .. "). Things may misbehave until it is re-checked.")
        end
    end
end)
API.RegisterEvents(boot, { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }, "boot")

GQT._test = { ensureDefaults = ensureDefaults, DEFAULTS = DEFAULTS, slash = slash }
