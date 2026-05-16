"""Tests for codex-usage-plugin.py — run with: python3 -m pytest Tests/PluginTests/test_codex_plugin.py"""

import importlib.util
import sys
import unittest
from pathlib import Path

PLUGIN_PATH = Path(__file__).parent.parent.parent / "Resources" / "BundledPlugins" / "codex-usage-plugin.py"


def load_plugin():
    plugin_dir = str(PLUGIN_PATH.parent)
    if plugin_dir not in sys.path:
        sys.path.insert(0, plugin_dir)
    spec = importlib.util.spec_from_file_location("codex_plugin", PLUGIN_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


plugin = load_plugin()


class TestAuthCredentials(unittest.TestCase):
    def test_reads_credentials_from_tokens_object(self):
        auth = {
            "tokens": {
                "access_token": "nested-token",
                "account_id": "nested-account",
            }
        }

        self.assertEqual(
            plugin.extract_auth_credentials(auth),
            ("nested-token", "nested-account"),
        )

    def test_reads_credentials_from_top_level_fields(self):
        auth = {
            "access_token": "top-token",
            "account_id": "top-account",
        }

        self.assertEqual(
            plugin.extract_auth_credentials(auth),
            ("top-token", "top-account"),
        )

    def test_falls_back_per_field_when_tokens_object_is_partial(self):
        auth = {
            "tokens": {"access_token": "nested-token"},
            "account_id": "top-account",
        }

        self.assertEqual(
            plugin.extract_auth_credentials(auth),
            ("nested-token", "top-account"),
        )

    def test_rejects_blank_credentials(self):
        auth = {
            "access_token": " ",
            "account_id": "",
        }

        self.assertEqual(plugin.extract_auth_credentials(auth), (None, None))


if __name__ == "__main__":
    unittest.main()
