#!/usr/bin/env bash
# install.sh — Install kubectl-sentinel to PATH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$SCRIPT_DIR/kubectl-sentinel"
INSTALL_DIR="${1:-/usr/local/bin}"
DEST="$INSTALL_DIR/kubectl-sentinel"

if [[ ! -f "$PLUGIN" ]]; then
  echo "Error: kubectl-sentinel not found at $PLUGIN" >&2
  exit 1
fi

# Strip CRLF line endings that Windows git may introduce, then install
if [[ -w "$INSTALL_DIR" ]]; then
  tr -d '\r' < "$PLUGIN" > "$DEST"
  chmod +x "$DEST"
else
  echo "Needs sudo to write to $INSTALL_DIR"
  tr -d '\r' < "$PLUGIN" | sudo tee "$DEST" > /dev/null
  sudo chmod +x "$DEST"
fi

echo "Installed kubectl-sentinel → $DEST"
echo ""
echo "Usage:"
echo "  kubectl sentinel                  # full cluster check"
echo "  kubectl sentinel -n <namespace>   # scoped to namespace"
echo "  kubectl sentinel pod/<name>       # pod deep-dive"
echo "  kubectl sentinel node/<name>      # node deep-dive"
echo "  kubectl sentinel --json           # JSON output"
