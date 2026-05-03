#!/usr/bin/env python3
# UsageBoardPlugin:
# {
#   "schemaVersion": 1,
#   "name": "Codex",
#   "icon": "https://raw.githubusercontent.com/lobehub/lobe-icons/refs/heads/master/packages/static-png/light/codex-color.png",
#   "description": "查询 OpenAI Codex CLI 用量和统计",
#   "parameters": [
#     {
#       "name": "DATA_DIR",
#       "label": "数据目录",
#       "type": "string",
#       "required": false,
#       "defaultValue": "~/.codex",
#       "placeholder": "~/.codex"
#     },
#     {
#       "name": "STAT_PERIOD",
#       "label": "统计周期",
#       "type": "choice",
#       "required": false,
#       "defaultValue": "7d",
#       "options": [
#         {"label": "7 天", "value": "7d"},
#         {"label": "30 天", "value": "30d"}
#       ]
#     }
#   ]
# }
# /UsageBoardPlugin
"""UsageBoard plugin for OpenAI Codex CLI quota usage."""

from __future__ import annotations

import glob
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, time, timedelta, timezone
from typing import Any


ENDPOINT = "https://chatgpt.com/backend-api/wham/usage"
SCHEMA_VERSION = 1


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_usageboard_params(argv: list[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    index = 0
    while index < len(argv):
        if argv[index] == "--usageboard-param" and index + 1 < len(argv):
            key_value = argv[index + 1]
            if "=" in key_value:
                key, value = key_value.split("=", 1)
                if key:
                    values[key] = value
            index += 2
        else:
            index += 1
    return values


def load_auth(data_dir: str) -> dict[str, Any] | None:
    auth_path = os.path.join(os.path.expanduser(data_dir), "auth.json")
    if not os.path.isfile(auth_path):
        return None
    try:
        with open(auth_path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def fetch_usage(access_token: str, account_id: str) -> dict[str, Any]:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
        "ChatGPT-Account-Id": account_id,
        "Origin": "https://chatgpt.com",
        "Referer": "https://chatgpt.com/",
        "User-Agent": "Mozilla/5.0",
    }
    request = urllib.request.Request(ENDPOINT, headers=headers)
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def epoch_ms_to_iso(value: Any) -> str | None:
    if value is None:
        return None
    try:
        raw = int(value)
    except (TypeError, ValueError):
        return None
    timestamp = raw / 1000 if raw > 10**11 else raw
    return datetime.fromtimestamp(timestamp, tz=timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def get_percent_left(window: dict[str, Any]) -> float | None:
    for key in ("percent_left", "remaining_percent"):
        value = window.get(key)
        if value is not None:
            try:
                return float(value)
            except (TypeError, ValueError):
                pass
    used = window.get("used_percent")
    if used is not None:
        try:
            return max(0, 100 - float(used))
        except (TypeError, ValueError):
            pass
    return None


def get_reset_at(window: dict[str, Any]) -> str | None:
    for key in ("reset_time_ms", "reset_at"):
        value = window.get(key)
        if value is not None:
            return epoch_ms_to_iso(value)
    nested = window.get("primary_window")
    if isinstance(nested, dict):
        return get_reset_at(nested)
    return None


def color_for(used_pct: float) -> str:
    if used_pct >= 90:
        return "red"
    if used_pct >= 80:
        return "orange"
    if used_pct >= 60:
        return "yellow"
    return "blue"


def stat_range(period: str) -> tuple[datetime, datetime, list[datetime], str]:
    now = datetime.now().astimezone()
    day_count = 7 if period == "7d" else 30
    today = now.date()
    start_date = today - timedelta(days=day_count - 1)
    start = datetime.combine(start_date, time.min, tzinfo=now.tzinfo)
    end = datetime.combine(today, time.max, tzinfo=now.tzinfo).replace(microsecond=0)
    buckets = [start + timedelta(days=i) for i in range(day_count)]
    return start, end, buckets, "day"


def bucket_id(dt: datetime, unit: str) -> str:
    return dt.strftime("%Y-%m-%d")


def bucket_label(dt: datetime, unit: str) -> str:
    return dt.strftime("%m-%d")


def chart_message(msg: str, period: str, buckets: list[datetime], unit: str) -> dict[str, Any]:
    return {
        "kind": "line",
        "period": period,
        "bucketUnit": unit,
        "buckets": [
            {"id": bucket_id(b, unit), "label": bucket_label(b, unit), "segments": []}
            for b in buckets
        ],
        "message": msg,
    }


_FILENAME_DATE = re.compile(r"rollout-(\d{4}-\d{2}-\d{2})T")


def parse_date_from_filename(filename: str) -> str | None:
    m = _FILENAME_DATE.search(os.path.basename(filename))
    return m.group(1) if m else None


def collect_session_files(data_dir: str, start_date, end_date) -> list[str]:
    expanded = os.path.expanduser(data_dir)
    files: list[str] = []
    for pattern in (
        os.path.join(expanded, "sessions", "**", "*.jsonl"),
        os.path.join(expanded, "archived_sessions", "*.jsonl"),
    ):
        files.extend(glob.glob(pattern, recursive=True))
    start_str = start_date.strftime("%Y-%m-%d") if isinstance(start_date, datetime) else str(start_date)
    end_str = end_date.strftime("%Y-%m-%d") if isinstance(end_date, datetime) else str(end_date)
    result: list[str] = []
    for f in files:
        file_date = parse_date_from_filename(f)
        if file_date and start_str <= file_date <= end_str:
            result.append(f)
    return result


def parse_sessions_for_chart(
    files: list[str],
    buckets: list[datetime],
    bucket_unit: str,
    period: str,
) -> dict[str, Any]:
    bucket_keys = {bucket_id(b, bucket_unit): {} for b in buckets}
    model_totals: dict[str, float] = {}

    for filepath in files:
        current_model: str | None = None
        prev_usage: dict[str, float] = {}
        try:
            with open(filepath, encoding="utf-8") as fh:
                for line in fh:
                    if '"turn_context"' not in line and '"token_count"' not in line:
                        continue
                    try:
                        event = json.loads(line)
                    except (json.JSONDecodeError, ValueError):
                        continue

                    kind = event.get("type")
                    payload = event.get("payload")
                    if not isinstance(payload, dict):
                        continue

                    if kind == "turn_context":
                        model = payload.get("model")
                        if isinstance(model, str) and model.strip():
                            current_model = model.strip()

                    if payload.get("type") == "token_count":
                        info = payload.get("info")
                        if not isinstance(info, dict):
                            continue
                        total_usage = info.get("total_token_usage")
                        if not isinstance(total_usage, dict):
                            continue
                        total_tokens = total_usage.get("total_tokens")
                        if not isinstance(total_tokens, (int, float)):
                            continue
                        total_tokens = float(total_tokens)

                        delta = max(total_tokens - prev_usage.get("total_tokens", 0), 0)
                        if not prev_usage:
                            delta = total_tokens
                        prev_usage["total_tokens"] = total_tokens

                        model = current_model or "unknown"
                        ts = payload.get("timestamp") or event.get("timestamp")
                        if ts and delta > 0:
                            try:
                                dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00")).astimezone()
                            except (ValueError, TypeError):
                                continue
                            key = bucket_id(dt, bucket_unit)
                            if key in bucket_keys:
                                bucket_keys[key][model] = bucket_keys[key].get(model, 0) + delta
                                model_totals[model] = model_totals.get(model, 0) + delta
        except (OSError, UnicodeDecodeError):
            continue

    sorted_models = [m for m, _ in sorted(model_totals.items(), key=lambda x: -x[1])]

    chart_buckets: list[dict[str, Any]] = []
    for b in buckets:
        key = bucket_id(b, bucket_unit)
        segments = [
            {"model": m, "tokens": int(bucket_keys[key].get(m, 0))}
            for m in sorted_models
            if bucket_keys[key].get(m, 0) > 0
        ]
        chart_buckets.append({"id": key, "label": bucket_label(b, bucket_unit), "segments": segments})

    message = None
    if not any(b["segments"] for b in chart_buckets):
        message = "暂无可用统计数据"

    return {"kind": "line", "period": period, "bucketUnit": bucket_unit, "buckets": chart_buckets, "message": message}


def parse_window(data: dict[str, Any], *keys: str) -> dict[str, Any] | None:
    for key in keys:
        value = data.get(key)
        if isinstance(value, dict):
            return value
    return None


def build_items(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], str | None]:
    rate_limits = parse_window(payload, "rate_limit", "rate_limits")
    if not rate_limits:
        return [], None

    badge = payload.get("plan_type")
    if not isinstance(badge, str):
        badge = None

    items: list[dict[str, Any]] = []

    five_hour = parse_window(rate_limits, "five_hour", "five_hour_limit", "five_hour_rate_limit", "primary")
    weekly = parse_window(rate_limits, "weekly", "weekly_limit", "weekly_rate_limit", "secondary")

    if not five_hour:
        five_hour = parse_window(rate_limits, "primary_window")
    if not weekly:
        weekly = parse_window(rate_limits, "secondary_window")

    if five_hour:
        pct = get_percent_left(five_hour)
        if pct is not None:
            used = 100 - pct
            items.append({
                "id": "codex-five-hour",
                "name": "5 小时用量",
                "used": round(used, 1),
                "limit": 100,
                "displayStyle": "percent",
                "resetAt": get_reset_at(five_hour),
                "status": "critical" if used >= 90 else "warning" if used >= 75 else "normal",
                "color": color_for(used),
            })

    if weekly:
        pct = get_percent_left(weekly)
        if pct is not None:
            used = 100 - pct
            items.append({
                "id": "codex-weekly",
                "name": "周用量",
                "used": round(used, 1),
                "limit": 100,
                "displayStyle": "percent",
                "resetAt": get_reset_at(weekly),
                "status": "critical" if used >= 90 else "warning" if used >= 75 else "normal",
                "color": color_for(used),
            })

    return items, badge


def success(items: list[dict[str, Any]], badge: str | None = None, chart: dict[str, Any] | None = None) -> int:
    result: dict[str, Any] = {"schemaVersion": SCHEMA_VERSION, "updatedAt": utc_now_iso(), "items": items}
    if badge:
        result["badge"] = badge
    if chart:
        result["chart"] = chart
    print(json.dumps(result, ensure_ascii=False))
    return 0


def failure(message: str) -> int:
    print(
        json.dumps(
            {
                "schemaVersion": SCHEMA_VERSION,
                "updatedAt": utc_now_iso(),
                "items": [
                    {
                        "id": "codex-error",
                        "name": f"Codex 查询失败：{message}",
                        "used": 0,
                        "limit": 1,
                        "displayStyle": "percent",
                        "resetAt": None,
                        "status": "critical",
                    }
                ],
            },
            ensure_ascii=False,
        )
    )
    return 0


def main() -> int:
    params = parse_usageboard_params(sys.argv[1:])
    data_dir = params.get("DATA_DIR", "") or "~/.codex"
    period = params.get("STAT_PERIOD", "7d").lower()
    if period not in ("7d", "30d"):
        period = "7d"

    auth = load_auth(data_dir)
    if not auth:
        return failure(f"未找到认证文件（{os.path.join(os.path.expanduser(data_dir), 'auth.json')}）")

    tokens = auth.get("tokens") if isinstance(auth.get("tokens"), dict) else {}
    access_token = tokens.get("access_token")
    account_id = tokens.get("account_id")
    if not access_token or not account_id:
        return failure("认证文件中缺少 access_token 或 account_id")

    items: list[dict[str, Any]] = []
    badge: str | None = None
    try:
        items, badge = build_items(fetch_usage(access_token, account_id))
    except urllib.error.HTTPError as error:
        if error.code == 401:
            return failure("Token 已过期，请重新登录 Codex")
        if error.code == 403:
            return failure("账号无权访问")
        return failure(f"HTTP {error.code}")
    except urllib.error.URLError as error:
        return failure(str(error.reason))
    except TimeoutError:
        return failure("请求超时")
    except Exception as error:
        return failure(str(error))

    start, end, buckets, bucket_unit = stat_range(period)
    try:
        session_files = collect_session_files(data_dir, start, end)
        chart = parse_sessions_for_chart(session_files, buckets, bucket_unit, period)
    except Exception:
        chart = chart_message("统计数据解析失败", period, buckets, bucket_unit)

    if not items:
        return failure("响应中没有可识别的配额数据")
    return success(items, badge=badge, chart=chart)


if __name__ == "__main__":
    sys.exit(main())
