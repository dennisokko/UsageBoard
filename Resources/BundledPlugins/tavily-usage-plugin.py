#!/usr/bin/env python3
# UsageBoardPlugin:
# {
#   "schemaVersion": 1,
#   "name": "Tavily",
#   "name@zh-Hans": "Tavily",
#   "name@en": "Tavily",
#   "icon": "https://raw.githubusercontent.com/lobehub/lobe-icons/refs/heads/master/packages/static-png/light/tavily-color.png",
#   "description": "查询 Tavily Search 月度用量",
#   "description@zh-Hans": "查询 Tavily Search 月度用量",
#   "description@en": "Query Tavily Search monthly usage",
#   "parameters": [
#     {
#       "name": "API_KEY",
#       "label": "Api Key",
#       "label@zh-Hans": "Api Key",
#       "label@en": "API Key",
#       "type": "secret",
#       "required": true,
#       "placeholder": "Tavily API Key"
#     }
#   ]
# }
# /UsageBoardPlugin
"""UsageBoard plugin for Tavily quota usage."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from calendar import monthrange
from typing import Any


ENDPOINT = "https://api.tavily.com/usage"
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


def get_api_key(argv: list[str]) -> str | None:
    return parse_usageboard_params(argv).get("API_KEY")


def get_app_language(argv: list[str]) -> str:
    return "en" if parse_usageboard_params(argv).get("USAGEBOARD_LANGUAGE") == "en" else "zh-Hans"


TRANSLATIONS = {
    "total_usage": {
        "zh-Hans": "总用量",
        "en": "Total usage",
    },
    "search": {
        "zh-Hans": "搜索",
        "en": "Search",
    },
    "crawl": {
        "zh-Hans": "爬取",
        "en": "Crawl",
    },
    "extract": {
        "zh-Hans": "提取",
        "en": "Extract",
    },
    "map": {
        "zh-Hans": "地图",
        "en": "Map",
    },
    "research": {
        "zh-Hans": "研究",
        "en": "Research",
    },
    "query_failed_prefix": {
        "zh-Hans": "Tavily 查询失败：",
        "en": "Tavily query failed: ",
    },
    "missing_api_key": {
        "zh-Hans": "请在插件设置中配置 Api Key",
        "en": "Configure Api Key in plugin settings",
    },
    "no_quota_items": {
        "zh-Hans": "响应中没有可识别的配额项",
        "en": "No recognizable quota items in response",
    },
    "request_timeout": {
        "zh-Hans": "请求超时",
        "en": "Request timed out",
    },
}


def translate(language: str, key: str) -> str:
    values = TRANSLATIONS.get(key, {})
    return values.get(language) or values.get("zh-Hans") or key


def fetch_usage(api_key: str) -> dict[str, Any]:
    request = urllib.request.Request(ENDPOINT, headers={"Authorization": f"Bearer {api_key}"})
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def next_month_start_iso() -> str:
    now = datetime.now(timezone.utc)
    year = now.year + (1 if now.month == 12 else 0)
    month = (now.month % 12) + 1
    return datetime(year, month, 1, tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")


def numeric(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return 0
    return 0


def status_for(used: float, total: float) -> str:
    pct = used / total * 100 if total > 0 else 0
    if pct >= 90:
        return "critical"
    if pct >= 75:
        return "warning"
    return "normal"


def color_for(used: float, total: float) -> str:
    pct = used / total * 100 if total > 0 else 0
    if pct >= 90:
        return "red"
    if pct >= 80:
        return "orange"
    if pct >= 60:
        return "yellow"
    return "blue"


def item(item_id: str, name: str, used: float, total: float, color: str = "blue", reset_at: str | None = None) -> dict[str, Any]:
    return {
        "id": item_id,
        "name": name,
        "used": max(used, 0),
        "limit": max(total, 0),
        "displayStyle": "ratio",
        "resetAt": reset_at,
        "status": status_for(used, total),
        "color": color,
    }


def build_items(payload: dict[str, Any], language: str) -> list[dict[str, Any]]:
    account = payload.get("account", {})
    if not isinstance(account, dict):
        return []

    plan_limit = numeric(account.get("plan_limit"))
    if plan_limit <= 0:
        return []

    plan_usage = numeric(account.get("plan_usage"))
    output = [
        item(
            "tavily-total-month",
            translate(language, "total_usage"),
            plan_usage,
            plan_limit,
            color_for(plan_usage, plan_limit),
            next_month_start_iso(),
        )
    ]

    details = [
        ("tavily-search", "search", "search_usage"),
        ("tavily-crawl", "crawl", "crawl_usage"),
        ("tavily-extract", "extract", "extract_usage"),
        ("tavily-map", "map", "map_usage"),
        ("tavily-research", "research", "research_usage"),
    ]
    for item_id, name_key, usage_key in details:
        used = numeric(account.get(usage_key))
        if used > 0:
            output.append(item(item_id, translate(language, name_key), used, plan_usage))

    return output


def success(items: list[dict[str, Any]]) -> int:
    print(json.dumps({"schemaVersion": SCHEMA_VERSION, "updatedAt": utc_now_iso(), "items": items}, ensure_ascii=False))
    return 0


def failure(message: str, language: str) -> int:
    print(
        json.dumps(
            {
                "schemaVersion": SCHEMA_VERSION,
                "updatedAt": utc_now_iso(),
                "items": [
                    {
                        "id": "tavily-error",
                        "name": f"{translate(language, 'query_failed_prefix')}{message}",
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
    api_key = get_api_key(sys.argv[1:])
    language = get_app_language(sys.argv[1:])
    if not api_key:
        return failure(translate(language, "missing_api_key"), language)

    try:
        items = build_items(fetch_usage(api_key), language)
        if not items:
            return failure(translate(language, "no_quota_items"), language)
        return success(items)
    except urllib.error.HTTPError as error:
        return failure(f"HTTP {error.code}", language)
    except urllib.error.URLError as error:
        return failure(str(error.reason), language)
    except TimeoutError:
        return failure(translate(language, "request_timeout"), language)
    except Exception as error:
        return failure(str(error), language)


if __name__ == "__main__":
    sys.exit(main())
