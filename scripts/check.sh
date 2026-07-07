#!/usr/bin/env bash
# Format + lint + typecheck gates for Rayfield Gen2. Same checks CI runs.
# Regenerates the selene roblox std, the rojo sourcemap, and the roblox type
# defs on demand, so a clean checkout can run this straight after `rokit install`.
#
# PowerShell users: run `bash scripts/check.sh` (Git Bash ships with Rojo/Rokit setups).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> stylua (format check)"
stylua --check src

echo "==> selene (lint)"
[ -f roblox.yml ] || selene generate-roblox-std
selene src

echo "==> luau-lsp (typecheck)"
rojo sourcemap default.project.json -o sourcemap.json
if [ ! -f globalTypes.d.luau ]; then
    curl -fsSL -o globalTypes.d.luau \
        "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
fi
luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau --no-strict-dm-types src

echo "==> all checks passed"
