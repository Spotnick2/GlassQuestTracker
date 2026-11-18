-- harness.lua: the addon loader and the tests' own helpers. dofile it after
-- wow_stubs.lua. check, eq and done are WowTestKit's (global).

function near(actual, expected, msg)
    check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
        string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
end

-- Every file line of the TOC, in load order, as written.
function tocLines() return Kit.tocLines("GlassQuestTracker.toc") end

-- Lua files listed in the TOC, in load order.
function tocFiles() return Kit.tocFiles("GlassQuestTracker.toc") end

-- FINDING (GlassQuestTracker#17): /gqt's help prints two lines with a bare
-- "|" ("theme clear|smoked|class|stock", "opacity light|medium|solid"), which
-- the client reads as escapes. done() fails on any stray "|"; a test that
-- prints the help lets exactly those two lines through until they're fixed,
-- so any other stray still fails. Returns how many it let through.
local KNOWN_STRAYS = { "/gqt theme clear|smoked|class|stock - the glass, or Blizzard's own tracker",
                       "/gqt opacity light|medium|solid - the backing under the glass" }
function acceptKnownStrays()
    local keep, known = {}, 0
    for _, line in ipairs(WoW.strays) do
        local hit = false
        for _, k in ipairs(KNOWN_STRAYS) do
            if line:find(k, 1, true) then hit = true end
        end
        if hit then known = known + 1 else keep[#keep + 1] = line end
    end
    WoW.strays = keep
    return known
end

-- The embedded LibGlass-1.0 comes from a checkout, not from Libs\ (gitignored,
-- filled by the packager): $LIBGLASS, else ../LibGlass. No checkout fails the
-- run loudly; a silently skipped library would test nothing.
LIBGLASS_XML = "Libs\\LibGlass-1.0\\LibGlass-1.0.xml"
function libGlassRoot()
    local root = (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/"):gsub("/$", "")
    local f = io.open(root .. "/LibGlass-1.0.xml", "rb")
    if not f then
        error("LibGlass checkout not found at " .. root .. " (no LibGlass-1.0.xml): clone "
              .. "github.com/Spotnick2/LibGlass there or set LIBGLASS", 0)
    end
    f:close()
    return root
end

-- The Lua files the library's XML loads, as paths, in order.
function libGlassScripts()
    local root = libGlassRoot()
    local f = assert(io.open(root .. "/LibGlass-1.0.xml", "rb"))
    local xml = f:read("*a"):gsub("<!%-%-.-%-%->", "")   -- listed in a comment is not loaded
    f:close()
    local files = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do
        local path = root .. "/" .. file:gsub("\\", "/")
        local src = io.open(path, "rb")
        if not src then error("LibGlass checkout at " .. root .. " is missing " .. file, 0) end
        src:close()
        files[#files + 1] = path
    end
    if #files == 0 then error("LibGlass-1.0.xml at " .. root .. " lists no Script files", 0) end
    return files
end

-- Load the addon the way the client does, in a fresh session: every TOC line
-- with (name, ns), the library's XML expanded in place, then ADDON_LOADED,
-- PLAYER_LOGIN and PLAYER_ENTERING_WORLD.
-- opts.db: saved variables. opts.before(): runs after the files load and
-- before ADDON_LOADED.
function loadAddon(opts)
    opts = opts or {}
    GlassQuestTracker, GlassQuestTrackerDB, LibStub = nil, nil, nil
    WoW.reset()
    local ns = {}
    for _, line in ipairs(tocLines()) do
        local files
        if line == LIBGLASS_XML then
            files = libGlassScripts()
        elseif line:match("%.lua$") then
            files = { (line:gsub("\\", "/")) }
        else
            error("the harness can't load TOC line " .. line, 0)
        end
        for _, file in ipairs(files) do
            local chunk = assert(loadfile(file))
            chunk("GlassQuestTracker", ns)
        end
    end
    if opts.db then GlassQuestTrackerDB = opts.db end
    if opts.before then opts.before() end
    WoW.fire("ADDON_LOADED", "GlassQuestTracker")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.flushTimers(0)
    return GlassQuestTracker
end

-- ForeverProbe, the host TrackerProbe is a module of: $FOREVERPROBE, else
-- ..\ForeverProbe; nil without a checkout (CI without the host's token).
function foreverProbeRoot()
    local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
    local toc = io.open(root .. "/ForeverProbe.toc", "rb")
    if not toc then return nil end
    toc:close()
    return root
end

local function tocScripts(path)
    local f = assert(io.open(path, "rb"))
    local list = {}
    for line in f:read("*a"):gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line:match("%.lua$") and not line:match("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
    end
    f:close()
    return list
end

-- The host, as the client loads it (GlassChat's loadForeverProbe): every TOC
-- file with ("ForeverProbe", {}), then its ADDON_LOADED.
function loadForeverProbe(root)
    for _, file in ipairs(tocScripts(root .. "/ForeverProbe.toc")) do
        assert(loadfile(root .. "/" .. file))("ForeverProbe", {})
    end
    WoW.fire("ADDON_LOADED", "ForeverProbe")
    return ForeverProbe
end

-- TrackerProbe, after the host: its TOC's files with ("TrackerProbe", ns),
-- then its ADDON_LOADED. Returns the namespace (ns._test is the seam).
function loadProbe()
    local dir = "Tools/TrackerProbe/"
    local ns = {}
    for _, file in ipairs(tocScripts(dir .. "TrackerProbe.toc")) do
        assert(loadfile(dir .. file))("TrackerProbe", ns)
    end
    WoW.fire("ADDON_LOADED", "TrackerProbe")
    return ns
end
