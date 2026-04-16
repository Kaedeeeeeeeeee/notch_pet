#!/usr/bin/env bash
# Regenerate NotchPet/Assets/Sprites/pet.{png,json} from the Lua generator.
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

mkdir -p NotchPet/Assets/Sprites

"$ASEPRITE" -b --script tools/sprites/gen_pet.lua

"$ASEPRITE" -b tools/sprites/pet.aseprite \
    --sheet-type packed \
    --sheet NotchPet/Assets/Sprites/pet.png \
    --data NotchPet/Assets/Sprites/pet.json \
    --list-tags \
    --format json-array

echo "Sheet: $(ls -lh NotchPet/Assets/Sprites/pet.png | awk '{print $5}')"
echo "JSON : $(ls -lh NotchPet/Assets/Sprites/pet.json | awk '{print $5}')"
