# >>> copilot-autopilot-editors >>>
# Extend "autopilot" (auto-approve agent actions by default) from the Copilot
# CLI to GUI agentic editors: VS Code, VS Code Insiders, VSCodium, plus the
# VS Code forks Antigravity (Google), Cursor and Windsurf.
#
# GUI editors are configured through their User settings.json, not a shell rc,
# so this block adds helper functions instead of a wrapper:
#   set_editor_autopilot   [editor] [--aggressive]  -> apply auto-approve settings
#   get_editor_autopilot   [editor]                 -> show current settings
#   reset_editor_autopilot [editor]                 -> remove keys this tool added
#
# VS Code + Copilot Chat is driven by verified settings keys, so it is automated
# end to end. The forks (Antigravity/Cursor/Windsurf) gate full autonomy behind
# an in-app toggle with no publicly documented JSON key, so this tool just
# ensures their settings file exists and prints the exact in-app steps.

# Resolve the User/settings.json path for an editor data dir on this platform.
_copilot_editor_settings_path() {
    _dir="$1"
    case "$(uname -s)" in
        Darwin) printf '%s/Library/Application Support/%s/User/settings.json' "$HOME" "$_dir" ;;
        *)      printf '%s/.config/%s/User/settings.json' "$HOME" "$_dir" ;;
    esac
}

# "Name|Dir|Flavor" registry of known agentic editors.
_copilot_editor_registry() {
    cat <<'EOF'
VS Code|Code|copilot
VS Code Insiders|Code - Insiders|copilot
VSCodium|VSCodium|copilot
Cursor|Cursor|cursor
Windsurf|Windsurf|windsurf
Antigravity|Antigravity|antigravity
EOF
}

set_editor_autopilot() {
    _filter='All'; _aggressive=0
    for _a in "$@"; do
        case "$_a" in
            --aggressive) _aggressive=1 ;;
            *) _filter="$_a" ;;
        esac
    done
    command -v python3 >/dev/null 2>&1 || { echo "python3 is required for JSON merging." >&2; return 1; }

    _copilot_editor_registry | while IFS='|' read -r _name _dir _flavor; do
        [ -n "$_name" ] || continue
        if [ "$_filter" != "All" ]; then
            case "$_name$_dir" in *"$_filter"*) : ;; *) continue ;; esac
        fi
        _path="$(_copilot_editor_settings_path "$_dir")"
        _pdir="$(dirname "$_path")"

        if [ ! -d "$_pdir" ] && [ ! -f "$_path" ]; then
            printf 'skip   %-16s (not installed)\n' "$_name"
            continue
        fi

        if [ "$_flavor" != "copilot" ]; then
            mkdir -p "$_pdir"
            [ -f "$_path" ] || printf '{}\n' > "$_path"
            printf 'manual %-16s settings.json ready -> enable in-app autonomy:\n' "$_name"
            case "$_flavor" in
                antigravity) echo "         Settings > Agent > 'Terminal Command Auto Execution' = Turbo (review Allow/Deny lists)" ;;
                cursor)      echo "         Agent panel > enable Auto-Run (YOLO) mode; edit the allowlist there" ;;
                windsurf)    echo "         Cascade panel > set autonomy to Turbo (auto-run commands)" ;;
            esac
            continue
        fi

        AP_AGGRESSIVE="$_aggressive" python3 - "$_path" "$_name" <<'PY'
import json, os, re, sys, shutil
path, name = sys.argv[1], sys.argv[2]
aggressive = os.environ.get("AP_AGGRESSIVE") == "1"
raw = ""
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
def parse_jsonc(text):
    if not text.strip():
        return {}
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(?m)^\s*//.*$", "", text)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)
try:
    data = parse_jsonc(raw)
    if not isinstance(data, dict):
        raise ValueError("root is not an object")
except Exception as e:
    print("skip   %-16s settings.json not parseable (%s); left untouched" % (name, e))
    sys.exit(0)
os.makedirs(os.path.dirname(path), exist_ok=True)
if os.path.exists(path):
    shutil.copyfile(path, path + ".autopilot.bak")
data["chat.agent.enabled"] = True
data["chat.permissions.default"] = "autopilot"
if aggressive:
    data["chat.tools.autoApprove"] = True
    data["chat.tools.terminal.autoApprove"] = {"/.*/": True}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
    f.write("\n")
print("ok     %-16s autopilot settings applied%s" % (name, " (aggressive)" if aggressive else ""))
PY
    done
    echo
    echo "Reload each editor window (Developer: Reload Window) to pick up the changes."
}

get_editor_autopilot() {
    _filter="${1:-All}"
    _copilot_editor_registry | while IFS='|' read -r _name _dir _flavor; do
        [ -n "$_name" ] || continue
        if [ "$_filter" != "All" ]; then
            case "$_name$_dir" in *"$_filter"*) : ;; *) continue ;; esac
        fi
        _path="$(_copilot_editor_settings_path "$_dir")"
        [ -f "$_path" ] || continue
        command -v python3 >/dev/null 2>&1 || { echo "$_name: $_path"; continue; }
        python3 - "$_path" "$_name" "$_flavor" <<'PY'
import json, re, sys
path, name, flavor = sys.argv[1], sys.argv[2], sys.argv[3]
keys = ["chat.agent.enabled","chat.permissions.default","chat.tools.autoApprove","chat.tools.terminal.autoApprove"]
raw = open(path, encoding="utf-8").read()
raw = re.sub(r"/\*.*?\*/","",raw,flags=re.S); raw = re.sub(r"(?m)^\s*//.*$","",raw); raw = re.sub(r",(\s*[}\]])",r"\1",raw)
try:
    d = json.loads(raw) if raw.strip() else {}
except Exception:
    d = {}
present = {k: d[k] for k in keys if k in d}
print("%-16s [%s] %s" % (name, flavor, path))
for k, v in present.items():
    print("    %s = %s" % (k, json.dumps(v)))
PY
    done
}

reset_editor_autopilot() {
    _filter="${1:-All}"
    command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; return 1; }
    _copilot_editor_registry | while IFS='|' read -r _name _dir _flavor; do
        [ -n "$_name" ] || continue
        [ "$_flavor" = "copilot" ] || continue
        if [ "$_filter" != "All" ]; then
            case "$_name$_dir" in *"$_filter"*) : ;; *) continue ;; esac
        fi
        _path="$(_copilot_editor_settings_path "$_dir")"
        [ -f "$_path" ] || continue
        python3 - "$_path" "$_name" <<'PY'
import json, os, re, sys, shutil
path, name = sys.argv[1], sys.argv[2]
keys = ["chat.agent.enabled","chat.permissions.default","chat.tools.autoApprove","chat.tools.terminal.autoApprove"]
raw = open(path, encoding="utf-8").read()
t = re.sub(r"/\*.*?\*/","",raw,flags=re.S); t = re.sub(r"(?m)^\s*//.*$","",t); t = re.sub(r",(\s*[}\]])",r"\1",t)
try:
    d = json.loads(t) if t.strip() else {}
except Exception:
    print("skip   %-16s not parseable" % name); sys.exit(0)
removed = [k for k in keys if d.pop(k, None) is not None]
if removed:
    shutil.copyfile(path, path + ".autopilot.bak")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=4); f.write("\n")
    print("reset  %-16s removed: %s" % (name, ", ".join(removed)))
PY
    done
}
# <<< copilot-autopilot-editors <<<
