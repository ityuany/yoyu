# 供独立规则测试使用的源码清单；页面与应用入口不参与编译。
yoyu_sources=()
while IFS= read -r source; do
  yoyu_sources+=("$source")
done < <(rg --files yoyu/Models yoyu/Domain yoyu/Persistence -g '*.swift' | sort)
yoyu_sources+=(yoyu/Features/Forecast/State/RunwaySession.swift)
