#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d /tmp/yoyu-runway-performance.XXXXXX)
trap 'rm -rf "$work"' EXIT
sources=(yoyu/Models/{ProfileRules,UserProfile,Career,EquityGrant,StockHolding,Severance,Liability,RecurringExpense,ExpectedExpense,Runway,RunwayCache}.swift)
fixtures=(Tests/Fixtures/RunwayBaselineEngine.swift Tests/Fixtures/RunwayPerformanceFixture.swift)
swiftc -Onone "${sources[@]}" Tests/RunwayTests.swift -o "$work/rules"
"$work/rules"
swiftc -Onone "${sources[@]}" "${fixtures[@]}" Tests/RunwayParityTests.swift -o "$work/parity"
"$work/parity"
swiftc -Onone "${sources[@]}" "${fixtures[@]}" Tests/RunwaySessionTests.swift -o "$work/session"
"$work/session"
swiftc -Onone "${sources[@]}" "${fixtures[@]}" Tests/RunwayPerformanceTests.swift -o "$work/performance"
"$work/performance"
