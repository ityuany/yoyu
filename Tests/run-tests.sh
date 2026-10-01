#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source Tests/Support/sources.sh
work=$(mktemp -d /tmp/yoyu-tests.XXXXXX)
trap 'rm -rf "$work"' EXIT
# 编译一次共享实现，各测试通过 testable import 访问内部类型。
swiftc -emit-library -emit-module -enable-testing -module-name YoyuTestSupport \
  "${yoyu_sources[@]}" -emit-module-path "$work/YoyuTestSupport.swiftmodule" \
  -o "$work/libYoyuTestSupport.dylib"
if [[ "$#" -gt 0 ]]; then
  tests=("$@")
else
  tests=()
  for file in Tests/*Tests.swift; do
    name=$(basename "$file" Tests.swift)
    case "$name" in StructuredData|RunwayPerformance) continue ;; esac
    tests+=("$name")
  done
fi
for name in "${tests[@]}"; do
  if [[ ! "$name" =~ ^[A-Za-z]+$ || ! -f "Tests/${name}Tests.swift" ]]; then
    echo "未知测试：$name" >&2; exit 1
  fi
  if [[ "$name" == StructuredData ]]; then
    Tests/run-structured-data.sh; continue
  fi
  { echo '@testable import YoyuTestSupport'; cat "Tests/${name}Tests.swift"; } > "$work/${name}Tests.swift"
  inputs=("$work/${name}Tests.swift")
  case "$name" in
    RunwaySession|RunwayParity|RunwayPerformance)
      for fixture in RunwayBaselineEngine RunwayPerformanceFixture; do
        { echo '@testable import YoyuTestSupport'; cat "Tests/Fixtures/${fixture}.swift"; } > "$work/${fixture}.swift"
        inputs+=("$work/${fixture}.swift")
      done ;;
  esac
  swiftc -parse-as-library -I "$work" -L "$work" -lYoyuTestSupport \
    -Xlinker -rpath -Xlinker "$work" "${inputs[@]}" -o "$work/$name"
  "$work/$name"
done
# 默认完整验证包含真实旧数据库升级；选择单组时按用户传入名单执行。
if [[ "$#" -eq 0 ]]; then Tests/run-structured-data.sh; fi
