#!/usr/bin/env bash
# Regenerate NotchPet/Assets/Cursors/*.png from the Lua generator.
# Run from anywhere; the script cd's to the repo root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

ASEPRITE="./tools/aseprite/build/bin/aseprite"
if [ ! -x "$ASEPRITE" ]; then
    echo "aseprite binary not found at $ASEPRITE" >&2
    exit 1
fi

mkdir -p NotchPet/Assets/Cursors

"$ASEPRITE" -b --script tools/sprites/gen_cursors.lua

for name in hand_open hand_closed hand_pet; do
    "$ASEPRITE" -b "tools/sprites/cursor_${name}.aseprite" \
        --save-as "NotchPet/Assets/Cursors/${name}.png"
    echo "Cursor: NotchPet/Assets/Cursors/${name}.png ($(ls -lh NotchPet/Assets/Cursors/${name}.png | awk '{print $5}'))"
done
