#!/bin/bash
# Launch the native VoiceLive Play Workbench app.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/VoiceLive Play Workbench.app"

if [[ ! -d "$APP" ]]; then
  echo "VoiceLive Play Workbench.app was not found in $ROOT"
  exit 1
fi

open "$APP"
