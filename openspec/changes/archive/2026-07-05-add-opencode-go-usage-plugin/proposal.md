## Why

UsageBoard 目前支持 Claude、Codex、DeepSeek、Tavily、GLM、MiniMax 等 AI 工具的用量查询，但缺少对 OpenCode Go 订阅的支持。OpenCode 是一个流行的开源 AI 编码 CLI 工具，其 Go 订阅计划 ($10/月) 提供多款开源模型的用量配额（5 小时滚动/每周/每月），用户需要在仪表盘查看使用情况。添加此插件可以让用户在 UsageBoard 中统一查看 OpenCode Go 的用量。

## What Changes

- 新增 `Resources/BundledPlugins/opencode-usage-plugin.py` - OpenCode Go 订阅用量查询插件
- 插件功能：
  - 通过 Dashboard 抓取获取 rolling、weekly、monthly 三个时间窗口的用量百分比
  - 显示每个窗口的到期重置时间
  - 根据用量百分比显示颜色和状态（正常/警告/危险）
  - 显示 "Go" badge
  - 可选读取本地数据目录生成 token 用量图表
- 新增 `openspec/specs/opencode-go-usage/spec.md` - 插件功能规格文档

## Capabilities

### New Capabilities
- `opencode-go-usage`: OpenCode Go 订阅用量查询，包括 rolling/weekly/monthly 三个窗口的用量百分比、重置时间、颜色状态，以及本地 token 用量统计图表

### Modified Capabilities

无

## Impact

- 新建文件 `Resources/BundledPlugins/opencode-usage-plugin.py`
- 新建规格文档 `openspec/specs/opencode-go-usage/spec.md`
- 无需修改现有文件
- 依赖 `_common.py` 中的共享工具函数
