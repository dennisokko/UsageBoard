## Context

UsageBoard 需要添加 OpenCode Go 订阅用量插件。OpenCode Go 是 OpenCode (https://opencode.ai) 的订阅计划，提供 $10/月的开源模型访问，包含三个用量窗口：
- 5 小时滚动窗口（$12 限额）
- 每周窗口（$30 限额）
- 每月窗口（$60 限额）

目前**没有官方用量 API**（PR #16513 未合并），需通过 Dashboard 抓取方式获取数据。

## Goals / Non-Goals

**Goals:**
- 通过 Dashboard 抓取获取 rolling/weekly/monthly 用量百分比
- 显示每个窗口的重置时间
- 颜色/状态标记用量级别
- 显示 "Go" badge
- 可选的本地 token 用量图表
- 中英文双语支持

**Non-Goals:**
- 不实现 OpenCode 的 Zen 余额查询
- 不修改现有插件或共享库
- 不实现实时推送通知

## Decisions

### Decision 1：Dashboard 抓取代替 API

**方案选择**：抓取 `https://opencode.ai/workspace/{workspaceId}/go` 页面，解析 SolidJS SSR 数据。

**备选方案**：
- ❌ **API 调用**（`/zen/go/v1/usage`）：PR 未合并，不可用
- ❌ **本地 SQLite 读取**：OpenCode 的 `opencode.db` 不包含订阅配额数据

**理由**：Dashboard 抓取是目前唯一可行的方案。`opencode-go-usage` 和 `opencode-quota` 两个已有项目都采用此方案，验证了可行性。

### Decision 2：三层 SSD SSR 解析策略

从易到难：

1. **`$R[0]=JSON.parse('...')`** — 优先尝试 JSON 解析
2. **`$R[0]={...}`** — raw JS 对象，sanitize（补引号、删尾逗号）后解析
3. **逐个字段正则** — 提取 `rollingUsage:{usagePercent,resetInSec}`

**理由**：SolidJS SSR 输出格式可能因部署版本变化，多层 fallback 增加鲁棒性。

### Decision 3：Auth Cookie 名称

使用 `__session` 作为 cookie name（Clerk 标准 session cookie 名）。

**理由**：OpenCode 使用 Clerk 做认证，`__session` 是 Clerk 的默认 session cookie 名称。这是 `opencode-go-usage` 插件使用的方案。

### Decision 4：Chart 使用本地 JSONL 扫描

参考 Claude 插件的 `maintain_cache()` 模式，扫描 DATA_DIR 下的 `.jsonl` 文件，解析 token 用量记录，构建 30 天滚动缓存。

**理由**：复用已验证的 cache 模式。如果 OpenCode 数据格式不兼容，chart 模块会静默降级。

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Dashboard HTML 结构变化导致解析失败 | 三层 fallback + 清晰的错误提示 |
| Auth Cookie 有效期短需频繁更新 | 提供明确的"如何获取 Cookie"说明 |
| 数据目录格式未知，chart 可能不可用 | Chart 模块静默降级，不影响核心功能 |
| 未来官方 API 发布后需迁移 | 插件架构支持新增 API fetch 路径而非替换 scraping |

## Migration Plan

N/A — 这是新插件，非迁移。

## Open Questions

- [ ] OpenCode 本地数据文件的确切格式是什么？需要在有 OpenCode 的环境中验证
- [ ] `__session` cookie 的过期时间是多长？
- [ ] 除了 rollingUsage/weeklyUsage/monthlyUsage，dashboard 是否还包含 total/used 美元值字段？
