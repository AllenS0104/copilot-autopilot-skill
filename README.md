# copilot-autopilot-skill

A GitHub **Copilot CLI skill** + PowerShell wrapper that makes the `copilot`
command run in **autopilot mode** by default on Windows — with an escape valve,
timestamped execution logging, and a self-service **tool forge**.

> Built and verified interactively with the GitHub Copilot CLI.

## Highlights

- **Autopilot by default** — `copilot "…"` auto-approves shell/tool commands
  instead of prompting for each one. Subcommands, help/version, and explicit
  modes (`--plan`, `-p`, `-i`, `--yolo`, …) are left untouched.
- **Escape valve** — `copilot --no-auto "…"` (one-off) or
  `$env:COPILOT_NO_AUTOPILOT = 1` (whole session) disables injection.
- **Execution log** — every invocation is timestamped to
  `~/.copilot-autopilot/autopilot.log` (`autopilot |` vs `manual |`).
- **Tool forge** — `New-AutopilotTool` lets an autonomous run invent a missing
  CLI tool (PowerShell / Python / batch) on the fly, placed on `PATH` with a
  `.cmd` launcher and tracked in a manifest.
- **Model-agnostic** — works with any Copilot CLI model (Claude, GPT-5.x,
  Gemini) and BYOK providers; `--model` composes with autopilot.

## Install

```powershell
git clone https://github.com/AllenS0104/copilot-autopilot-skill.git
cd copilot-autopilot-skill
./install.ps1        # idempotent: updates both PS7 + WinPS5.1 profiles
. $PROFILE           # reload current session
```

To use it as a Copilot CLI **skill**, place (or symlink) this folder under
`~/.copilot/skills/autopilot/` so the CLI can load `SKILL.md`.

## Usage

```powershell
copilot "add pagination to the users endpoint and run the tests"
copilot --no-auto "delete the prod bucket"     # ask me first
copilot --model gpt-5.4 "…"                    # model + autopilot together

New-AutopilotTool epochconv -Language python -Description 'unix epoch -> ISO' -Body @'
import sys, datetime
print(datetime.datetime.utcfromtimestamp(int(sys.argv[1])).isoformat())
'@
epochconv 1700000000
Get-AutopilotTool
```

## Uninstall

```powershell
./uninstall.ps1      # removes the block from both profiles
```

The `~/.copilot-autopilot/` folder (logs + forged tools) is preserved.

## Layout

```
copilot-autopilot-skill/
├─ SKILL.md                      # Copilot CLI skill manifest + agent guidance
├─ install.ps1                   # idempotent installer (both profiles)
├─ uninstall.ps1                 # remove the block
├─ assets/
│  └─ copilot-autopilot.ps1      # canonical wrapper block (source of truth)
└─ README.md
```

## License

MIT — see [LICENSE](LICENSE).
