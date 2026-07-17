# copilot-autopilot-skill

A GitHub **Copilot skill** + shell wrapper that makes the `copilot`
command run in **autopilot mode** by default — with an escape valve,
timestamped execution logging, and a self-service **tool forge** — and extends
auto-approve to **agentic editors** (VS Code, Antigravity, Cursor, Windsurf).

Cross-platform: **Windows** (PowerShell 7 + Windows PowerShell 5.1) and
**Ubuntu/Linux + macOS** (bash + zsh). iOS cannot run a terminal/CLI, so the
macOS wrapper covers the Apple platform.

> Built and verified interactively with the GitHub Copilot CLI.

## Highlights

- **Autopilot by default** — `copilot "…"` auto-approves shell/tool commands
  instead of prompting for each one. Subcommands, help/version, and explicit
  modes (`--plan`, `-p`, `-i`, `--yolo`, …) are left untouched.
- **Escape valve** — `copilot --no-auto "…"` (one-off) or
  `COPILOT_NO_AUTOPILOT=1` (whole session) disables injection.
- **Execution log** — every invocation is timestamped to
  `~/.copilot-autopilot/autopilot.log` (`autopilot |` vs `manual |`).
- **Tool forge** — `New-AutopilotTool` (PowerShell) / `new_autopilot_tool`
  (bash/zsh) lets an autonomous run invent a missing CLI tool on the fly,
  placed on `PATH` and tracked in a manifest.
- **Agentic editors** — `Set-EditorAutopilot` / `set_editor_autopilot`
  configures **VS Code / Insiders** (Copilot Chat Autopilot, fully automated)
  and ensures + guides autonomy for the VS Code forks **Antigravity** (Google),
  **Cursor** and **Windsurf**.
- **Model-agnostic** — works with any Copilot CLI model (Claude, GPT-5.x,
  Gemini) and BYOK providers; `--model` composes with autopilot.

## Install

### Windows (PowerShell)

```powershell
git clone https://github.com/AllenS0104/copilot-autopilot-skill.git
cd copilot-autopilot-skill
./install.ps1        # idempotent: updates both PS7 + WinPS5.1 profiles
. $PROFILE           # reload current session
```

### Ubuntu/Linux & macOS (bash/zsh)

```bash
git clone https://github.com/AllenS0104/copilot-autopilot-skill.git
cd copilot-autopilot-skill
bash ./install.sh          # idempotent: updates ~/.bashrc + ~/.zshrc
source ~/.bashrc           # or: source ~/.zshrc
```

To use it as a Copilot CLI **skill**, place (or symlink) this folder under
`~/.copilot/skills/autopilot/` so the CLI can load `SKILL.md`.

## Usage

### Windows (PowerShell)

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

# Configure agentic editors for auto-approve:
Set-EditorAutopilot                 # VS Code fully automated; Antigravity/Cursor/Windsurf guided
Set-EditorAutopilot -Aggressive     # also blanket-approve all tools + terminal
Get-EditorAutopilot                 # inspect what was applied
```

### Ubuntu/Linux & macOS (bash/zsh)

```bash
copilot "add pagination to the users endpoint and run the tests"
copilot --no-auto "delete the prod bucket"     # ask me first
copilot --model gpt-5.4 "…"                    # model + autopilot together

new_autopilot_tool epochconv --language python --description 'unix epoch -> ISO' --body '
import sys, datetime
print(datetime.datetime.utcfromtimestamp(int(sys.argv[1])).isoformat())
'
epochconv 1700000000
get_autopilot_tool

# Configure agentic editors for auto-approve:
set_editor_autopilot                 # VS Code fully automated; forks guided
set_editor_autopilot Code --aggressive
get_editor_autopilot
```

## Uninstall

```powershell
./uninstall.ps1      # Windows: removes the block from both profiles
```

```bash
bash ./uninstall.sh  # Linux/macOS: removes the block from ~/.bashrc + ~/.zshrc
```

The `~/.copilot-autopilot/` folder (logs + forged tools) is preserved. Editor
settings written to `settings.json` are **not** touched by uninstall — run
`Reset-EditorAutopilot` / `reset_editor_autopilot` first if you want them gone.

## Layout

```
copilot-autopilot-skill/
├─ SKILL.md                      # Copilot CLI skill manifest + agent guidance
├─ install.ps1 / uninstall.ps1   # idempotent Windows (un)installers
├─ install.sh  / uninstall.sh    # idempotent Linux/macOS (un)installers
├─ .gitattributes                # forces LF on *.sh (so they run on Linux/macOS)
├─ assets/
│  ├─ copilot-autopilot.ps1      # canonical PowerShell CLI wrapper block
│  ├─ copilot-autopilot.sh       # canonical bash/zsh CLI wrapper block
│  ├─ editor-autopilot.ps1       # PowerShell editor configurator block
│  └─ editor-autopilot.sh        # bash/zsh editor configurator block
└─ README.md
```

## License

MIT — see [LICENSE](LICENSE).
