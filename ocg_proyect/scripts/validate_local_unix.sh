#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FUNCTIONS_DIR="$PROJECT_ROOT/functions"

step() {
  printf '\n==================================================\n'
  printf '%s\n' "$1"
  printf '==================================================\n'
}

cd "$PROJECT_ROOT"

echo "Kit local de validación OCG (Linux/macOS)"
echo "Este script NO despliega, NO configura credenciales y NO borra archivos."
echo "El build APK requiere Android SDK correctamente instalado."

step "1) Flutter version"
flutter --version

step "2) Flutter doctor -v"
flutter doctor -v

step "3) Flutter pub get"
flutter pub get

step "4) Flutter analyze"
flutter analyze

step "5) Flutter test"
flutter test

step "6) Flutter build apk --debug (si hay Android SDK)"
if command -v flutter >/dev/null 2>&1 && flutter doctor -v 2>/dev/null | grep -q "Android toolchain"; then
  flutter build apk --debug
else
  echo "Android SDK / Android toolchain no detectado. Se omite build APK en esta máquina."
fi

cd "$FUNCTIONS_DIR"

step "7) npm ci (functions)"
npm ci

step "8) npm run build (functions)"
npm run build

step "9) node --test test/*.test.mjs (functions)"
node --test test/*.test.mjs

echo
echo "Validación local completada correctamente."
echo "Recuerda consolidar la evidencia en docs/checklists/EVIDENCIA_VALIDACION_HUMANA.md"
