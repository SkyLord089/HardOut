#!/usr/bin/env bash
# Быстрая проверка проекта: компиляция всех .luau + юнит-тесты.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Проверка синтаксиса Luau =="
node tools/luau-check.mjs

echo
echo "== Юнит-тесты =="
node tools/run-tests.mjs
