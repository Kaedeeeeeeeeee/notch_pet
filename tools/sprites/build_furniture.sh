#!/usr/bin/env bash
# Regenerate NotchPet/Assets/Sprites/furniture.{png,json} from the Lua generator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

ASEPRITE="./tools/aseprite/build/bin/aseprite"
if [ ! -x "$ASEPRITE" ]; then
    echo "aseprite binary not found at $ASEPRITE" >&2
    exit 1
fi

mkdir -p NotchPet/Assets/Sprites

"$ASEPRITE" -b --script tools/sprites/gen_furniture.lua

"$ASEPRITE" -b tools/sprites/furniture.aseprite \
    --sheet-type packed \
    --sheet NotchPet/Assets/Sprites/furniture.png \
    --data NotchPet/Assets/Sprites/furniture.json \
    --list-tags \
    --format json-array

echo "Sheet: $(ls -lh NotchPet/Assets/Sprites/furniture.png | awk '{print $5}')"
echo "JSON : $(ls -lh NotchPet/Assets/Sprites/furniture.json | awk '{print $5}')"
