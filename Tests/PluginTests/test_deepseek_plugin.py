"""Tests for deepseek-usage-plugin.py — run with: python3 -m pytest Tests/PluginTests/test_deepseek_plugin.py"""

import importlib.util
import json
import sys
import unittest
from io import StringIO
from pathlib import Path
from unittest.mock import patch

PLUGIN_PATH = Path(__file__).parent.parent.parent / "Resources" / "BundledPlugins" / "deepseek-usage-plugin.py"


def load_plugin():
    spec = importlib.util.spec_from_file_location("deepseek_plugin", PLUGIN_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


plugin = load_plugin()

FAKE_BALANCE_RESPONSE = {"balance_infos": [{"currency": "CNY", "total_balance": "50.0"}]}


def run_main(argv_extra=None):
    """Run plugin main() with given argv, return parsed stdout JSON."""
    argv = ["deepseek-usage-plugin.py"] + (argv_extra or [])
    with patch("sys.argv", argv):
        with patch("sys.stdout", new_callable=StringIO) as mock_out:
            try:
                plugin.main()
            except SystemExit:
                pass
            return json.loads(mock_out.getvalue())


class TestErrorFormat(unittest.TestCase):
    """Error output must use {"error": "message"} format with no items."""

    def test_missing_api_key_outputs_error_field_not_items(self):
        output = run_main([])
        self.assertIn("error", output)
        self.assertNotIn("items", output)

    def test_missing_api_key_exits_zero(self):
        with patch("sys.argv", ["deepseek-usage-plugin.py"]):
            with patch("sys.stdout", new_callable=StringIO):
                try:
                    plugin.main()
                    exit_code = 0
                except SystemExit as e:
                    exit_code = e.code or 0
        self.assertEqual(exit_code, 0)


class TestSchemaVersion(unittest.TestCase):
    """Success output must include schemaVersion."""

    def test_success_output_has_schema_version(self):
        fake_items = [{"id": "balance-CNY", "name": "余额", "used": 50.0, "limit": 50.0, "displayStyle": "ratio", "status": "normal", "color": None}]
        argv = ["deepseek-usage-plugin.py", "--usageboard-param", "API_KEY=fake"]
        with patch("sys.argv", argv):
            with patch.object(plugin, "fetch_balance", return_value=fake_items):
                with patch("sys.stdout", new_callable=StringIO) as mock_out:
                    try:
                        plugin.main()
                    except SystemExit:
                        pass
                    output = json.loads(mock_out.getvalue())
        self.assertIn("schemaVersion", output)


if __name__ == "__main__":
    unittest.main()
