#!/usr/bin/env python3
# UsageBoardPlugin:
# {
#   "name": "OpenCode Go",
#   "name@zh-Hans": "OpenCode Go",
#   "name@en": "OpenCode Go",
#   "icon": "https://opencode.ai/favicon-96x96-v3.png",
#   "description": "查询 OpenCode Go 订阅用量和 token 统计",
#   "description@zh-Hans": "查询 OpenCode Go 订阅用量和 token 统计",
#   "description@en": "Query OpenCode Go subscription usage and token stats",
#   "parameters": [
#     {
#       "name": "WORKSPACE_ID",
#       "label": "Workspace ID",
#       "label@zh-Hans": "Workspace ID",
#       "label@en": "Workspace ID",
#       "type": "string",
#       "required": true,
#       "placeholder": "wrk_xxx"
#     },
#     {
#       "name": "AUTH_COOKIE",
#       "label": "Auth Cookie",
#       "label@zh-Hans": "Auth Cookie",
#       "label@en": "Auth Cookie",
#       "type": "secret",
#       "required": true,
#       "placeholder": "Fe26.2**..."
#     },
#     {
#       "name": "DATA_DIR",
#       "label": "Data Directory",
#       "label@zh-Hans": "数据目录",
#       "label@en": "Data Directory",
#       "type": "directory",
#       "required": false,
#       "defaultValue": "~/.local/share/opencode",
#       "placeholder": "~/.local/share/opencode"
#     },
#     {
#       "name": "ENABLE_STATS",
#       "label": "Statistics",
#       "label@zh-Hans": "统计",
#       "label@en": "Statistics",
#       "type": "boolean",
#       "required": false,
#       "defaultValue": "true"
#     },
#     {
#       "name": "STAT_PERIOD",
#       "label": "Stats Period",
#       "label@zh-Hans": "统计周期",
#       "label@en": "Stats Period",
#       "type": "choice",
#       "required": false,
#       "defaultValue": "7d",
#       "options": [
#         {"label": "7 days",  "label@zh-Hans": "7 天",  "label@en": "7 days",  "value": "7d"},
#         {"label": "15 days", "label@zh-Hans": "15 天", "label@en": "15 days", "value": "15d"},
#         {"label": "30 days", "label@zh-Hans": "30 天", "label@en": "30 days", "value": "30d"}
#       ]
#     }
#   ]
# }
# /UsageBoardPlugin
"""UsageBoard plugin for OpenCode Go subscription usage."""

from __future__ import annotations

import glob
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import (  # noqa: E402
    app_language,
    color_for_pct,
    failure,
    handle_http_error,
    handle_url_error,
    make_translator,
    parse_usageboard_params,
    status_for as common_status_for,
    success,
    utc_now_iso,
)

# ─── Constants ────────────────────────────────────────────────────────────────

DASHBOARD_URL = "https://opencode.ai/workspace/{workspace_id}/go"
CACHE_VERSION = 1
CACHE_FILENAME = ".usageboard-opencode-chart.json"

REQUEST_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
}

TRANSLATIONS = {
    "rolling_usage":    {"zh-Hans": "5 小时用量",     "en": "5-hour usage"},
    "weekly_usage":     {"zh-Hans": "周用量",         "en": "Weekly usage"},
    "monthly_usage":    {"zh-Hans": "月用量",         "en": "Monthly usage"},
    "missing_workspace_id": {"zh-Hans": "请在插件设置中配置 Workspace ID",  "en": "Configure Workspace ID in plugin settings"},
    "missing_auth_cookie":  {"zh-Hans": "请在插件设置中配置 Auth Cookie",   "en": "Configure Auth Cookie in plugin settings"},
    "cookie_expired":   {"zh-Hans": "Auth Cookie 已过期，请重新在 opencode.ai 登录后获取",  "en": "Auth Cookie expired. Re-authenticate on opencode.ai."},
    "dashboard_parse_failed": {"zh-Hans": "用量面板数据解析失败，页面格式可能已变更",          "en": "Failed to parse dashboard data. The page format may have changed."},
    "no_stats_data":    {"zh-Hans": "暂无可用统计数据",                                     "en": "No stats data available."},
    "no_quota_items":   {"zh-Hans": "未获取到配额数据",                                     "en": "No quota data found."},
    "stats_parse_failed": {"zh-Hans": "统计数据解析失败",                                   "en": "Failed to parse stats data."},
}

