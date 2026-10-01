#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d /tmp/yoyu-structured-data.XXXXXX)
trap 'rm -rf "$work"' EXIT
source Tests/Support/sources.sh
sources=("${yoyu_sources[@]}")
swiftc -module-name YoyuPersistenceTests Tests/Fixtures/LegacyJSONModels.swift Tests/Fixtures/LegacyJSONSeed.swift -o "$work/seed"
"$work/seed" "$work/legacy.store"
swiftc -module-name YoyuPersistenceTests "${sources[@]}" Tests/StructuredDataTests.swift -o "$work/structured"
"$work/structured" "$work/legacy.store"
