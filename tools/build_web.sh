#!/bin/bash
# Export the web build to build/web and add the online bridge (web/net.js)
# and the controller fix-up (web/gamepad.js). The game files are named after
# the build (game-<commit>.*) with a small index.html that opens them, so a
# browser can never mix an old cached game with a new page.
set -e
cd "$(dirname "$0")/.."
B=$(git rev-parse --short HEAD)$(git diff --quiet HEAD -- . ':!data/build.txt' || echo "+")
echo "$B $(date -u +%Y-%m-%d)" > data/build.txt
rm -rf build/web && mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release Web "build/web/game-${B%+}.html" 2>&1 | grep -E "^ERROR" && exit 1
rm -f build/web/*.import
cp web/net.js web/gamepad.js build/web/
cat > build/web/index.html <<HTML
<!doctype html><meta charset="utf-8"><title>Hamlet Kart</title>
<meta http-equiv="refresh" content="0; url=game-${B%+}.html">
<a href="game-${B%+}.html">Play Hamlet Kart</a>
HTML
ls build/web