_DASHBOARD_SCRAPE_TIMEOUT = 15

# ─── Helpers ──────────────────────────────────────────────────────────────────

def make_t(lang: str):
    return make_translator(TRANSLATIONS)(lang)


def status_for(pct: float) -> str:
    if pct >= 90:
        return "critical"
    if pct >= 75:
        return "warning"
    return "normal"


def reset_from_seconds(seconds: float) -> str | None:
    if seconds is None or seconds <= 0:
        return None
    reset_dt = datetime.now(timezone.utc) + timedelta(seconds=seconds)
    return reset_dt.replace(microsecond=0).isoformat().replace("+00:00", "Z")


# ─── Dashboard fetch ─────────────────────────────────────────────────────────

def fetch_dashboard(workspace_id: str, auth_cookie: str) -> str:
    url = DASHBOARD_URL.format(workspace_id=workspace_id)
    headers = dict(REQUEST_HEADERS)
    headers["Cookie"] = f"__session={auth_cookie}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=_DASHBOARD_SCRAPE_TIMEOUT) as resp:
        return resp.read().decode("utf-8")


# ─── Dashboard parsing (SolidJS SSR) ────────────────────────────────────────

_RE_JSON_PARSE = re.compile(
    r"""\$R\s*\[\s*0\s*\]\s*=\s*JSON\.parse\s*\(\s*'([^']+)'\s*\)""",
    re.DOTALL,
)

_RE_RAW_OBJECT = re.compile(
    r"""\$R\s*\[\s*0\s*\]\s*=\s*(\{.*?\});""",
    re.DOTALL,
)

_RE_WINDOW = re.compile(
    r"(rollingUsage|weeklyUsage|monthlyUsage)\s*:\s*\{([^}]+)\}",
)

_RE_FIELD = re.compile(r"(\w+)\s*:\s*([\d.]+)")


def _try_json_parse(html: str) -> dict[str, Any] | None:
    m = _RE_JSON_PARSE.search(html)
    if not m:
        return None
    raw = m.group(1)
    # unescape single quotes within the JSON string
    raw = raw.replace("\\'", "'")
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        return None


def _sanitize_js_object(text: str) -> str:
    """Convert a JS object literal to valid JSON by quoting keys and stripping trailing commas."""
    text = text.strip()
    # wrap unquoted keys in double quotes
    text = re.sub(r"(?<![:\w])(\w+)\s*:", r'"\1":', text)
    # remove trailing commas before closing brace
    text = re.sub(r",\s*}", "}", text)
    text = re.sub(r",\s*\]", "]", text)
    return text


def _try_raw_object(html: str) -> dict[str, Any] | None:
    m = _RE_RAW_OBJECT.search(html)
    if not m:
        return None
    sanitized = _sanitize_js_object(m.group(1))
    try:
        return json.loads(sanitized)
    except (json.JSONDecodeError, ValueError):
        return None


def _try_per_field(html: str) -> dict[str, Any] | None:
    result: dict[str, Any] = {}
    for m in _RE_WINDOW.finditer(html):
        key = m.group(1)
        body = m.group(2)
        fields: dict[str, float] = {}
        for fm in _RE_FIELD.finditer(body):
            try:
                fields[fm.group(1)] = float(fm.group(2))
            except ValueError:
                continue
        if fields:
            result[key] = fields
    return result if result else None


def parse_dashboard(html: str) -> dict[str, Any] | None:
    parsed = _try_json_parse(html)
    if parsed:
        return parsed
    parsed = _try_raw_object(html)
    if parsed:
        return parsed
    parsed = _try_per_field(html)
    if parsed:
        return parsed
    return None


# ─── Item builder ────────────────────────────────────────────────────────────

