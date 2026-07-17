---
name: autopilot
description: Set up and use the GitHub Copilot CLI "autopilot" wrapper on Windows (PowerShell) and Ubuntu/Linux + macOS (bash/zsh). Makes `copilot` auto-approve shell/tool commands by default, adds a --no-auto escape valve, timestamped execution logging, and a self-service "tool forge" (New-AutopilotTool / new_autopilot_tool) so autopilot can invent a missing CLI tool on the fly. Use when the user wants unattended/autonomous Copilot CLI runs, mentions autopilot mode, "auto-approve", "tool forge", New-AutopilotTool, or wants to install/update this wrapper in their PowerShell profile or shell rc.
license: MIT
---

# Copilot CLI Autopilot (PowerShell + bash/zsh)

A drop-in wrapper that makes the **GitHub Copilot CLI** run in autopilot mode by
default and gives an autonomous run three extra powers: an escape valve, an
execution log, and an on-the-fly **tool forge**.

Two equivalent implementations ship in this skill:

| Platform | Shell | Wrapper asset | Installer |
| --- | --- | --- | --- |
| Windows | PowerShell 7 + Windows PowerShell 5.1 | `assets/copilot-autopilot.ps1` | `install.ps1` |
| Ubuntu/Linux, macOS | bash + zsh | `assets/copilot-autopilot.sh` | `install.sh` |

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
`# <<< copilot-autopilot-default <<<`) is inserted into the shell startup files
for your platform.

### Windows (PowerShell)

The block goes into **both** PowerShell profiles (PowerShell 7 and Windows
PowerShell 5.1). It defines:

| Function | Purpose |
| --- | --- |
| `copilot` | Wraps `copilot.cmd`, injecting `--autopilot` by default. |
| `New-AutopilotTool` | Forge a new tool (ps1 / python / batch) onto PATH. |
| `Get-AutopilotTool` | List forged tools from the manifest. |
| `Remove-AutopilotTool` | Delete a forged tool + manifest entry. |
| `Write-CopilotAutopilotLog` | Append a timestamped line to the log. |

### Ubuntu/Linux & macOS (bash/zsh)

The block goes into **both** `~/.bashrc` and `~/.zshrc`. It defines:

| Function | Purpose |
| --- | --- |
| `copilot` | Wraps the real `copilot` binary, injecting `--autopilot` by default. |
| `new_autopilot_tool` | Forge a new tool (bash / python) onto PATH. |
| `get_autopilot_tool` | List forged tools from the manifest. |
| `remove_autopilot_tool` | Delete a forged tool + manifest entry. |

> iOS itself cannot run a terminal/CLI; use the macOS wrapper for the
> Apple platform.

Shared home (all platforms): `~/.copilot-autopilot/`
- `tools/`  — forged tools (plus `.cmd` launchers on Windows), added to `PATH`.
- `tools/manifest.json` — registry of forged tools.
- `autopilot.log` — timestamped record of every `copilot` invocation.

## Install

### Windows (PowerShell)

```powershell
# From a clone of this repo:
./install.ps1
# then reload:
. $PROFILE
```

`install.ps1` is **idempotent**: it replaces the existing marker block if
present, otherwise appends it, for both profile paths.

### Ubuntu/Linux & macOS (bash/zsh)

```bash
# From a clone of this repo:
bash ./install.sh
# then reload:
source ~/.bashrc   # or: source ~/.zshrc
```

`install.sh` is likewise **idempotent** across `~/.bashrc` and `~/.zshrc`.

## Usage

### Windows (PowerShell)

```powershell
copilot "refactor the auth module and run the tests"   # autopilot (default)
copilot --no-auto "risky migration, ask me first"      # escape valve (one-off)
$env:COPILOT_NO_AUTOPILOT = 1                           # escape valve (session)
copilot --model gpt-5.4 "..."                           # model + autopilot combined
```

### Ubuntu/Linux & macOS (bash/zsh)

```bash
copilot "refactor the auth module and run the tests"   # autopilot (default)
copilot --no-auto "risky migration, ask me first"      # escape valve (one-off)
export COPILOT_NO_AUTOPILOT=1                           # escape valve (session)
copilot --model gpt-5.4 "..."                           # model + autopilot combined
```

The wrapper **skips** autopilot injection automatically for subcommands
(`config`, `billing`, `providers`, …), help/version, and when a mode/prompt is
already specified (`--plan`, `--mode`, `-p`, `-i`, `--yolo`, …).

## Tool forge

When autopilot hits a missing tool and no ready solution exists:

**Windows (PowerShell):**

```powershell
New-AutopilotTool epochconv -Language python -Description 'unix epoch -> ISO' -Body @'
import sys, datetime
print(datetime.datetime.utcfromtimestamp(int(sys.argv[1])).isoformat())
'@
epochconv 1700000000          # callable by bare name in any shell
```

Languages: `powershell` (default), `python`, `batch`. Each non-batch tool gets a
`.cmd` launcher so a bare `toolname` resolves from any shell via PATH.

**Ubuntu/Linux & macOS (bash/zsh):**

```bash
new_autopilot_tool epochconv --language python --description 'unix epoch -> ISO' --body '
import sys, datetime
print(datetime.datetime.utcfromtimestamp(int(sys.argv[1])).isoformat())
'
epochconv 1700000000          # callable by bare name (chmod +x, on PATH)
# body may also be piped on stdin:
printf "echo hi\n" | new_autopilot_tool greet --language bash
```

Languages: `bash` (default), `python`. Each tool is made executable and dropped
into `~/.copilot-autopilot/tools` (already on PATH).

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

- **Windows:** remove the marker block from both profiles (or run
  `./uninstall.ps1`).
- **Ubuntu/Linux & macOS:** remove the block from `~/.bashrc` and `~/.zshrc`
  (or run `bash ./uninstall.sh`).

Then optionally delete `~/.copilot-autopilot/`.

## Files

- `assets/copilot-autopilot.ps1` — canonical PowerShell wrapper block (Windows).
- `assets/copilot-autopilot.sh` — canonical bash/zsh wrapper block (Linux/macOS).
- `install.ps1` / `uninstall.ps1` — idempotent Windows (un)installers.
- `install.sh` / `uninstall.sh` — idempotent Linux/macOS (un)installers.
- `.gitattributes` — forces LF on `.sh` files so they run on Linux/macOS.
