#!/usr/bin/env bash
# Install/update the Copilot CLI autopilot wrapper into the bash and zsh rc files.
#
# Idempotently inserts the marker-delimited block from
# assets/copilot-autopilot.sh into ~/.bashrc and ~/.zshrc. If the block already
# exists (between the markers) it is replaced; otherwise it is appended.
#
# Works on Ubuntu/Linux and macOS.
set -eu

BEGIN_MARKER='# >>> copilot-autopilot-default >>>'
END_MARKER='# <<< copilot-autopilot-default <<<'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSET="${SCRIPT_DIR}/assets/copilot-autopilot.sh"
[ -f "${ASSET}" ] || { echo "Missing asset: ${ASSET}" >&2; exit 1; }

TARGETS="${HOME}/.bashrc ${HOME}/.zshrc"

for rc in ${TARGETS}; do
    touch "${rc}"
    tmp="$(mktemp)"
    # Strip any existing block between the markers.
    awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" '
        index($0, b) { skip=1 }
        skip { if (index($0, e)) skip=0; next }
        { print }
    ' "${rc}" > "${tmp}"

    # Drop trailing blank lines, then append a fresh copy of the block.
    awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}' "${tmp}" > "${rc}"
    if [ -s "${rc}" ]; then printf '\n' >> "${rc}"; fi
    cat "${ASSET}" >> "${rc}"

    if grep -qF "${BEGIN_MARKER}" "${tmp}"; then
        echo "Updated existing block in ${rc}"
    else
        echo "Appended block to ${rc}"
    fi
    rm -f "${tmp}"
done

echo
echo "Done. Reload with:  source ~/.bashrc   (or)   source ~/.zshrc"
