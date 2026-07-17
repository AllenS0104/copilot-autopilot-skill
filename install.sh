#!/usr/bin/env bash
# Install/update the Copilot CLI autopilot wrapper into the bash and zsh rc files.
#
# Idempotently inserts the marker-delimited blocks from
# assets/copilot-autopilot.sh (the CLI wrapper) and assets/editor-autopilot.sh
# (the VS Code / Antigravity / fork configurator) into ~/.bashrc and ~/.zshrc.
# If a block already exists (between its markers) it is replaced; otherwise it
# is appended.
#
# Works on Ubuntu/Linux and macOS.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# "asset-file|begin-marker|end-marker" for every block this installer manages.
ASSETS='copilot-autopilot.sh|# >>> copilot-autopilot-default >>>|# <<< copilot-autopilot-default <<<
editor-autopilot.sh|# >>> copilot-autopilot-editors >>>|# <<< copilot-autopilot-editors <<<'

TARGETS="${HOME}/.bashrc ${HOME}/.zshrc"

for rc in ${TARGETS}; do
    touch "${rc}"
    printf '%s\n' "${ASSETS}" | while IFS='|' read -r asset_file begin_marker end_marker; do
        [ -n "${asset_file}" ] || continue
        asset="${SCRIPT_DIR}/assets/${asset_file}"
        [ -f "${asset}" ] || { echo "Missing asset: ${asset}" >&2; exit 1; }

        tmp="$(mktemp)"
        # Strip any existing block between the markers.
        awk -v b="${begin_marker}" -v e="${end_marker}" '
            index($0, b) { skip=1 }
            skip { if (index($0, e)) skip=0; next }
            { print }
        ' "${rc}" > "${tmp}"

        had_block=0
        grep -qF "${begin_marker}" "${rc}" && had_block=1

        # Drop trailing blank lines, then append a fresh copy of the block.
        awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}' "${tmp}" > "${rc}"
        if [ -s "${rc}" ]; then printf '\n' >> "${rc}"; fi
        cat "${asset}" >> "${rc}"

        if [ "${had_block}" -eq 1 ]; then
            echo "Updated ${asset_file} block in ${rc}"
        else
            echo "Appended ${asset_file} block to ${rc}"
        fi
        rm -f "${tmp}"
    done
done

echo
echo "Done. Reload with:  source ~/.bashrc   (or)   source ~/.zshrc"
echo "Then configure editors with:  set_editor_autopilot"
