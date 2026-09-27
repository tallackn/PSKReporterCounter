#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/app_store_connect.py release "$@"
