# Forever probe: Glass Quest Tracker

What has to be measured on the live client before the skin is built (#2), and what was found.
Record the build each result was measured on.

TrackerProbe is a ForeverProbe module (`References\Docs\PROBES.md`, #13): `/fp gqt <command>`. Deploy
with `pwsh Tools\deploy.ps1 -Probe`, which deploys the host (`..\ForeverProbe`) first, then
`/reload`. Its lines go to the ForeverProbe console (`/fp`), never to chat, and are saved: after a
`/reload` or logout they're in `WTF\Account\<account>\SavedVariables\TrackerProbe.lua`
(`TrackerProbeDB.log`). Until #13 the probe was `/gqtprobe`, printing to chat; the results below
were measured with it.

## Probe questions (`/fp gqt`)

| # | Question | Command | Result |
|---|---|---|---|
| P1 | Is Blizzard_ObjectiveTracker loaded before us? Is `ObjectiveTrackerFrame` protected? Strata, level, size, `IsInDefaultPosition`, `editModeHeight`, `isCollapsed` | `frames` | **1.60.1.70374:** loaded before us; not protected; LOW / level 1; 260×800; scale 1; not in default position; `editModeHeight` 800 |
| P2 | Module names; blocks, lines, `ItemButton`, right-edge frames. Which values are secret: text, NineSlice/block `GetTop`/`GetBottom`, `IsShown` | `frames` (with a few quests tracked) | **70374:** 11 modules from `ObjectiveTrackerFrame.modules`; blocks/lines via `usedBlocks`/`usedLines`; text, `GetTop`/`GetBottom`, `IsShown`, `GetPoint` all plain (not secret) |
| P3 | NineSlice extent while collapsed and while empty in Edit Mode. Is `IsMouseOver()` secret? | `nine` (toggles a red overlay; look at it collapsed, empty, in Edit Mode) | **70374:** NineSlice keeps its full extent when collapsed (overlay stayed big); BOTTOM → last module only while populated; `IsMouseOver` plain |
| P4 | CVars `autoQuestWatch` and `questPOI`; `Constants.QuestWatchConsts.MAX_QUEST_WATCHES`; `GetNumQuestWatches` | `cvars` | **70374:** `autoQuestWatch` = 1 (default 1); `questPOI` = 1; `MAX_QUEST_WATCHES` = 25 |
| P5 | `QUEST_ACCEPTED` payload; `GetQuestWatchType` / `AddQuestWatch` right away vs one frame later | `accept on`, accept a quest; then `accept watch`, accept another | **70374:** one arg, `questID` (number); with `autoQuestWatch` on, already watched (type 1) at the event. `accept watch` not run |
| P6 | **Taint pass A:** count-only `EndLayout` / `Header.SetCollapsed` / Edit Mode hooks, plus a plain child panel of the tracker (faint blue) anchored and re-anchored like Panel.lua | `hook`, then the routine, then `counts` | **70374: clean** (no errors, no blocked actions; hooks and panel fire) |
| P7 | **Taint pass B:** pass A + fade, blank, shadows, minimize tint; does the module header animation flash? | `restyle`, `/reload`, the routine, `counts` | **70374: clean** (23-min full routine; 10-min re-run with `taintLog 1`: nothing from the probe or the tracker). Header flash: open |
| P8 | Fonts: `ObjectiveTrackerLineFont:GetFont()`, shadow as built | `frames` | **70374:** `FRIZQT__.TTF` 12 (line) / 14 (header), shadow 1,-1 black |
| P9 | Other tracker addons loaded (Questie, RXP, ForeverUI) | `frames` | **70374:** RXPGuides, Leatrix_Plus (Questie and ForeverUI not installed) |

`hook` and `restyle` are remembered across `/reload` (so the pass is in place from login); `off`
clears it for the next `/reload`. Both **refuse while Glass Quest Tracker is loaded**: two skins
on one tracker measure nothing. Disable the addon to run a pass; a refused pass isn't remembered.

**The P6/P7 routine:** `/reload`, **then** `/console taintLog 1` (on 70374 the CVar is back to 0
after a `/reload`, and the probe prints its value on entering the world), then accept, progress and turn in a quest;
collapse and expand by clicking; open Edit Mode, move the tracker, change Text Size, Opacity and
Height; fight; enter a dungeon. Then read `Logs\taint.log` and the error frame (especially
"Auras cannot be accessed when secret"). **If P6 or P7 shows taint, stop and re-plan.**
`/fp gqt routine` lists which steps the session has covered; it's also logged at logout.
A step counts only after the pass is installed, and collapse only once both the tracker and a
section have been collapsed **and** expanded.

On 70374, with `taintLog` 1 or 2, hovering any player throws a Blizzard error
(`TooltipDataHandler.lua:300`, "attempt to call a nil value"; none at 0). It's the logging,
not the addon under test: ignore that stack.

## The glass look's checks: `/fp steps gqt look` (#3)

A guided procedure: one step at a time in ForeverProbe's panel, each outcome, note and screenshot
saved. With the addon enabled, `/reload`, then `/fp steps gqt look`. It:
- switches each theme and opacity through `/gqt`, and checks the addon's state after each one
  (glass shown or hidden, wash hidden, NineSlice and header bar faded or back);
- asks you to collapse and expand the tracker and a section and to use Edit Mode, then checks where
  the glass went;
- asks what only you can see (Blizzard's own look under `stock`, the "−" button on the glass, a gold
  flash, legibility over bright ground), with a screenshot for each visual step;
- checks that `/gqt failures` is empty, and puts your theme and opacity back.

The manual steps check that you did them: a section newly collapsed then expanded, and Edit Mode
opened and closed since a snapshot taken just before; Next alone fails. A `/reload` loses that
snapshot: those steps then fail and say so; go Back to the "Noting" step, press Run, and redo them. Your theme and opacity are
kept in `TrackerProbeDB.look` until they're put back, so a run stopped or restarted part-way
doesn't lose them. `/fp gqt restore` puts them back by hand.

`/fp steps gqt collapse` is the same hand steps alone (collapsing, a section, Edit Mode), to redo
them without the themes. `/fp gqt state` prints the same state at any time. After the closing `/reload`, the results are in
`ForeverProbe.lua` (`steps.records["TrackerProbe/look"]`), and the screenshot file names are on
each step (`..\ForeverProbe\Tools\screenshots.ps1 -Module TrackerProbe` lists them).

## In-game checklist (v0.1.0, #6)

- [ ] Each theme (clear, smoked, class) and `stock`; `/gqt theme <name>` repaints live.
- [ ] The glass hugs the quests; collapsed shows the header only; empty in Edit Mode is sane.
- [ ] Edit Mode: move, Height, Text Size; the glass follows.
- [ ] Mouse-out fade; text stays readable while moving over bright terrain.
- [ ] Auto-track on accept; `/gqt trackall`; the watch limit.
- [ ] **Full taint pass** (the P6 routine with the whole addon): nothing from GlassQuestTracker in
      `taint.log`, `/gqt failures` empty.

## Measured

**1.60.1.70374, 2026-10-14.** Account with RXPGuides, Leatrix_Plus, Attune, Apotheca, AtlasLoot,
Decursive, DBM loaded.

- **The gate passes: no taint from hooking and restyling in place.**
  - Pass A: hooks and the child panel; Edit Mode and a section collapse. No errors.
  - Pass B, 23 minutes: the whole routine (13 quests accepted, progress, turn-in, tracker and
    section collapse, Edit Mode move/Height/Text Size/Opacity, combat, a dungeon). No Lua errors,
    no `ADDON_ACTION_BLOCKED`/`FORBIDDEN`. `taintLog` was 0 for this run.
  - Pass B, 10 minutes with `taintLog` 1 (and 2 for part of it): Edit Mode, combat, a dungeon in
    and out. `taint.log` has 3279 lines, from Attune, Apotheca, AtlasLoot, Decursive and DBM;
    **none** mention TrackerProbe or `ObjectiveTracker`.
  - Hook counts over the 23-minute run: `EndLayout` 86–126 per populated module, 12–13 for
    Scenario/UIWidget; the panel re-placed 891 times; Blizzard reset faded textures 368 times and
    the `Show`/`SetAlpha` hooks re-faded them each time.
- **The panel's bottom anchor by state works:** collapsed, the stand-in panel hugs the header
  while the NineSlice keeps its full size. NineSlice points while populated: TOPLEFT (-30,0) and
  TOPRIGHT (5,0) to the tracker, BOTTOM to the last module (0,-10), BOTTOMRIGHT to the tracker.
- **The stock background is invisible on this setup:** NineSlice alpha 0 (Edit Mode Opacity).
  The glass is the only backing.
- **Auto-track is mostly Blizzard's here:** `autoQuestWatch` is on by default, and every accepted
  quest was watched by the time `QUEST_ACCEPTED` reached us. ForeverUI's "watch list stays empty"
  didn't reproduce. Our toggle only matters with that CVar off; `AddQuestWatch` from addon code
  is still unmeasured.
- **Blizzard bugs seen (not ours):** `PetActionBar.lua:123` calls `HasPetActionHighlightMark`,
  which this client lacks; the tooltip error above with `taintLog` on.

**1.60.1.70374, 2026-10-15** (the glass look, #3, read with `/run`):
- **A gradient texture ignores `SetAlpha`.** LibGlass's wash read `true 1` after Theme had set it
  to 0, and its white gradient greyed the panel's upper half. Painting it through the gradient and
  hiding it at zero fixed it (`false 1`). The same as GlassActionBars measured on 10-13; LibGlass's
  probe then showed that order and texture kind don't matter (porting guide §3, "A gradient texture
  ignores SetAlpha"). `tests/wow_stubs.lua` models it.

**1.60.1.70450, 2026-10-17** (`/fp steps gqt look`, the charcoal look before the reflective shell;
screenshots `WoWScrnShot_101726_0113*`–`0115*`):
- **Passed, checks and screenshots agreeing:** clear, smoked, class and stock (stock showed
  Blizzard's gold bars and red minimize button: "looks like Blizzard's own", yes); opacity light,
  solid and medium; the section "−" fully on the glass; Edit Mode move and Height, with the glass
  following; readable over bright ground; `/gqt failures` empty; the owner's look put back.
- **Not exercised:** collapsing the tracker and a section. Next came 1–2 s after each step
  appeared, and the screenshots show both still expanded, so the checks failed as designed.
  `/fp steps gqt collapse` redoes them.
- **Gold flash on a section title:** "unsure".
