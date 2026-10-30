-- Compat.lua: the one place this addon touches client APIs that moved, may be
-- absent, or behave differently on WoW: Forever. Everything else calls through
-- GlassQuestTracker.API. Nothing is injected into _G.
--
-- Glass MiniMap's Compat.lua (itself GlassMail's): failures, events, version,
-- class colour, the options registration; plus Fade, Blank and Tint, the
-- C-method-only ways the tracker's art steps aside.

GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local API = {}
GQT.API = API

-- The build the notes in docs/ were measured on. Bump only after re-measuring
-- in game; tests/test_toc.lua pins the same literal.
GQT.MEASURED_ON_BUILD = "1.60.1.70374"

function API.Print(msg)
    print("|cff7fd4ffGlassQuestTracker|r " .. msg)
end

-- True for a Retail secret value: it may be handed back to the client but
-- never compared, concatenated or truth-tested in Lua.
function API.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- v, or nil when it is secret.
function API.Plain(v)
    if API.IsSecret(v) then return nil end
    return v
end

function API.ClientBuild()
    local version, build = GetBuildInfo()
    return tostring(version) .. "." .. tostring(build)
end

-- The one failure recorder: key -> first error, read by /gqt failures.
GQT.failures = GQT.failures or {}
function API.Fail(key, err)
    if GQT.failures[key] ~= nil then return end
    local msg = "(unprintable error)"
    if type(err) == "string" then
        msg = err
    elseif not API.IsSecret(err) then
        local ok, s = pcall(tostring, err)
        if ok and type(s) == "string" then msg = s end
    end
    GQT.failures[key] = msg
end

-- Run fn under pcall; a throw is recorded under `key` and nil is returned.
function API.Try(key, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    API.Fail(key, a)
    return nil
end

-- RegisterEvent throws on an unknown name and returns false on a refusal.
-- Both count as failure, and every failure is reported: a silently missing
-- handler is the bug this exists to prevent.
function API.RegisterEvent(frame, name, who)
    local ok, registered = pcall(frame.RegisterEvent, frame, name)
    if ok and registered ~= false then return true end
    local why = ok and "refused" or tostring(registered)
    API.Fail("event:" .. name, (who and (who .. ": ") or "") .. why)
    API.Print("|cffff6060could not register|r " .. name .. " (" .. why .. ")")
    return false
end

function API.RegisterEvents(frame, events, who)
    for _, name in ipairs(events) do API.RegisterEvent(frame, name, who) end
end

-- An addon's TOC Version, or nil (absent API, error, secret, not a string).
function API.AddOnVersion(addon)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, addon, "Version")
    if not ok or API.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

function API.IsAddOnLoaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return ok and API.Plain(loaded) == true
end

function API.CVarBool(name)
    local ok, on = pcall(GetCVarBool, name)
    return ok and API.Plain(on) == true
end