def build_items(
    data: dict[str, Any],
    language: str,
    translate: Any,
) -> list[dict[str, Any]]:
    windows = [
        ("rolling", "rolling_usage"),
        ("weekly", "weekly_usage"),
        ("monthly", "monthly_usage"),
    ]
    items: list[dict[str, Any]] = []
    for key, name_key in windows:
        usage_key = f"{key}Usage"
        window = data.get(usage_key)
        if not isinstance(window, dict):
            continue
        usage_pct = window.get("usagePercent")
        if usage_pct is None or not isinstance(usage_pct, (int, float)):
            continue
        usage_pct = float(usage_pct)
        if usage_pct < 0:
            usage_pct = 0
        reset_sec = window.get("resetInSec")
        items.append({
            "id": f"opencode-{key}",
            "name": translate(language, name_key),
            "displayStyle": "percent",
            "used": round(min(usage_pct, 100), 1),
            "limit": 100,
            "resetAt": reset_from_seconds(reset_sec) if reset_sec is not None else None,
            "color": color_for_pct(usage_pct),
            "status": status_for(usage_pct),
        })
    return items


# ─── Chart from local data directory ─────────────────────────────────────────

def all_jsonl_files(data_dir: str) -> list[str]:
    expanded = os.path.expanduser(data_dir)
    return glob.glob(os.path.join(expanded, "**", "*.jsonl"), recursive=True)


