"""Railway template: keep the Feishu/Lark SDK (lark_oapi, ~130 MB of RAM) out of memory
unless Feishu app credentials are configured, so the app fits a 0.5 GB service.

Upstream imports lark_oapi at startup for Feishu App Bot, Stream and Docs features and falls
back cleanly when it is missing. Feishu webhook notifications don't use it. Set
FEISHU_APP_ID (as a Railway variable or in the web UI, then restart) to load it, or set
RAILWAY_LOAD_FEISHU_SDK=true to always load it.
"""
import os
import sys


def _feishu_wanted():
    if os.environ.get("RAILWAY_LOAD_FEISHU_SDK", "").strip().lower() in ("1", "true", "yes"):
        return True
    if os.environ.get("FEISHU_APP_ID", "").strip():
        return True
    path = os.environ.get("ENV_FILE", "")
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                key, sep, value = line.partition("=")
                if sep and key.strip().removeprefix("export ").strip() == "FEISHU_APP_ID":
                    value = value.split("#", 1)[0].strip().strip("'\"")
                    if value:
                        return True
    except OSError:
        pass
    return False


class _BlockFeishuSDK:
    def find_spec(self, name, path=None, target=None):
        if name == "lark_oapi" or name.startswith("lark_oapi."):
            raise ImportError("lark_oapi not loaded: no Feishu app configured (Railway template)")
        return None


if not _feishu_wanted():
    sys.meta_path.insert(0, _BlockFeishuSDK())
