# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Glass Quest Tracker is a **liquid-glass quest tracker for World of Warcraft: Forever 1.60.1**
(Interface `16001`), written in **Lua 5.1**. It has a single owner (Spotnick) and uses the same
stack and conventions as the sibling Forever addons: `..\GlassMiniMap` (the closest template:
Compat, Theme, Blizzard fades, tests, tools), `..\GlassMail` (tooling, CI) and `..\LibGlass` (the
material, embedded). When this file doesn't cover something, check how those handle it before you
invent a new idiom.

**The plan** is [docs/PLAN.md](docs/PLAN.md) (Codex `gpt-6-astra`, consensus in round 2,
2026-10-14). Measured client facts go in [docs/FOREVER-PROBE.md](docs/FOREVER-PROBE.md).

**Owner decisions (2026-10-14):**
- **Restyle Blizzard's `ObjectiveTrackerFrame` in place.** No veil and own list (that mode is
  deferred until the in-place density proves too low).
- The stock watch list, plus auto-tracking accepted quests.
- Phase 2: Questie-style map and minimap markers in an in-repo embedded library,
  `LibQuestMarkers-1.0`, at the repo root (not `Libs\`, which is gitignored).
- **MIT.** Questie is GPL: ideas only, never its code or icons. QuestieDB is only ever an optional,
  separately installed dependency.

**Status:** parked (2026-10-30) after milestone 3, the glass look (#3, merged), until a new idea
earns it a next step. The probe passed the taint gate on 70374 (#2). Next per the plan: milestone 4,
auto-track.

## The UI contract (non-negotiable)

**Reskin Blizzard's tracker; never replace, move or drive it.** `ObjectiveTrackerFrame` is an Edit
Mode system (12) and a `RightManagedFrameTemplate`. ForeverUI measured that `Hide`/`Show`/
`SetParent`/`SetPoint` on it, or calling its Lua (`Update`, `SetCollapsed`, `MarkDirty`), taints and
later throws "Auras cannot be accessed when secret". Opening Blizzard windows from addon code
(`QuestMapFrame_OpenToQuestDetails`, `ToggleQuestLog`) taints the window manager.

**C methods only on Blizzard objects:**
- **Allowed:** `SetAlpha`, `EnableMouse`, `SetShadowOffset`/`SetShadowColor`, `SetDesaturated`,
  `SetVertexColor`, `SetTexture(nil)`/`SetAtlas(original)`, getters, `HookScript`, `hooksecurefunc`.
- **Never:** mixin methods, `Show`/`Hide`/`SetShown`/`SetPoint`/`SetParent`/`SetText`/`SetFont*`/
  `SetTextColor`, `Update`/`MarkDirty`/`SetCollapsed`, `UIFrameFade*` (it writes `FADEFRAMES`),
  or any field write on their tables. Never reassign a Blizzard global or method.
- Our state lives in our own weak tables. Our frames are unnamed.
- Text keeps Blizzard's colours and fonts: Edit Mode's Text Size works through the font objects,
  and difficulty colours carry information. We add shadows only.

## Tracker facts for this client

From `..\wow-ui-source` (branch `forever`, 70338) and the 70374 API dump:
- Forever runs the **Mainline** `Blizzard_ObjectiveTracker` (manager → container → modules →
  blocks → lines). Classic's `QuestWatchFrame` isn't loaded. The only Camelot override disables
  timer bars and changes tag text.
- **Hook point:** `hooksecurefunc(<module instance>, "EndLayout")`. `ObjectiveTrackerFrame.Update`
  hooks miss dirty updates (a closure made at OnLoad, `Container.lua:23`). Mixin-table hooks miss
  everything, because mixins are copied at creation.
- `NineSlice` BOTTOM follows the last module (`Container.lua:117-127`) only while a module exists;
  otherwise it has top anchors only (`Container.xml:71`).
- Module header `Background`/`Shine`/`Glow` animate with `setToFinalAlpha`: blank them, don't fade them.
- Auto-watch is gated by the CVar `autoQuestWatch` (`Blizzard_ObjectiveTracker.lua:32-38`).
  ForeverUI measured that the watch list stays empty. We never `SetCVar`.
- Width (260), spacing and the header band are layout fields: out of reach in place.

## Layout

| File | What |
|---|---|
| `Compat.lua` | `API.*`: failures, events, version, `CVarBool`, `ClassColor`, Settings registration; `Fade`/`Blank`/`Tint` and their `Un-` restores |
| `Glass.lua` | our LibGlass instance (`preset = "clean"`) |
| `Theme.lua` | clear / smoked / class / stock, the backing opacity, `Refresh` |
| `Tracker.lua` | read-only resolvers: the frame, NineSlice, Header, modules, pooled extras |
| `Blizzard.lua` | what is faded, blanked and tinted, and `Restore` (the stock theme) |
| `Panel.lua` | the glass, a child of the tracker; bottom anchor by state |
| `Skin.lua` | the `EndLayout` / `SetCollapsed` / Edit Mode hooks, the first pass, `Apply` |
| `GlassQuestTracker.lua` | bootstrap, `GlassQuestTrackerDB`, `/gqt` |

Planned, per docs/PLAN.md: `AutoTrack`, `Options`. `Tools\TrackerProbe\` is the measuring addon (never shipped): a ForeverProbe module, `/fp gqt`, with
`/fp steps gqt look` as the glass look's in-game check.

## References

- `..\References\Docs\PORTING-TBC-TO-FOREVER.md`: Edit Mode systems, secure buttons, secret values,
  options-page recipe, packaging.
- `..\References\Forever\api\`, the newest `forever-api-<version>.<build>.md` there: does an API exist?
  Presence is not a contract. The tests check method and event names against 70450's
  (`tests/wow_stubs.lua`).
- `..\References\Docs\LIBGLASS-WINDOW-STYLING.md`: the suite's reflective window look, which the
  panel follows (LibGlass r9's `Glass.Reflect`).
- `..\References\Docs\RELEASING.md`, `..\References\Docs\LIBGLASS-MIGRATION.md`, `..\References\Docs\EMBEDDED-LIBRARIES.md`.
- `..\References\Addons\UISuites\ForeverUI\ForeverUI\Modules\Quests\`: what another addon measured on the tracker.
- `..\References\Addons\QuestsLeveling\Questie`: tracker UX and map markers. GPL: ideas only.
- `..\LibGlass\docs\GLASS-MATERIAL.md`: the material and its region fields.

## Toolchain and commands

Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\` (`lua.exe`, `luac.exe`). No build step.

```powershell
pwsh tests\run.ps1                                                   # luac -p on the TOC files (+ probe), then every tests\test_*.lua (needs ..\LibGlass or $env:LIBGLASS)
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_boot.lua      # one test, from the repo root
pwsh Tools\deploy.ps1 -Probe                                         # copy the addon (+ ForeverProbe and TrackerProbe) into AddOns
```

- Default AddOns path: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`.
- In game: `/console scriptErrors 1`, `/reload`, **then** `/console taintLog 1` (a `/reload` puts it
  back to 0 on 70374). `/reload` also loads a new addon folder (ForeverProbe guide, section 7).
- The probe: `/fp gqt` lists its commands; `/fp steps gqt look` walks #3's checks. Read
  `SavedVariables\TrackerProbe.lua` and `ForeverProbe.lua` (`steps.records`) after the owner's
  `/reload`, and the screenshots with `..\ForeverProbe\Tools\screenshots.ps1 -Module TrackerProbe`.
- **Shell heredocs here collapse `\\` to `\`**: write files that contain Lua backslash escapes or
  Windows paths with the Write/Edit tools.

## Testing

Glass MiniMap's harness: `tests\wow_stubs.lua` (strict globals as an allowlist of APIs verified in
the dump, event names validated against the dump, every widget method recorded),
`tests\harness.lua` (`check`, `eq`, `near`, `loadAddon`), `test_methods.lua` (every method called
exists on this client). **Mutation-test every new test.** Offline tests can't cover taint,
rendering or the live client's data: that's the probe and the in-game checklist.

## Workflow and releasing

- Issue → branch off `main` → PR with `Closes #N`. Never commit to `main`; commit or push only
  when asked. `luac -p` clean and tests green before committing.
- **The owner merges and closes PRs and launches reviews.**
- **Plans** get an adversarial review before coding: Codex via the `codex-consult` skill,
  `-m gpt-6-astra` at high effort, looping until consensus, without overengineering.
- Releases: `..\References\Docs\RELEASING.md`. The CurseForge project is created by the owner before
  v0.1.0.

## Conventions

- Comments explain why, in the siblings' plain style. Name the measured build when a fact was
  measured.
- `GQT.failures` is the one failure record (`API.Fail`, `API.Try`); `/gqt failures` reads it.
- `GlassQuestTrackerDB` saves only what differs from `DEFAULTS`.

## Consulting Codex

The shared `codex-consult` skill (user level) has the invocation and the gotchas. For this repo:

For Glass Quest Tracker, good things to hand Codex:
- anything that hooks, fades, blanks or reads Blizzard's `ObjectiveTrackerFrame` (an Edit Mode
  system and a right-managed frame): the "C methods only" rule in `CLAUDE.md`, and whether a
  change could run Blizzard's tracker Lua from our code (measured to taint on this client);
