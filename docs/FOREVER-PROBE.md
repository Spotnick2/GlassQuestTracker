# Forever probe: Glass Quest Tracker

What has to be measured on the live client before the skin is built (#2), and what was found.
Deploy with `pwsh Tools\deploy.ps1 -Probe`, restart the client, then run `/gqtprobe` and the
routine below. Record the build each result was measured on.

## Probe questions (`/gqtprobe`)

Every line the probe prints is also saved: after a `/reload` or logout it's in
`WTF\Account\<account>\SavedVariables\TrackerProbe.lua` (`TrackerProbeDB.log`).

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
clears it for the next `/reload`.

**The P6/P7 routine:** `/reload`, **then** `/console taintLog 1` (on 70374 the CVar is back to 0
after a `/reload`, and the probe prints its value on entering the world), then accept, progress and turn in a quest;
collapse and expand by clicking; open Edit Mode, move the tracker, change Text Size, Opacity and
Height; fight; enter a dungeon. Then read `Logs\taint.log` and the error frame (especially
"Auras cannot be accessed when secret"). **If P6 or P7 shows taint, stop and re-plan.**
`/gqtprobe routine` lists which steps the session has covered; it's also logged at logout.
A step counts only after the pass is installed, and collapse only once both the tracker and a
section have been collapsed **and** expanded.

On 70374, with `taintLog` 1 or 2, hovering any player throws a Blizzard error
(`TooltipDataHandler.lua:300`, "attempt to call a nil value"; none at 0). It's the logging,
not the addon under test: ignore that stack.

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