-- The player's class colour (plain numbers), or nil (GlassPanel's).
function API.ClassColor()
    local ok, _, class = pcall(UnitClass, "player")
    class = ok and API.Plain(class) or nil
    if type(class) ~= "string" then return nil end
    local ok2, c = pcall(C_ClassColor.GetClassColor, class)
    if not ok2 or type(c) ~= "table" then return nil end
    local r, g, b = API.Plain(c.r), API.Plain(c.g), API.Plain(c.b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return r, g, b
end

--------------------------------------------------------------------------------
-- Stepping Blizzard's tracker art aside: C widget methods only
--------------------------------------------------------------------------------

-- The tracker is an Edit Mode system that taints when moved, hidden or driven
-- (CLAUDE.md, "The UI contract"). So its art is never Hide()n: Fade sets
-- alpha 0, Blank drops a texture's image, Tint recolours one. Each keeps
-- what it changed in our own weak table, never a field on theirs, and gives
-- it back on the matching Un- call (the "stock" theme).

local faded = setmetatable({}, { __mode = "k" })   -- region -> { alpha = , busy = }
local fadeHooked = setmetatable({}, { __mode = "k" })

local function refade(region)
    local s = faded[region]
    if not s or s.busy then return end
    s.busy = true                                    -- our own SetAlpha re-enters the hook
    pcall(region.SetAlpha, region, 0)
    s.busy = false
end

-- Alpha 0, kept there when Blizzard shows the region or sets its alpha again.
-- The alpha Blizzard asks for while faded is remembered, so Unfade gives back
-- the latest one: Edit Mode's Opacity sets the NineSlice's alpha whenever the
-- player moves the slider (GlassMiniMap's helper kept only the first).
function API.Fade(region)
    if type(region) ~= "table" or not region.SetAlpha then return false end
    if faded[region] then refade(region); return true end
    faded[region] = { alpha = API.Plain(region:GetAlpha()) }
    if not fadeHooked[region] then
        fadeHooked[region] = true
        for _, m in ipairs({ "Show", "SetShown", "SetAlpha" }) do
            if type(region[m]) == "function" then
                hooksecurefunc(region, m, function(self, alpha)
                    local s = faded[self]
                    if not s or s.busy then return end
                    if m == "SetAlpha" and type(API.Plain(alpha)) == "number" then s.alpha = alpha end
                    refade(self)
                end)
            end
        end
    end
    refade(region)
    return true
end

function API.Unfade(region)
    local s = faded[region]
    if not s then return end
    faded[region] = nil
    pcall(region.SetAlpha, region, s.alpha or 1)
end

function API.IsFaded(region) return faded[region] ~= nil end

-- A texture whose alpha Blizzard animates (an AnimationGroup with
-- setToFinalAlpha writes alpha without calling SetAlpha, so Fade can't hold
-- it): drop its image instead, and give the atlas or file back on Unblank.
local blanked = setmetatable({}, { __mode = "k" })  -- texture -> { atlas = } | { file = }

function API.Blank(tex)
    if type(tex) ~= "table" or not tex.SetTexture or blanked[tex] then return false end
    local atlas = tex.GetAtlas and API.Plain(tex:GetAtlas())
    blanked[tex] = atlas and { atlas = atlas } or { file = API.Plain(tex:GetTexture()) }
    tex:SetTexture(nil)
    return true
end

function API.Unblank(tex)
    local s = blanked[tex]
    if not s then return end
    blanked[tex] = nil
    if s.atlas then tex:SetAtlas(s.atlas) else tex:SetTexture(s.file) end
end

function API.IsBlanked(tex) return blanked[tex] ~= nil end

-- Recolour a texture (desaturated, then a vertex colour). Both survive
-- Blizzard's SetAtlas on the same texture (the minimize buttons swap atlases
-- on collapse; pass B, 70374), and re-tinting is harmless.
local tinted = setmetatable({}, { __mode = "k" })   -- texture -> { desat = , r, g, b, a }

function API.Tint(tex, r, g, b)
    if type(tex) ~= "table" or not tex.SetVertexColor then return false end
    if not tinted[tex] then
        local s = { desat = tex.IsDesaturated and API.Plain(tex:IsDesaturated()) == true }
        s.r, s.g, s.b, s.a = tex:GetVertexColor()
        tinted[tex] = s
    end
    if tex.SetDesaturated then tex:SetDesaturated(true) end
    tex:SetVertexColor(r, g, b)
    return true
end

function API.Untint(tex)
    local s = tinted[tex]
    if not s then return end
    tinted[tex] = nil
    if tex.SetDesaturated then tex:SetDesaturated(s.desat) end
    tex:SetVertexColor(API.Plain(s.r) or 1, API.Plain(s.g) or 1, API.Plain(s.b) or 1, API.Plain(s.a) or 1)
end

--------------------------------------------------------------------------------
-- Settings (Options > AddOns)
--------------------------------------------------------------------------------

-- The global, read late: Options.lua has a local of the same name.
local function settingsAPI() return rawget(_G, "Settings") end

function API.RegisterSettingsPanel(panel, name)
    local S = settingsAPI()
    if not (S and S.RegisterCanvasLayoutCategory and S.RegisterAddOnCategory) then return nil end
    local category = S.RegisterCanvasLayoutCategory(panel, name)
    S.RegisterAddOnCategory(category)
    return category
end

function API.OpenSettings(category)
    local S = settingsAPI()
    if not (category and S and S.OpenToCategory) then return false end
    return pcall(S.OpenToCategory, category:GetID()) and true or false
end
