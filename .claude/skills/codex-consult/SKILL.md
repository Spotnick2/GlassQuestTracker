---
name: codex-consult
description: Consult the Codex CLI (OpenAI) non-interactively for an adversarial design review, code/plan critique, or independent second opinion. Use when the user asks to "rubber-duck with Codex", get Codex's take on a design/plan, or run Codex headlessly to double-check work.
version: 1.0.0
allowed-tools: [Bash, Write, Read]
---

# Consult Codex CLI (headless)

Run OpenAI's `codex` CLI non-interactively to get a second opinion (design review, plan
critique, adversarial check) from a *different model family* than Claude — the point is
decorrelated blind spots, not raw capability.

> Requires the `codex` CLI installed and OpenAI-authenticated on this machine. If `codex`
> isn't found, say so and fall back to Fable for the adversarial pass (see `CLAUDE.md`).

## The invocation

1. **Write the prompt to a file** (use the scratchpad dir, not a bash heredoc — more reliable):
   `…/scratchpad/codex-prompt.txt`
2. **Run**, feeding the prompt via stdin redirect and capturing the answer with `-o`:

```bash
timeout 300 codex exec \
  -c model_reasoning_effort=medium \
  --ephemeral \
  --skip-git-repo-check \
  -s read-only \
  -o "<scratchpad>/codex-verdict.md" \
  < "<scratchpad>/codex-prompt.txt" \
  > "<scratchpad>/codex-progress.log" 2>&1
```

3. **Read the answer** from the `-o` file (`codex-verdict.md`). `stdout` is only progress.

## Why each flag (these are the gotchas that will bite you)

- **Prompt via `< promptfile` (stdin), NOT as a bare argument.** In a piped/non-TTY
  environment, `codex exec "my prompt"` prints *"Reading additional input from stdin…"* and
  **hangs forever** waiting for EOF. Redirecting a file to stdin gives the EOF.
- **`--ephemeral`** — no session persistence. Without it, a long or looping run can balloon a
  session-log JSONL under `~/.codex/sessions/` to **hundreds of MB** and never return.
- **`-o <file>`** — the final agent message is written here. **Do not parse stdout for the
  answer** — stdout is progress noise only.
- **`-s read-only`** — advisory/design use: Codex can read but not edit the tree. Use
  `-s workspace-write` only when you actually want it to make changes.
- **`--skip-git-repo-check`** — safe to run regardless of git state.
- **`-c model_reasoning_effort=high`** — the owner's standing choice for reviews (GlassMail
  2026-10-09, restated for this addon 2026-10-14: "use /codex-consult to get an adversarial review
  with gpt-6-astra, you can loop until consensus without overengineering"). Loop
  rounds: round 1 asks for BLOCKER/SHOULD/NIT findings; later rounds ask RESOLVED / NOT RESOLVED
  per finding and end on one line, "CONSENSUS: ..." or "NO CONSENSUS: ...". Add
  `-c web_search=live` if it needs the web. Add `-m <model>` to pin a model (else default).
  **Always pin `-m gpt-6-astra`**: the default in `~/.codex/config.toml` moved to `gpt-6-sol`
  (seen 2026-10-14), and astra is the model the owner asked for. The short name `-m astra` is
  **rejected** ("not supported when using Codex with a ChatGPT account").
- **`timeout <sec>`** — always wrap it (300–420s is typical) so a stuck run can't hang forever.

## Prompt shape — pick the mode

Codex answers a numbered list of specific questions well; a wall of prose less so. Two modes,
depending on whether the evidence is in the prompt or in the repo:

- **Design-prose mode** (the design/plan is described *inline* in the prompt — nothing to inspect):
  lead with *"OPINION ONLY — do NOT read files, edit, or run commands. Answer from the description
  below."* This keeps it fast and stops Codex wandering the tree. (Still run with `-s read-only`.)
- **Code / repository review mode** (the request references a diff, file paths, or "review the
  code"): **do NOT forbid reading** — Codex must inspect the evidence. Lead with *"Review the code.
  Read these files: <paths>. Do NOT edit anything or run commands — read-only advice only."* The
  `-s read-only` sandbox already blocks edits; the prompt just scopes what to read.

Never tell Codex to both "review the code" and "do not read files" — that contradiction produces a
critique of nothing. Match the instruction to the mode.

**"Do not run commands" counts as "do not read files."** Codex reads through the shell, so that
phrasing silently disarms it: it comes back asking you to paste the files, having inspected
nothing, and a whole run is wasted. In code-review mode say the opposite — *"you are in a
read-only sandbox, read the files yourself with whatever shell commands you need; the sandbox
already prevents edits."* `-s read-only` is what enforces safety, not the prompt.

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
`C:/Projects/WoW/References/PORTING-TBC-TO-FOREVER.md` and `docs/FOREVER-PROBE.md`. Those findings
were measured on the live client. Without them, a cold reviewer argues from Classic-era or Retail
behaviour that doesn't hold here (that the Classic `QuestWatchFrame` exists, that calling the
tracker's own methods is harmless).
`C:/Projects/WoW/References/forever-api-1.60.1.70374.md` is the full API surface when a question
turns on whether something exists, and `C:/Projects/WoW/wow-ui-source` (branch `forever`) is the
client's own FrameXML (`Blizzard_ObjectiveTracker`). The design references are
`C:/Projects/WoW/References/Questie-v12.1.0+v1.0.6` (GPL) and `ForeverUI-0.4.42` (its
`Modules/Quests` measured the tracker's taint); behaviour references only, their code is never copied.

Say what you have already established and ask it not to repeat that work. A clean "no defect found"
is a useful answer - ask for it explicitly, or you invite an invented finding.

## Concurrency / safety

- The owner may run **their own Codex sessions concurrently**. Multiple sessions on one account
  can serialize/slow each other.
- **Never kill Codex processes by pattern/name** — you may terminate the owner's sessions. If you
  must kill a stuck run, kill **only the exact PID you started** (`taskkill //PID <pid> //F`), and
  prefer just letting the `timeout` wrapper end it.
