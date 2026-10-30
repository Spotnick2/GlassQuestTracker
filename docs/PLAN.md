# Glass Quest Tracker: plan (v0.1.0 + phase-2 outline)

## Context
WoW: Forever 1.60.1 (Interface 16001, Lua 5.1) runs Retail's `ObjectiveTrackerFrame`. It's a heavy
gold-framed panel that takes a lot of room. The owner wants the LibGlass "clean" glass look on it,
lighter and more compact, staying close to stock. Later (phase 2) they want Questie-style objective
markers on the world map and minimap, which the stock UI lacks. `C:\Projects\WoW\GlassQuestTracker` is empty.

**Owner decisions (2026-10-14):**
- **Restyle the stock tracker in place.** Not "veil it and draw our own list": in-place is seen as
  less likely to break after an update; "see how it pans out". Leave room for an own-list mode later.
- **Contents:** the stock watch list, plus auto-tracking newly accepted quests (with a toggle).
- **Phase 2:** markers owned by Glass Quest Tracker, built as an embedded LibStub library inside
  the repo, so it can be extracted later and embedded by GlassMaps.
- **Phase 2 coordinates:** probe Blizzard's POI data first, then fill gaps from QuestieDB.
- **License: MIT.** Questie is GPL (confirmed on CurseForge) and QuestieDB ships no license, so
  ideas only. QuestieDB is a runtime-only optional dependency: never bundled, never copied.

**Workflow:**
- GitHub issues and PRs: issue → branch off `main` → PR with `Closes #N`. The owner merges and
  launches reviews; commit and push only when asked.
