## 1. Plugin 基础结构和参数定义

- [x] 1.1 创建 `Resources/BundledPlugins/opencode-usage-plugin.py`，包含 shebang、编码声明、import 语句
- [x] 1.2 编写插件头部 JSON（name、icon、description、parameters 含 WORKSPACE_ID/AUTH_COOKIE/DATA_DIR/ENABLE_STATS/STAT_PERIOD）
- [x] 1.3 定义常量（Dashboard URL、Headers、Cache 版本号等）
- [x] 1.4 编写翻译字典和 translate 函数（中英文，含所有 error/user-facing 消息）

## 2. Dashboard 抓取和解析

- [x] 2.1 实现 `fetch_dashboard(workspace_id, auth_cookie)` — 带 Cookie 请求 `https://opencode.ai/workspace/{workspaceId}/go`
- [x] 2.2 实现 `parse_dashboard(html)` — 三层 fallback 解析 SolidJS SSR 数据（JSON.parse → raw object → 逐字段正则）
- [x] 2.3 实现 `build_items(data, language, translate)` — 构建三个 percent 类型 item（rolling/weekly/monthly）含 resetAt、color、status

## 3. 错误处理和 main 函数

- [x] 3.1 实现 401/403 → cookie_expired 的特定错误处理
- [x] 3.2 实现其他 HTTP 错误、网络错误、超时的错误处理
- [x] 3.3 实现 `main()` 函数：参数解析 → 认证检查 → 抓取 Dashboard → 解析数据 → 构建 items → 处理 chart → 输出结果

## 4. Chart 图表功能（可选）

- [x] 4.1 实现 JSONL 文件扫描和 token 记录解析函数
- [x] 4.2 实现 30 天缓存维护（load_cache/save_cache/maintain_cache）
- [x] 4.3 实现 `build_chart(data_dir, period, language, translate)` — 构建 token 用量折线图

## 5. 验证和测试

- [x] 5.1 用模拟的 dashboard HTML 测试三层解析逻辑
- [x] 5.2 验证完整的 fetch → parse → items 流程
- [x] 5.3 验证中英文翻译和错误消息
