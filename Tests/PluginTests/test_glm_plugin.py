"""Tests for glm-usage-plugin.py — run with: python3 -m pytest Tests/PluginTests/test_glm_plugin.py"""

import importlib.util
import sys
import unittest
from pathlib import Path

PLUGIN_PATH = Path(__file__).parent.parent.parent / "Resources" / "BundledPlugins" / "glm-usage-plugin.py"


def load_plugin():
    plugin_dir = str(PLUGIN_PATH.parent)
    if plugin_dir not in sys.path:
        sys.path.insert(0, plugin_dir)
    spec = importlib.util.spec_from_file_location("glm_plugin", PLUGIN_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


plugin = load_plugin()


class TestQuotaKind(unittest.TestCase):
    def test_current_value_shape_is_tool_usage(self):
        kind, label = plugin.quota_kind({"currentValue": 10, "usage": 100}, "en")

        self.assertEqual(kind, "tool")
        self.assertEqual(label, "Tool calls")

    def test_named_token_shape_is_text_usage(self):
        kind, label = plugin.quota_kind({"name": "Token quota"}, "en")

        self.assertEqual(kind, "text")
        self.assertEqual(label, "Text generation")

    def test_unrelated_marker_field_does_not_drive_classification(self):
        kind, label = plugin.quota_kind({"note": "tool migration note"}, "en")

        self.assertEqual(kind, "text")
        self.assertEqual(label, "Text generation")


if __name__ == "__main__":
    unittest.main()