- anything that adds or removes quest watches (`AutoTrack.lua`);
- anything that writes to SavedVariables;
- any plan that grows scope toward a full replacement tracker (the own-list mode is deferred by
  the owner) or toward Questie (GPL: ideas only, never its code or icons);
- the phase-2 marker library (`LibQuestMarkers-1.0`): its upgrade rules are LibGlass's.

**Always hand it `CLAUDE.md` and `docs/PLAN.md` alongside the diff or plan**, plus
`C:/Projects/WoW/References/Docs/PORTING-TBC-TO-FOREVER.md` and `docs/FOREVER-PROBE.md`. Those findings
were measured on the live client. Without them, a cold reviewer argues from Classic-era or Retail
behaviour that doesn't hold here (that the Classic `QuestWatchFrame` exists, that calling the
tracker's own methods is harmless).
`C:/Projects/WoW/References/Forever/api/` (its newest `forever-api-*.md`) is the full API surface when a question
turns on whether something exists, and `C:/Projects/WoW/wow-ui-source` (branch `forever`) is the
client's own FrameXML (`Blizzard_ObjectiveTracker`). The design references are
`C:/Projects/WoW/References/Addons/QuestsLeveling/Questie` (GPL) and `C:/Projects/WoW/References/Addons/UISuites/ForeverUI` (its
`Modules/Quests` measured the tracker's taint); behaviour references only, their code is never copied.