- `codex-consult` adversarial review, gpt-6-astra at high effort: **consensus in round 2**
  (2026-10-14). Round 1 had 8 SHOULDs and 1 NIT, no blockers; all were reconciled, with one point
  pushed back on (blanket mutation testing stays, per the owner's convention).
- First steps after approval:
  - save a project memory (codex-consult review + GitHub issues/PRs workflow);
  - copy GlassMail's `codex-consult` skill into `.claude/skills/`;
  - the owner creates the GitHub repo `Spotnick2/GlassQuestTracker`; I `git init` and open the
    milestone issues.

## Ground truth (wow-ui-source `forever` @70338, API dump 70374)
- **The frame.** `ObjectiveTrackerFrame` = `RightManagedFrameTemplate` + Edit Mode system 12 +
  container. Width 260, fixed in its XML. Children: `.NineSlice` and `.Header` (`Background`, `Text`,
  `MinimizeButton`). Modules are global instances (`QuestObjectiveTracker`,
  `CampaignQuestObjectiveTracker`, …), added after `PLAYER_ENTERING_WORLD` + `VARIABLES_LOADED`.
- **Measured taint (ForeverUI).** Any of these from addon code taints and later throws
  secret-aura errors:
  - `Hide`/`Show`/`SetParent`/`SetPoint` on the tracker;
  - calling its Lua (`Update`, `SetCollapsed`, `MarkDirty`);
  - opening Blizzard windows.
- **Hook point.** `hooksecurefunc(ObjectiveTrackerFrame, "Update")` misses dirty updates: they run
  a closure made at OnLoad. Mixin-table hooks miss too, since mixins are copied at creation.
  **`hooksecurefunc(<module instance>, "EndLayout")`** runs after every real layout.
  `Header.SetCollapsed` can be hooked per Header instance.
- **Content bottom for free.** Blizzard re-anchors `NineSlice` BOTTOM to the last module after every
  layout (`Blizzard_ObjectiveTrackerContainer.lua:117-127`). Our panel anchors to the NineSlice
  and never reads a position (positions can be secret here).
- **Edit Mode settings:**
  - Height and TextSize (12–20, through `ObjectiveTrackerLineFont`/`HeaderFont`): we respect both
    by not touching fonts.
  - Opacity (`NineSlice:SetAlpha`): superseded by our own setting.
- **Animations.** Module header `Background`/`Shine`/`Glow` animate with `setToFinalAlpha`, which
  beats an alpha fade, so we **blank** them (`SetTexture(nil)`, original atlas kept in a weak table).
- **Compactness ceiling.**
  - Achievable: glass that hugs the content, gold header bars removed, mouse-out fade of the glass
    and controls, Edit Mode Height/TextSize, collapse with the stock buttons (player click only).
  - **Not achievable in place:** line, block or module spacing, width, scale, or the 38 px header
    band. All of these are layout fields, and writing them taints. Real density needs the deferred
    own-list mode.
- **Auto-track.** Stock only auto-watches when the CVar `autoQuestWatch` is on
  (`Blizzard_ObjectiveTracker.lua:32-38`). ForeverUI measured that the watch list stays empty.
  `C_QuestLog.AddQuestWatch(questID) -> wasWatched` exists.

## Rule for every hook ("C methods only")
- **Allowed on Blizzard objects:** `SetAlpha`, `EnableMouse`, `SetShadowOffset`/`SetShadowColor`,
  `SetDesaturated`, `SetVertexColor`, `SetTexture(nil)`/`SetAtlas(original)`, getters, `HookScript`,
  `hooksecurefunc`.
- **Never:** mixin methods, `Show`/`Hide`/`SetShown`/`SetPoint`/`SetParent`/`SetText`/`SetFont*`/
  `SetTextColor`, `Update`/`MarkDirty`/`SetCollapsed`, `UIFrameFade*` (it writes `FADEFRAMES`), or
  field writes. Our state lives in our own weak tables. Our frames are unnamed.
- Text keeps Blizzard's colours: difficulty colouring carries information, and hover resets the
  colour anyway. We only add shadows.

## File layout (TOC order)
```
Libs\LibGlass-1.0\LibGlass-1.0.xml   (.pkgmeta external, tag r6)
Compat.lua  Glass.lua  Theme.lua  Tracker.lua  Blizzard.lua  Panel.lua  Skin.lua  AutoTrack.lua
Options.lua  GlassQuestTracker.lua
```
- **Compat.lua:** copy of `..\GlassMiniMap\Compat.lua` (`API.Fail`/`Try`, `RegisterEvents`,
  `Fade`/`Unfade`, `IsSecret`/`Plain`, `CVarBool`, `ClassColor`, Settings registration,
  `MEASURED_ON_BUILD`). Adds `API.Blank`/`Unblank` (keeps `GetAtlas`/`GetTexture`) and
  `API.Shade`/`Unshade` (keeps the old shadow).
- **Glass.lua:** `LibStub("LibGlass-1.0"):New({ preset = "clean" })`.
- **Theme.lua:** `..\GlassMiniMap\Theme.lua` almost verbatim (clear/smoked/class, `Register`,
  `Refresh`, `OnChange`, `Retry`).
- **Tracker.lua:** read-only resolvers: `Frame`, `NineSlice`, `Header`, `Modules` (from
  `ObjectiveTrackerFrame.modules`, falling back to known global names via `rawget`),
  `EachBlock(module)` (`usedBlocks`), `EachLine(block)` (`usedLines`). Anything missing is skipped
  and recorded in `/gqt failures`.
- **Blizzard.lua:**
  - `FADED`: NineSlice, `Header.Background`, minimize-button highlights.
  - `BLANKED`: module header Background, Shine and Glow.
  - Minimize-button tint (desaturate + vertex colour; it survives `SetAtlas`).
  - `Restore()`, used by the "stock" theme.
- **Panel.lua:**
  - An unnamed, mouse-off frame **parented to `ObjectiveTrackerFrame`**. It shows and hides with
    the tracker; GlassMiniMap does the same with an Edit Mode frame.
  - Level = the tracker's level, which is under the modules. Anchored TOPLEFT/BOTTOMRIGHT to the
    NineSlice with small insets.
  - `Glass.Apply(panel, "large")`, plus the opaque backing from `..\GlassMiniMap\Tracking.lua:281`,
    masked by `g.mask`, with alpha from the opacity setting.
  - **The bottom anchor is chosen by state, never inherited blindly.** NineSlice only gets a BOTTOM
    anchor when a module exists (`Container.lua:117`); at first, and while empty in Edit Mode, it
    has only top anchors (`Container.xml:71`). So:
    - populated: bottom → NineSlice;
    - collapsed (container `Header.SetCollapsed` hook; initial state from `isCollapsed`): bottom →
      Header;
    - empty, including Edit Mode: bottom → Header.

    The state is recomputed after every `EndLayout` and each collapse.
  - **Edit Mode:** `EditModeManagerFrame` OnShow/OnHide forces the panel fully visible.
  - **Mouse-out fade:** a 0.15 s poll of `IsMouseOver()` on our own frame, then our own OnUpdate
    fade of the panel and the minimize tint. Quest text stays visible.
- **Skin.lua:**
  - `hooksecurefunc(module, "EndLayout", …)` on each module, plus the Header `SetCollapsed` hooks,
    all under `API.Try`.
  - **Then one immediate full pass** over the existing regions. Blizzard's first layout can run
    before our deferred start (`Manager.lua:215`).
  - Every layout re-walks blocks, lines and right-edge frames: existing blocks gain new lines.
    "Style once" is per **region**, held in a weak set. Switching from stock back to glass clears
    the set and re-applies.
  - What gets styled:
    - module header: blank, shadow, tint;
    - block `HeaderText`: shadow;
    - item and find-group button art via `GetNormalTexture()`/`GetPushedTexture()`: faded. Icon,
      count and cooldown are kept. Find-group buttons are found through the module's
      `usedRightEdgeFrames`, not `block.ItemButton`;
    - line `Text` and `Dash`: shadow;
    - progress-bar borders: faded;
    - minimize **art** textures are tinted; the animated button's own alpha is left alone.

    POI buttons and auto-quest popups stay stock: they are Lua mixins.
- **Fade restore:** our copy of `API.Fade` records the **latest alpha Blizzard asks for** (for
  example Edit Mode Opacity changed while glass is active), ignoring our own guarded writes. The
  sibling helper only kept the first alpha (`GlassMiniMap\Compat.lua:148,178`). `Unfade` restores
  that latest value.
- **AutoTrack.lua:** our own `QUEST_ACCEPTED(questID)` handler. **Not** `SetCVar`: that would change
  an account setting that outlives the addon.
  - **Shared eligibility** (used by both paths): skip the quest if
    - the ID is secret or not a number;
    - it's a bounty or a task quest;
    - `GetQuestWatchType` is non-nil (already watched);
    - `GetNumQuestWatches() >= Constants.QuestWatchConsts.MAX_QUEST_WATCHES` (that path is probed;
      a guarded fallback if it's missing).
  - **Automatic path only:** also skip when the setting is off, or when CVar `autoQuestWatch` is on
    (Blizzard already does it). If `AddQuestWatch` returns false, retry once on the next frame,
    rechecking eligibility and capacity.
  - **`TrackAll()`** uses only the shared rules, walks the log up to the maximum, and runs only from
    the button or the command, never on its own.
- **Options.lua:** the GlassMiniMap recipe (porting guide §1495-1595):
  - radios: theme (clear/smoked/class/stock) and backing opacity (light 0.55 / medium 0.75 / solid 0.92);
  - checkboxes: mouse-out fade, auto-track;
  - a "Track every quest now" button;
  - a note that Edit Mode owns Text Size and Height.
- **GlassQuestTracker.lua:** bootstrap (`ADDON_LOADED` loads the DB; `PLAYER_LOGIN` sets up options
  and auto-track; Panel and Skin start after `PLAYER_ENTERING_WORLD`, one frame later, once the
  modules exist), `GQT.Settings`, `GlassQuestTrackerDB` (only non-defaults are saved), and `/gqt`
  (`help`, `theme`, `opacity`, `fade`, `autotrack`, `trackall`, `options`, `failures`, `version`).
- **Conflicts:** detect Questie's tracker, RXP or ForeverUI hiding the stock tracker, and print one line.

## Repo scaffolding (copy, don't invent)
- From GlassMiniMap and GlassMail:
  - `.pkgmeta` (LibGlass `tag: r6` plus the `Libs/LibGlass-1.0/*` ignores);
  - `.github/workflows/package-check.yml` (names swapped);
  - `.gitignore`, `.gitattributes`;
  - `Tools/deploy.ps1`, `Tools/LibGlassPin.ps1`;
  - `tests/run.ps1`, `harness.lua`, `fetch_external.sh`, `wow_stubs.lua`, `test_methods.lua`, `test_toc.lua`.
- `CLAUDE.md`: the UI contract above, the hook-point facts, the C-only rule.
- `README.md`, `CHANGELOG.md`, `LICENSE` (MIT), `docs/PLAN.md` (this plan), `docs/FOREVER-PROBE.md`.
- `.claude/skills/codex-consult/SKILL.md`, copied from `..\GlassMail`.

## Probe first: `Tools/TrackerProbe/` (`/gqtprobe`). Gates the skin work.
Results go in `docs/FOREVER-PROBE.md` with the build number. Every value passes an `issecretvalue`
guard. The probe checks:
- **P1.** Is Blizzard_ObjectiveTracker loaded before us? Is the tracker protected? Its strata,
  level and size, `IsInDefaultPosition`, `editModeHeight`, `isCollapsed`.
- **P2.** Module names and blocks/lines/`ItemButton`/`poiButton`. Which values are secret:
  text, NineSlice/block `GetTop`/`GetBottom`, `IsShown`.
- **P3.** NineSlice extent while collapsed and while empty in Edit Mode. Is `IsMouseOver()` secret?
- **P4.** CVars `autoQuestWatch` and `questPOI`; `MAX_QUEST_WATCHES`; `GetNumQuestWatches`.
- **P5.** The `QUEST_ACCEPTED` payload; whether `GetQuestWatchType`/`AddQuestWatch` work right away or one frame later.
- **P6. Taint pass A: hooks and the child panel.** Count-only `EndLayout`/`SetCollapsed`/Edit Mode
  hooks, plus a plain child frame of the tracker anchored and re-anchored the way Panel.lua does it. Then
  `/console taintLog 1` and a routine: accept, progress and turn in a quest; collapse and expand;
  Edit Mode move/TextSize/Opacity/Height; combat; a dungeon. Check `Logs\taint.log` and errors.
- **P7. Taint pass B.** Pass A plus fade, blank, shadows and tint; repeat the routine; watch the
  header animation for a flash.
- **P8.** Fonts.
- **P9.** Other tracker addons loaded.

(The phase-2 data probe, for Blizzard POIs and QuestieDB, moves to the phase-2 design epic.)

**Gate:** if P6/P7 show taint, stop. Re-plan from the measured failure with the owner. There is no
pre-built fallback: an event-driven restyle wouldn't cover every module's dirty triggers anyway
(`Blizzard_AchievementObjectiveTracker.lua:39`).

## Tests (offline, Lua 5.1)
- **Stubs:** a fake tracker (container, Header, NineSlice, Quest/Campaign modules whose `EndLayout`
  hands out pooled blocks and lines), plus the C_QuestLog watch APIs, CVars and `EditModeManagerFrame`.
  **No field writes on Blizzard stubs:** a `__newindex` trap catches new keys, and a snapshot of
  existing fields is compared before and after the addon runs (`__newindex` alone misses existing
  keys such as `isCollapsed`). Every method call is recorded.
- **Test files:**
  - `test_toc`, `test_boot` (globals: `GlassQuestTracker`, `SLASH_*` only), `test_db`, `test_methods`
    (calls exist in dump 70374).
  - **`test_contract`:** every call on a Blizzard object is on the C-only allowlist, and no fields
    are written. A regression guard, not proof of taint safety: the probe is that proof.
  - `test_skin`: initial pass, new lines on an existing block, pool reuse, stock → glass re-apply,
    "stock" restores the latest Blizzard alpha.
  - `test_panel`: bottom anchor per state (populated, collapsed, empty/Edit Mode), Edit Mode
    visible, fade state machine with a fake clock, theme/opacity repaint.
  - `test_autotrack`: shared vs automatic-only rules, the retry recheck, `TrackAll` ignoring the
    setting and the CVar, the limit.
- Mutation-test every new test (the owner's sibling convention; Codex suggested targeted negatives
  only, kept as is).

## Milestones (GitHub issues, `Spotnick2/GlassQuestTracker`; the owner creates the repo)
1. Scaffold: repo, TOC, `.pkgmeta`, CI, docs, harness, deploy.
2. TrackerProbe + `FOREVER-PROBE.md`. The owner runs it in game; this gates 3–5.
3. The glass look: Glass, Theme, Tracker, Blizzard, Panel, Skin, the "stock" restore, `test_contract`.
4. Auto-track + Track all.
5. Mouse-out fade, options page, `/gqt`.
6. In-game checklist + full-addon taint pass → v0.1.0 (CurseForge per `..\References\Docs\RELEASING.md`).
7. Phase-2 design epic: a probe of Blizzard POIs, QuestieDB and player-position secrecy, then
   `docs/PLAN-markers.md` with its own review. No code yet.

## Phase 2 outline (design later, not built in v0.1.0)
- **The library:** `LibQuestMarkers-1.0`, in-repo at `LibQuestMarkers-1.0\` at the repo root (its
  own XML, listed in the TOC, not an external until extracted). Not under `Libs\`, which is
  gitignored for the LibGlass external. It follows the LibGlass/EMBEDDED-LIBRARIES rules
  from day one: dispatch through `lib.impl` at call time, tables reused in place, `lib.ready = MINOR`
  last, the API only grows. It doesn't depend on LibGlass; consumers pass the style in.
- **API sketch:**
  - `GetPoints(questID[, uiMapID])` returns `{uiMapID, x, y, kind, objectiveIndex, label, source}` copies.
  - A `POINTS_CHANGED` callback.
  - `NewWorldMapLayer(owner, opts)` / `NewMinimapLayer(owner, opts)` with `SetEnabled`, `SetStyle`, `Refresh`.
  - Callbacks run under pcall; no live tables are handed out.
- **Data:**
  1. Blizzard first (`GetQuestsOnMap`, `GetNextWaypoint(ForMap)`).
  2. QuestieDB (optional): `RequireContract(4)`, quest objectives → NPC/object spawns, keyed by
     AreaTable id. The area→uiMapID map is published as
     `Support.Get("ZoneDB").private.areaIdToUiMapId` (`QuestieDB\src\support\data.lua:21,80`).
     Guard its availability and verify it against the contract in the phase-2 design.
- **Display risks:** `WorldMapFrame:AddDataProvider` from addon code on a secret-value client, and
  the gamepad map-cursor taint (Questie hides pins from it via `GetCenter`). Both get measured like
  P6. Minimap pins need positions that may be secret.

## Risks (stated up front)
1. **Hook or child-panel taint.** P6/P7 decide; if they fail, re-plan with the owner.
2. **Compactness ceiling.** In place gives a lighter look but stock density. Density means the own-list mode later.
3. **Blizzard internals change between builds** (parentKeys, `usedBlocks`). Resolvers skip what's
   missing, `/gqt failures` reports it, and the measured build is pinned.
4. **Legibility over terrain.** The backing plus shadows; judge it while moving.
5. **Other trackers fighting us.** Detect and print.

## Verification
- `pwsh tests\run.ps1`: `luac -p` plus every test, green and mutation-tested.
- `pwsh Tools\deploy.ps1 -Probe`, then in game run `/console scriptErrors 1`, `/console taintLog 1`
  and `/reload`.
- Run the P6 routine on the full addon; `Logs\taint.log` must show nothing from GlassQuestTracker,
  and there must be no secret-aura errors.
- Visual check across themes, collapse, Edit Mode, mouse-out fade, auto-track on accept and
  `/gqt trackall`; compare with `/gqt theme stock`.
- CI: the packager dry run and the zip allowlist.