def parse_records(files: list[str]) -> list[tuple[datetime, str, dict[str, int]]]:
    records: list[tuple[datetime, str, dict[str, int]]] = []
    for filepath in files:
        try:
            with open(filepath, encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except Exception:
                        continue
                    if not isinstance(obj, dict):
                        continue
                    # Try both Claude and OpenCode-like log formats
                    usage = obj.get("usage") or obj.get("token_usage") or {}
                    if not isinstance(usage, dict):
                        usage = {}
                    inp = int(usage.get("input_tokens") or usage.get("input") or 0)
                    out = int(usage.get("output_tokens") or usage.get("output") or 0)
                    if inp + out <= 0:
                        continue
                    model = (obj.get("model") or obj.get("provider") or "unknown").strip()
                    raw_ts = obj.get("timestamp") or obj.get("created_at") or ""
                    if not raw_ts:
                        continue
                    try:
                        ts = datetime.fromisoformat(str(raw_ts).replace("Z", "+00:00"))
                    except Exception:
                        continue
                    records.append((ts, model, {"input": inp, "output": out}))
        except Exception:
            continue
    return records


def group_by_date(
    records: list[tuple[datetime, str, dict[str, int]]],
) -> dict[str, dict[str, int]]:
    result: dict[str, dict[str, int]] = {}
    for ts, model, b in records:
        day = ts.astimezone().strftime("%Y-%m-%d")
        bucket = result.setdefault(day, {})
        bucket[model] = bucket.get(model, 0) + b.get("input", 0) + b.get("output", 0)
    return result


def _cache_path(data_dir: str) -> str:
    return os.path.join(os.path.expanduser(data_dir), CACHE_FILENAME)


def _parse_date(s: str):
    return datetime.strptime(s, "%Y-%m-%d").date()


def _format_date(d) -> str:
    return d.strftime("%Y-%m-%d")


def load_chart_cache(data_dir: str) -> dict[str, Any] | None:
    path = _cache_path(data_dir)
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            data = json.load(f)
        if data.get("version") != CACHE_VERSION:
            return None
        return data
    except Exception:
        return None


def save_chart_cache(data_dir: str, cache_data: dict[str, Any]) -> None:
    path = _cache_path(data_dir)
    try:
        with open(path, "w") as f:
            json.dump(cache_data, f)
    except Exception:
        pass


def maintain_chart_cache(data_dir: str) -> dict[str, dict[str, int]]:
    today = _parse_date(_format_date(datetime.now()))
    cutoff = today - timedelta(days=29)
    cache = load_chart_cache(data_dir)
    now = datetime.now(timezone.utc)

    def full_scan_and_save():
        files = all_jsonl_files(data_dir)
        records = parse_records(files)
        by_day = group_by_date(records)
        days = {d: by_day.get(d, {}) for d in
                (_format_date(cutoff + timedelta(days=i)) for i in range(30))
                if _parse_date(d) <= today}
        save_chart_cache(data_dir, {
            "version": CACHE_VERSION,
            "last_date": _format_date(today),
            "days": days,
        })
        return days

    if cache is None:
        return full_scan_and_save()

    last_date = _parse_date(cache.get("last_date", "2000-01-01"))
    gap_days = (today - last_date).days

    if gap_days < 0 or gap_days > 30:
        return full_scan_and_save()

    scan_start = today if gap_days == 0 else last_date + timedelta(days=1)
    scan_start_ts = datetime.combine(scan_start, datetime.min.time()).replace(tzinfo=timezone.utc).timestamp()
    recent_files = [f for f in all_jsonl_files(data_dir) if os.path.getmtime(f) >= scan_start_ts]
    records = parse_records(recent_files)
    new_days = group_by_date(records)

    merged: dict[str, dict[str, int]] = {}
    for d, v in cache.get("days", {}).items():
        parsed = _parse_date(d)
        if cutoff <= parsed < scan_start:
            merged[d] = v

    day_count = (today - scan_start).days + 1
    for i in range(day_count):
        date_str = _format_date(scan_start + timedelta(days=i))
        merged[date_str] = new_days.get(date_str, {})

    save_chart_cache(data_dir, {
        "version": CACHE_VERSION,
        "last_date": _format_date(today),
        "days": merged,
    })
    return merged


def build_chart_from_cache(
    daily: dict[str, dict[str, int]],
    period: str,
    language: str,
    translate: Any,
) -> dict[str, Any]:
    day_count = {"7d": 7, "15d": 15, "30d": 30}.get(period, 7)
    today = datetime.now().date()
    date_list = [_format_date(today - timedelta(days=i)) for i in range(day_count - 1, -1, -1)]

    model_totals: dict[str, int] = {}
    for date in date_list:
        for model, tokens in daily.get(date, {}).items():
            model_totals[model] = model_totals.get(model, 0) + tokens
    sorted_models = [m for m, _ in sorted(model_totals.items(), key=lambda x: -x[1])]

    buckets: list[dict[str, Any]] = []
    for date in date_list:
        day_data = daily.get(date, {})
        segments = [
            {"model": m, "tokens": int(day_data.get(m, 0))}
            for m in sorted_models
            if day_data.get(m, 0) > 0
        ]
        buckets.append({"id": date, "label": date[5:], "segments": segments})

    message = None
    if not any(b["segments"] for b in buckets):
        message = translate(language, "no_stats_data")

    return {"kind": "line", "period": period, "bucketUnit": "day", "buckets": buckets, "message": message}


def build_chart(
    data_dir: str,
    period: str,
    language: str,
    translate: Any,
) -> dict[str, Any] | None:
    expanded = os.path.expanduser(data_dir) if data_dir else None
    if not expanded or not os.path.isdir(expanded):
        return None
    try:
        daily = maintain_chart_cache(expanded)
        return build_chart_from_cache(daily, period, language, translate)
    except Exception:
        return None  # silently skip chart on error


# ─── Main ────────────────────────────────────────────────────────────────────

def main() -> int:
    params = parse_usageboard_params(sys.argv[1:])
    language = app_language(params)
    translate = make_translator(TRANSLATIONS)

    workspace_id = params.get("WORKSPACE_ID", "").strip()
    if not workspace_id:
        return failure(translate(language, "missing_workspace_id"))

    auth_cookie = params.get("AUTH_COOKIE", "").strip()
    if not auth_cookie:
        return failure(translate(language, "missing_auth_cookie"))

    try:
        html = fetch_dashboard(workspace_id, auth_cookie)
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            return failure(translate(language, "cookie_expired"))
        return handle_http_error(error, translate, language)
    except urllib.error.URLError as error:
        return handle_url_error(error, translate, language)
    except TimeoutError:
        return failure(translate(language, "request_timeout"))
    except Exception:
        return failure(translate(language, "network_error"))

    try:
        data = parse_dashboard(html)
    except Exception:
        return failure(translate(language, "dashboard_parse_failed"))

    if data is None:
        return failure(translate(language, "dashboard_parse_failed"))

    try:
        items = build_items(data, language, translate)
    except Exception:
        return failure(translate(language, "usage_parse_failed"))

    if not items:
        return failure(translate(language, "no_quota_items"))

    chart = None
    data_dir = params.get("DATA_DIR", "") or "~/.local/share/opencode"
    enable_stats = params.get("ENABLE_STATS", "true").lower() != "false"
    period = params.get("STAT_PERIOD", "7d").lower()
    if period not in ("7d", "15d", "30d"):
        period = "7d"

    if enable_stats:
        chart = build_chart(data_dir, period, language, translate)

    return success(items, badge="Go", chart=chart)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.exit(1)
