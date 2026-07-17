---
name: autopilot
description: Set up and use the GitHub Copilot CLI "autopilot" PowerShell wrapper on Windows. Makes `copilot` auto-approve shell/tool commands by default, adds a --no-auto escape valve, timestamped execution logging, and a self-service "tool forge" (New-AutopilotTool) so autopilot can invent a missing CLI tool on the fly. Use when the user wants unattended/autonomous Copilot CLI runs, mentions autopilot mode, "auto-approve", "tool forge", New-AutopilotTool, or wants to install/update this wrapper in their PowerShell profile.
license: MIT
---

# Copilot CLI Autopilot (PowerShell)

A drop-in PowerShell wrapper that makes the **GitHub Copilot CLI** run in
autopilot mode by default and gives an autonomous run three extra powers:
an escape valve, an execution log, and an on-the-fly **tool forge**.

## When to use this skill

- The user wants Copilot CLI to run **unattended** without stopping at every
  "Do you want to run this command?" prompt.
- The user asks to **install / update** the autopilot wrapper in their profile.
- During an autopilot session, a required CLI tool is **missing** and neither a
  package manager nor a web search yields a ready one — forge a purpose-built
  tool with `New-AutopilotTool` instead of giving up.
- The user asks how autopilot relates to **model selection** or BYOK.

## What it installs

A single marker-delimited block (`# >>> copilot-autopilot-default >>>` …
`# <<< copilot-autopilot-default <<<`) is inserted into **both** PowerShell
profiles (PowerShell 7 and Windows PowerShell 5.1). It defines:

| Function | Purpose |
| --- | --- |
| `copilot` | Wraps `copilot.cmd`, injecting `--autopilot` by default. |
| `New-AutopilotTool` | Forge a new tool (ps1 / python / batch) onto PATH. |
| `Get-AutopilotTool` | List forged tools from the manifest. |
| `Remove-AutopilotTool` | Delete a forged tool + manifest entry. |
| `Write-CopilotAutopilotLog` | Append a timestamped line to the log. |

Shared home: `~/.copilot-autopilot/`
- `tools/`  — forged tools + `.cmd` launchers, added to `PATH`.
- `tools/manifest.json` — registry of forged tools.
- `autopilot.log` — timestamped record of every `copilot` invocation.

## Install

```powershell
# From a clone of this repo:
./install.ps1
# then reload:
. $PROFILE
```

`install.ps1` is **idempotent**: it replaces the existing marker block if
present, otherwise appends it, for both profile paths.

## Usage

```powershell
copilot "refactor the auth module and run the tests"   # autopilot (default)
copilot --no-auto "risky migration, ask me first"      # escape valve (one-off)
$env:COPILOT_NO_AUTOPILOT = 1                           # escape valve (session)
copilot --model gpt-5.4 "..."                           # model + autopilot combined
```

The wrapper **skips** autopilot injection automatically for subcommands
(`config`, `billing`, `providers`, …), help/version, and when a mode/prompt is
already specified (`--plan`, `--mode`, `-p`, `-i`, `--yolo`, …).

## Tool forge

When autopilot hits a missing tool and no ready solution exists:

```powershell
New-AutopilotTool epochconv -Language python -Description 'unix epoch -> ISO' -Body @'
import sys, datetime
print(datetime.datetime.utcfromtimestamp(int(sys.argv[1])).isoformat())
'@
epochconv 1700000000          # callable by bare name in any shell
```

Languages: `powershell` (default), `python`, `batch`. Each non-batch tool gets a
`.cmd` launcher so a bare `toolname` resolves from any shell via PATH.

**Guidance for the agent:** only forge a tool after (1) confirming it isn't
already installed, (2) checking the platform package managers, and (3) a web
search found no maintained equivalent. Keep forged tools small, single-purpose,
and dependency-light. Record what it does in `-Description`.

## Model support

`--autopilot` controls **approval/execution behavior, not the model**. It works
with every model the Copilot CLI exposes (Claude, GPT-5.x, Gemini) and with
`providers` BYOK custom models. `--model` is intentionally *not* in the skip
list, so `copilot --model <m> "..."` still gets autopilot. The wrapper is bound
to the GitHub Copilot CLI binary; other vendors' CLIs are out of scope, though
the forge/logging pattern ports easily.

## Uninstall

Remove the marker block from both profiles (or run `./uninstall.ps1`), then
optionally delete `~/.copilot-autopilot/`.

## Files

- `assets/copilot-autopilot.ps1` — the canonical wrapper block (source of truth).
- `install.ps1` / `uninstall.ps1` — idempotent (un)installers.
