#!/usr/bin/env bash
# Remove the Copilot CLI autopilot wrapper block from the bash and zsh rc files.
#
# Works on Ubuntu/Linux and macOS.
set -eu

MARKERS='# >>> copilot-autopilot-default >>>|# <<< copilot-autopilot-default <<<
# >>> copilot-autopilot-editors >>>|# <<< copilot-autopilot-editors <<<'

TARGETS="${HOME}/.bashrc ${HOME}/.zshrc"

for rc in ${TARGETS}; do
    [ -f "${rc}" ] || continue
    removed_any=0
    printf '%s\n' "${MARKERS}" | { while IFS='|' read -r begin_marker end_marker; do
        [ -n "${begin_marker}" ] || continue
        if grep -qF "${begin_marker}" "${rc}"; then
            tmp="$(mktemp)"
            awk -v b="${begin_marker}" -v e="${end_marker}" '
                index($0, b) { skip=1 }
                skip { if (index($0, e)) skip=0; next }
                { print }
            ' "${rc}" > "${tmp}"
            # Drop trailing blank lines left behind.
            awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}' "${tmp}" > "${rc}"
            [ -s "${rc}" ] && printf '\n' >> "${rc}"
            rm -f "${tmp}"
            removed_any=1
        fi
    done
    if [ "${removed_any}" -eq 1 ]; then
        echo "Removed autopilot blocks from ${rc}"
    else
        echo "No block found in ${rc}"
    fi
    }
done

echo
echo "Done. The ~/.copilot-autopilot/ folder (logs, forged tools) was left intact."
