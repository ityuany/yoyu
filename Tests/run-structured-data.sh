#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d /tmp/yoyu-structured-data.XXXXXX)
trap 'rm -rf "$work"' EXIT
sources=(yoyu/Models/{ProfileRules,UserProfile,Career,EquityGrant,StockHolding,Severance,Liability,RecurringExpense,ExpectedExpense,Runway,RunwaySession,StructuredDataMigration}.swift)
swiftc -module-name YoyuPersistenceTests Tests/Fixtures/LegacyJSONModels.swift Tests/Fixtures/LegacyJSONSeed.swift -o "$work/seed"
"$work/seed" "$work/legacy.store"
swiftc -module-name YoyuPersistenceTests "${sources[@]}" Tests/StructuredDataTests.swift -o "$work/structured"
"$work/structured" "$work/legacy.store"
