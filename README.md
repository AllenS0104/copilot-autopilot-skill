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

## Agentic editors (VS Code, Antigravity, …)

Editors are configured through their `User/settings.json`, so use the
`*-EditorAutopilot` helpers (installed with the wrapper) instead of a command
wrapper. Existing settings are merged (a `.autopilot.bak` backup is written),
re-running is idempotent, and `Reset-EditorAutopilot` cleanly reverts.

### VS Code / VS Code Insiders / VSCodium — fully automated

Prerequisite: the **GitHub Copilot** + **GitHub Copilot Chat** extensions
installed and signed in.

```powershell
# Windows (PowerShell)
. $PROFILE                          # reload so the functions are available
Set-EditorAutopilot -Editor Code    # write verified autopilot keys
# optional, trusted environments only — blanket-approve ALL tools + terminal:
Set-EditorAutopilot -Editor Code -Aggressive
Get-EditorAutopilot Code            # inspect
Reset-EditorAutopilot Code          # revert
```

```bash
# Ubuntu/Linux & macOS (bash/zsh)
source ~/.bashrc                    # or: source ~/.zshrc
set_editor_autopilot Code           # write verified autopilot keys
set_editor_autopilot Code --aggressive   # trusted environments only
get_editor_autopilot Code
reset_editor_autopilot Code
```

This writes to `settings.json`:

```jsonc
{
  "chat.agent.enabled": true,
  "chat.permissions.default": "autopilot"   // new sessions auto-approve + keep going
}
```

Then run **Developer: Reload Window** in VS Code. You can also skip the tool and
pick **Autopilot** from the permissions dropdown in the Chat view (per session),
or add the keys above by hand via **Preferences: Open User Settings (JSON)**.

### Antigravity (Google) — settings ensured + in-app Turbo

Antigravity's full autonomy lives behind an in-app toggle with no documented
`settings.json` key, so the tool ensures the settings file exists and prints the
exact steps rather than inventing keys.

```powershell
Set-EditorAutopilot -Editor Antigravity   # ensures settings.json + prints steps
```

Then in Antigravity: **Settings → Agent → "Terminal Command Auto Execution" →
Turbo**, and review the **Allow/Deny** lists (or set it via the Antigravity CLI
`/permissions`). Cursor and Windsurf work the same way (Auto-Run/YOLO and
Cascade Turbo respectively) — run `Set-EditorAutopilot` with no `-Editor` to
handle every installed editor at once.

> **Caution:** auto-approving every command reduces protection against prompt
> injection. Use these settings only in trusted environments.

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
