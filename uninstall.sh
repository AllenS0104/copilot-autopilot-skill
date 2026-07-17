#!/usr/bin/env bash
# Remove the Copilot CLI autopilot wrapper block from the bash and zsh rc files.
#
# Works on Ubuntu/Linux and macOS.
set -eu

BEGIN_MARKER='# >>> copilot-autopilot-default >>>'
END_MARKER='# <<< copilot-autopilot-default <<<'

TARGETS="${HOME}/.bashrc ${HOME}/.zshrc"

for rc in ${TARGETS}; do
    [ -f "${rc}" ] || continue
    if grep -qF "${BEGIN_MARKER}" "${rc}"; then
        tmp="$(mktemp)"
        awk -v b="${BEGIN_MARKER}" -v e="${END_MARKER}" '
            index($0, b) { skip=1 }
            skip { if (index($0, e)) skip=0; next }
            { print }
        ' "${rc}" > "${tmp}"
        # Drop trailing blank lines left behind.
        awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}' "${tmp}" > "${rc}"
        [ -s "${rc}" ] && printf '\n' >> "${rc}"
        rm -f "${tmp}"
        echo "Removed block from ${rc}"
    else
        echo "No block found in ${rc}"
    fi
done

echo
echo "Done. The ~/.copilot-autopilot/ folder (logs, forged tools) was left intact."
