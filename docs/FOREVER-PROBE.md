# Forever probe: Glass Quest Tracker

What has to be measured on the live client before the skin is built (#2), and what was found.
Deploy with `pwsh Tools\deploy.ps1 -Probe`, restart the client, then run `/gqtprobe` and the
routine below. Record the build each result was measured on.

## Probe questions (`/gqtprobe`)

| # | Question | Result |
|---|---|---|
| P1 | Is Blizzard_ObjectiveTracker loaded before us? Is `ObjectiveTrackerFrame` protected? Strata, level, size, `IsInDefaultPosition`, `editModeHeight`, `isCollapsed` | open |
| P2 | Module names; blocks, lines, `ItemButton`, `poiButton`. Which values are secret: text, NineSlice/block `GetTop`/`GetBottom`, `IsShown` | open |
| P3 | NineSlice extent while collapsed and while empty in Edit Mode. Is `IsMouseOver()` secret? | open |
| P4 | CVars `autoQuestWatch` and `questPOI`; `Constants.QuestWatchConsts.MAX_QUEST_WATCHES`; `GetNumQuestWatches` | open |
| P5 | `QUEST_ACCEPTED` payload; `GetQuestWatchType` / `AddQuestWatch` right away vs one frame later | open |
| P6 | **Taint pass A:** count-only `EndLayout` / `Header.SetCollapsed` / Edit Mode hooks, plus a plain child panel of the tracker anchored and re-anchored like Panel.lua | open |
| P7 | **Taint pass B:** pass A + fade, blank, shadows, minimize tint; does the module header animation flash? | open |
| P8 | Fonts: `ObjectiveTrackerLineFont:GetFont()`, shadow as built | open |
| P9 | Other tracker addons loaded (Questie, RXP, ForeverUI) | open |

**The P6/P7 routine:** `/console taintLog 1`, `/reload`, then accept, progress and turn in a quest;
collapse and expand by clicking; open Edit Mode, move the tracker, change Text Size, Opacity and
Height; fight; enter a dungeon. Then read `Logs\taint.log` and the error frame (especially
"Auras cannot be accessed when secret"). **If P6 or P7 shows taint, stop and re-plan.**

## In-game checklist (v0.1.0, #6)

- [ ] Each theme (clear, smoked, class) and `stock`; `/gqt theme <name>` repaints live.
- [ ] The glass hugs the quests; collapsed shows the header only; empty in Edit Mode is sane.
- [ ] Edit Mode: move, Height, Text Size; the glass follows.
- [ ] Mouse-out fade; text stays readable while moving over bright terrain.
- [ ] Auto-track on accept; `/gqt trackall`; the watch limit.
- [ ] **Full taint pass** (the P6 routine with the whole addon): nothing from GlassQuestTracker in
      `taint.log`, `/gqt failures` empty.

## Measured

Nothing yet.
