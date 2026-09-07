import json
import os
import sys
import time
from pathlib import Path

Path(os.environ["CODESNAP_TEST_HELPER"]).write_text(json.dumps({
    "pid": os.getpid(),
    "input_path": os.readlink("/proc/self/fd/0"),
}))
mode = os.environ["CODESNAP_TEST_MODE"]
if mode == "provider-slow":
    time.sleep(30)
if mode == "provider-fail":
    sys.exit(4)

data = sys.stdin.buffer.read()
try:
    config = json.loads(data)
except (UnicodeDecodeError, json.JSONDecodeError):
    config = None
Path(os.environ["CODESNAP_TEST_OUTPUT"]).write_text(json.dumps({
    "operation": "copy" if "image/png" in sys.argv else "copy_ascii",
    "config": config,
    "arguments": sys.argv[1:],
    "input_path": os.readlink("/proc/self/fd/0"),
    "data_hex": data.hex(),
}))

if mode == "owner":
    child = os.fork()
    if child:
        Path(os.environ["CODESNAP_TEST_OWNER"]).write_text(str(child))
    else:
        # Like wl-copy, deliberately retain stderr in the daemon
        # It must be /dev/null rather than a pipe the Neovim parent waits for
        time.sleep(30)
