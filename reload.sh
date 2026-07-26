#!/usr/bin/env bash
# Rebuild game-3 and reopen it in Roblox Studio.
# Run from Git Bash in this repo: ./reload.sh
#
#   ./reload.sh            build, regenerate sourcemap, restart Studio
#   ./reload.sh --no-open  build only, leave Studio alone (use in a check loop)
#   ./reload.sh --check    build + analyze, never touches Studio

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_OUTPUT="$PROJECT_ROOT/Chiikawa Fighting Simulator.rbxl"

cd "$PROJECT_ROOT"

OPEN_STUDIO=1
RUN_CHECK=0
for arg in "$@"; do
    case "$arg" in
        --no-open) OPEN_STUDIO=0 ;;
        --check)   OPEN_STUDIO=0; RUN_CHECK=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

# Prefer a Rojo binary on PATH; fall back to the bundled tools/rojo.exe.
if command -v rojo >/dev/null 2>&1; then
    ROJO="rojo"
else
    ROJO="$PROJECT_ROOT/tools/rojo.exe"
    if [ ! -f "$ROJO" ]; then
        echo "Rojo not found." >&2
        echo "Install Rojo from https://rojo.space or place rojo.exe in tools/rojo.exe" >&2
        exit 1
    fi
fi

# Warn once rather than failing: the place still runs without Packages, on
# DataService's unlocked-DataStore fallback. See README "Setup" step 2.
if [ ! -d "$PROJECT_ROOT/Packages" ]; then
    echo "WARNING: Packages/ is missing - ProfileService is not installed."
    echo "         DataService will run its UNLOCKED DataStore fallback."
    echo "         Run 'wally install' before any public test."
fi

echo "Building project with $ROJO..."
"$ROJO" build default.project.json -o "$BUILD_OUTPUT"

# Keeps luau-lsp / editor autocomplete honest about the DataModel shape.
echo "Regenerating sourcemap..."
"$ROJO" sourcemap default.project.json -o "$PROJECT_ROOT/sourcemap.json"

if command -v selene >/dev/null 2>&1; then
    echo "Linting with selene..."
    selene src
fi

if [ "$RUN_CHECK" -eq 1 ]; then
    if command -v luau-lsp >/dev/null 2>&1; then
        echo "Type-checking with luau-lsp..."
        luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --no-strict-dm-types \
            $(find src -name '*.lua')
    else
        echo "luau-lsp not on PATH - skipping type check."
        echo "Get it from https://github.com/JohnnyMorganz/luau-lsp/releases"
    fi
fi

if [ "$OPEN_STUDIO" -eq 0 ]; then
    echo "Done (Studio untouched)."
    exit 0
fi

echo "Closing Roblox Studio..."
cmd //c "taskkill /F /IM RobloxStudioBeta.exe" || true

sleep 2

echo "Opening $BUILD_OUTPUT in Roblox Studio..."
cmd //c "start \"\" \"$BUILD_OUTPUT\""

echo "Done."
