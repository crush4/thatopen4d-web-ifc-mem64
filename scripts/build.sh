#!/usr/bin/env bash
# Reproduzierbarer Build des Memory64-Forks von web-ifc.
# Vorgehen:
#   1. Submodule init (vendor/web-ifc auf gepinnten Tag)
#   2. Patches anwenden (3 Stueck — siehe ../patches/)
#   3. Docker-Build mit emscripten/emsdk
#   4. dist/ aus dem Container extrahieren + aufraeumen

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

IMAGE_NAME="thatopen4d-web-ifc-mem64-build"
CONTAINER_NAME="thatopen4d-web-ifc-mem64-extract"

echo "==> Submodule init"
git submodule update --init --recursive

echo "==> Patches anwenden"
cd vendor/web-ifc
# Vorherigen Patch-State zuruecksetzen (idempotent).
git checkout -- .
git clean -fd src/cpp/CMakeLists.txt src/cpp/wasm/web-ifc-wasm.cpp src/ts/web-ifc-api.ts 2>/dev/null || true

for patch in "$REPO_ROOT"/patches/*.patch; do
  echo "  - $(basename "$patch")"
  git apply "$patch"
done

echo "==> Docker-Build"
cd "$REPO_ROOT/vendor/web-ifc"
docker build -t "$IMAGE_NAME" .

echo "==> dist/ extrahieren"
cd "$REPO_ROOT"
# Alten Container wegraeumen falls vorhanden.
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
# `tail -f /dev/null` damit der Container nicht beim ENTRYPOINT ausfaellt.
MSYS_NO_PATHCONV=1 docker run -d --name "$CONTAINER_NAME" \
  --entrypoint sh "$IMAGE_NAME" -c "sleep 999"
# dist-Verzeichnis kopieren
rm -rf dist
docker cp "$CONTAINER_NAME":/web-ifc-app/dist ./dist
docker rm -f "$CONTAINER_NAME"

echo "==> dist aufraeumen (TS-Quellen + Build-Cache entfernen)"
cd "$REPO_ROOT/dist"
rm -f ifc-schema.ts web-ifc-api.ts tsconfig.tsbuildinfo LICENSE.md README.md package.json
rm -f helpers/*.ts
cd "$REPO_ROOT"

echo ""
echo "Build fertig. dist-Inhalt:"
ls -lh dist/

echo ""
echo "Naechste Schritte:"
echo "  - dist/ committen"
echo "  - package.json version bump (z.B. 0.0.77-mem64.2)"
echo "  - git tag v0.0.77-mem64.2 + push"
