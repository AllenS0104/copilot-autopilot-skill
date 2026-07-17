# >>> copilot-autopilot-default >>>
# Make the GitHub Copilot CLI start in autopilot mode by default on Ubuntu/Linux
# and macOS, so shell/tool commands run automatically without stopping for a
# "Do you want to run this command?" confirmation each time.
#
# This is the POSIX-shell (bash/zsh) counterpart of the PowerShell wrapper block.
# Injection is skipped for subcommands, help/version, and when a mode or prompt
# is already specified.
#
# Enhancements:
#   1. Escape valve   -> `copilot --no-auto ...` or env COPILOT_NO_AUTOPILOT=1
#                        temporarily disables autopilot injection.
#   2. Shell sync     -> this identical block lives in ~/.bashrc and ~/.zshrc.
#   3. Execution log  -> every invocation is timestamped to autopilot.log.
#   4. Tool forge     -> a self-created tools dir is put on PATH, and
#                        new_autopilot_tool lets autopilot invent a missing tool
#                        on the fly when web search yields no ready solution.

# --- Shared autopilot home (same for bash and zsh) -----------------------------
COPILOT_AUTOPILOT_HOME="${HOME}/.copilot-autopilot"
COPILOT_TOOLS_BIN="${COPILOT_AUTOPILOT_HOME}/tools"
COPILOT_LOG="${COPILOT_AUTOPILOT_HOME}/autopilot.log"
COPILOT_MANIFEST="${COPILOT_TOOLS_BIN}/manifest.json"

[ -d "${COPILOT_TOOLS_BIN}" ] || mkdir -p "${COPILOT_TOOLS_BIN}"

# Put self-created tools on PATH so a bare `toolname` resolves in any shell.
case ":${PATH}:" in
    *":${COPILOT_TOOLS_BIN}:"*) : ;;
    *) PATH="${COPILOT_TOOLS_BIN}:${PATH}"; export PATH ;;
esac

_copilot_autopilot_log() {
    # Append a timestamped line to the log; never let logging break a command.
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "${COPILOT_LOG}" 2>/dev/null || true
}

copilot() {
    # Enhancement 1: escape valve. Strip our own --no-auto flag before forwarding.
    local forwarded=()
    local force_no_auto=0
    local a
    for a in "$@"; do
        if [ "$a" = "--no-auto" ]; then force_no_auto=1; continue; fi
        forwarded+=("$a")
    done

    local inject=1
    if [ "$force_no_auto" -eq 1 ]; then
        inject=0
    elif [ -n "${COPILOT_NO_AUTOPILOT:-}" ] && \
         [ "${COPILOT_NO_AUTOPILOT}" != "0" ] && \
         [ "${COPILOT_NO_AUTOPILOT}" != "false" ] && \
         [ "${COPILOT_NO_AUTOPILOT}" != "False" ]; then
        inject=0
    else
        # Skip injection for subcommands, help/version, or an already-specified
        # mode/prompt. `case` avoids bash-vs-zsh word-splitting differences.
        local w
        for w in "${forwarded[@]}"; do
            case "$w" in
                billing|commands|config|permissions|providers|help|\
--autopilot|--plan|--mode|--interactive|-i|-p|--prompt|--acp|\
--help|-h|--version|-V|--yolo|--allow-all)
                    inject=0; break ;;
            esac
        done
    fi

    if [ "$inject" -eq 1 ]; then
        _copilot_autopilot_log "autopilot | copilot ${forwarded[*]}"
        command copilot --autopilot "${forwarded[@]}"
    else
        _copilot_autopilot_log "manual    | copilot ${forwarded[*]}"
        command copilot "${forwarded[@]}"
    fi
}

