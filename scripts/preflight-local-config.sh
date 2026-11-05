#!/usr/bin/env bash
#
# Guardrail run before `darwin-rebuild switch`.
#
# Nix evaluation is non-interactive — it cannot stop and ask a question — so a
# missing machine-local value would otherwise be silently replaced by its
# built-in default and applied to the system. This script asks the flake which
# keys are about to fall back, shows them, and requires confirmation first.
#
#   usage: preflight-local-config <flake-path>
#
# Exit codes: 0 continue, 1 abort.
#
# Environment:
#   MACBOOK_CONFIGS_ASSUME_YES=1  accept all fallbacks without prompting
#   MACBOOK_CONFIGS_LOCAL=<path>  override which local config file is read
set -euo pipefail

flake="${1:-}"
if [ -z "$flake" ]; then
  echo "usage: preflight-local-config <flake-path>" >&2
  exit 1
fi

# MACBOOK_CONFIGS_STRICT is cleared for this query only. Under strict mode the
# merged config throws, and because darwinConfigurations is keyed by the
# hostname *from* that config, the whole output set — report included — becomes
# unevaluatable. Reporting what is missing is exactly what we need here, so ask
# without strict; the real rebuild that follows still honours it.
if ! report=$(/usr/bin/env -u MACBOOK_CONFIGS_STRICT \
  nix eval --impure --json "${flake}#localConfigReport" 2>/dev/null); then
  echo "preflight: could not evaluate ${flake}#localConfigReport" >&2
  echo "preflight: re-run manually to see the evaluation error:" >&2
  echo "    nix eval --impure --json ${flake}#localConfigReport" >&2
  exit 1
fi

source_file=$(jq -r '.source // ""' <<<"$report")
missing_count=$(jq -r '.missingNames | length' <<<"$report")

if [ "$missing_count" -eq 0 ]; then
  # Every supported key is set explicitly; nothing to warn about.
  exit 0
fi

echo
if [ -n "$source_file" ]; then
  echo "Machine-local config: ${source_file}"
else
  echo "Machine-local config: NO FILE FOUND"
  echo "  Looked for \$MACBOOK_CONFIGS_LOCAL, ~/.config/macbook-configs/local.nix,"
  echo "  and /Users/\$SUDO_USER/.config/macbook-configs/local.nix"
fi

echo
echo "${missing_count} value(s) are not set and will fall back to built-in defaults:"
echo
jq -r '
  .missing
  | to_entries
  | sort_by(.key)[]
  | "    \(.key) = " + (
      if .value == null then "null   (feature left disabled)" else (.value | tojson) end
    )
' <<<"$report"
echo
echo "These defaults are placeholders, not your machine's real values."
echo "Applying them can build the wrong hostname or user. Edit the file above"
echo "(template: local.nix.example) to set them."
echo

if [ "${MACBOOK_CONFIGS_ASSUME_YES:-0}" = "1" ]; then
  echo "MACBOOK_CONFIGS_ASSUME_YES=1 — continuing with the defaults above."
  exit 0
fi

if [ ! -t 0 ]; then
  echo "Not running on an interactive terminal, so the question cannot be asked." >&2
  echo "Refusing to apply defaults unattended. Set MACBOOK_CONFIGS_ASSUME_YES=1" >&2
  echo "to accept them, or MACBOOK_CONFIGS_STRICT=1 to make evaluation itself fail." >&2
  exit 1
fi

read -r -p "Continue with these defaults? [y/N] " reply
case "$reply" in
  [yY] | [yY][eE][sS])
    exit 0
    ;;
  *)
    echo "Aborted — nothing was applied."
    exit 1
    ;;
esac
