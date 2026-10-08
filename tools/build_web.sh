#!/bin/bash
# Export the web build to build/web and add the online bridge (web/net.js).
set -e
cd "$(dirname "$0")/.."
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release Web 2>&1 | grep -E "^ERROR" && exit 1
rm -f build/web/*.import
cp web/net.js build/web/
ls build/web