# --- Enhancement 4: the tool forge --------------------------------------------
# During autopilot, when a required tool is missing and neither the package
# managers nor a web search yield a usable one, autopilot can synthesize a
# purpose-built tool with new_autopilot_tool. The tool lands in
# ${COPILOT_TOOLS_BIN} (already on PATH), made executable, so it is immediately
# callable by name.
#
# Usage:
#   new_autopilot_tool <name> [--language bash|python] [--description "..."]
#                       [--force] --body 'SCRIPT SOURCE'
#   # or pipe the body on stdin:
#   printf '%s\n' 'echo hi' | new_autopilot_tool greet --language bash
new_autopilot_tool() {
    local name="" language="bash" description="" body="" force=0 have_body=0
    if [ $# -gt 0 ]; then name="$1"; shift; fi
    while [ $# -gt 0 ]; do
        case "$1" in
            --language|-l) language="$2"; shift 2 ;;
            --description|-d) description="$2"; shift 2 ;;
            --body|-b) body="$2"; have_body=1; shift 2 ;;
            --force|-f) force=1; shift ;;
            *) printf 'new_autopilot_tool: unknown arg: %s\n' "$1" >&2; return 2 ;;
        esac
    done

    if [ -z "$name" ]; then
        printf 'new_autopilot_tool: a tool name is required.\n' >&2; return 2
    fi
    case "$name" in
        *[!A-Za-z0-9._-]*)
            printf "new_autopilot_tool: invalid name '%s' (use A-Z a-z 0-9 . _ -).\n" "$name" >&2
            return 2 ;;
    esac
    case "$language" in
        bash|python) : ;;
        *) printf "new_autopilot_tool: language must be bash or python.\n" >&2; return 2 ;;
    esac

    # Body from stdin when not passed via --body and stdin is not a tty.
    if [ "$have_body" -eq 0 ] && [ ! -t 0 ]; then
        body="$(cat)"
    fi
    if [ -z "$body" ]; then
        printf 'new_autopilot_tool: empty tool body.\n' >&2; return 2
    fi

    [ -d "${COPILOT_TOOLS_BIN}" ] || mkdir -p "${COPILOT_TOOLS_BIN}"
    local target="${COPILOT_TOOLS_BIN}/${name}"
    if [ -e "$target" ] && [ "$force" -eq 0 ]; then
        printf "new_autopilot_tool: tool '%s' already exists. Pass --force to overwrite.\n" "$name" >&2
        return 1
    fi

    local shebang
    case "$language" in
        bash)   shebang='#!/usr/bin/env bash' ;;
        python) shebang='#!/usr/bin/env python3' ;;
    esac

    # Write the shebang unless the body already begins with one.
    case "$body" in
        '#!'*) printf '%s\n' "$body" > "$target" ;;
        *)     printf '%s\n%s\n' "$shebang" "$body" > "$target" ;;
    esac
    chmod +x "$target"

    _copilot_tool_manifest_upsert "$name" "$language" "$description" "$target"
    _copilot_autopilot_log "forge     | created tool '${name}' (${language}) - ${description}"
    printf "Forged tool '%s' (%s) -> %s\n" "$name" "$language" "$target"
}

get_autopilot_tool() {
    # List forged tools recorded in the manifest (optionally filter by name glob).
    local filter="${1:-}"
    [ -f "${COPILOT_MANIFEST}" ] || { printf '[]\n'; return 0; }
    if command -v python3 >/dev/null 2>&1; then
        MANIFEST="${COPILOT_MANIFEST}" FILTER="$filter" python3 - <<'PY'
import json, os, fnmatch
p = os.environ["MANIFEST"]; f = os.environ.get("FILTER") or ""
try:
    tools = json.load(open(p))
except Exception:
    tools = []
if f:
    tools = [t for t in tools if fnmatch.fnmatch(t.get("name", ""), f)]
print(json.dumps(tools, indent=2))
PY
    else
        cat "${COPILOT_MANIFEST}"
    fi
}

remove_autopilot_tool() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        printf 'remove_autopilot_tool: a tool name is required.\n' >&2; return 2
    fi
    rm -f "${COPILOT_TOOLS_BIN}/${name}" 2>/dev/null || true
    _copilot_tool_manifest_remove "$name"
    _copilot_autopilot_log "forge     | removed tool '${name}'"
}

# --- Manifest helpers (JSON array; uses python3 when available) ----------------
_copilot_tool_manifest_upsert() {
    local name="$1" language="$2" description="$3" launcher="$4"
    if command -v python3 >/dev/null 2>&1; then
        MANIFEST="${COPILOT_MANIFEST}" N="$name" L="$language" D="$description" \
        LN="$launcher" TS="$(date '+%Y-%m-%d %H:%M:%S')" python3 - <<'PY'
import json, os
p = os.environ["MANIFEST"]
try:
    tools = json.load(open(p))
    if not isinstance(tools, list): tools = []
except Exception:
    tools = []
name = os.environ["N"]
tools = [t for t in tools if t.get("name") != name]
tools.append({
    "name": name, "language": os.environ["L"],
    "description": os.environ["D"], "launcher": os.environ["LN"],
    "created": os.environ["TS"],
})
json.dump(tools, open(p, "w"), indent=2)
PY
    fi
}

_copilot_tool_manifest_remove() {
    local name="$1"
    if command -v python3 >/dev/null 2>&1; then
        MANIFEST="${COPILOT_MANIFEST}" N="$name" python3 - <<'PY'
import json, os
p = os.environ["MANIFEST"]
try:
    tools = json.load(open(p))
    if not isinstance(tools, list): tools = []
except Exception:
    tools = []
name = os.environ["N"]
tools = [t for t in tools if t.get("name") != name]
json.dump(tools, open(p, "w"), indent=2)
PY
    fi
}
# <<< copilot-autopilot-default <<<
