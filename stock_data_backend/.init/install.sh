#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/stock-growth-analyzer-221696-230050/stock_data_backend"
cd "$WORKSPACE"
VENV="$WORKSPACE/.venv"
# create venv if missing
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV" || { echo "venv creation failed" >&2; exit 5; }
fi
V_PY="$VENV/bin/python"
V_PIP="$VENV/bin/pip"
# verify venv python works, recreate if broken
if ! "$V_PY" -c 'import sys; print("ok")' >/dev/null 2>&1; then
  rm -rf "$VENV" && python3 -m venv "$VENV" || { echo "venv recreate failed" >&2; exit 6; }
fi
# Ensure pip exists
$V_PIP --version >/dev/null 2>&1 || { echo "venv pip missing" >&2; exit 7; }
# Ensure venv python >=3.8
V_PY_VER=$($V_PY -c 'import sys; print("%d.%d" % sys.version_info[:2])')
if [ "${V_PY_VER%%.*}" -lt 3 ] || { [ "${V_PY_VER%%.*}" -eq 3 ] && [ "${V_PY_VER##*.}" -lt 8 ]; }; then
  echo "venv python must be >=3.8, found $V_PY_VER" >&2
  exit 8
fi
# Upgrade packaging tooling inside venv
$V_PY -m pip install --upgrade pip setuptools wheel --disable-pip-version-check --quiet || { echo "upgrade pip/setuptools/wheel failed" >&2; $V_PIP --version; exit 9; }
# Packages to install (pinned minor versions to match plan)
PKGS=("fastapi~=0.100.0" "httpx~=0.24.0" "SQLAlchemy~=2.0" "uvicorn~=0.22.0" "pytest~=7.0" "pytest-asyncio~=0.22.0")
# pip install with simple retry (up to 2 retries) to mitigate transient PyPI/network issues
RETRIES=2
COUNT=0
until [ "$COUNT" -gt "$RETRIES" ]; do
  "$V_PY" -m pip install --disable-pip-version-check --progress-bar=off "${PKGS[@]}" && break || {
    COUNT=$((COUNT+1))
    echo "pip install attempt $COUNT failed" >&2
    sleep $((COUNT*2))
    if [ "$COUNT" -gt "$RETRIES" ]; then
      echo "pip install failed after retries" >&2
      "$V_PIP" list --format=columns || true
      exit 10
    fi
  }
done
# Record global uvicorn presence and which uvicorn will be used
if command -v uvicorn >/dev/null 2>&1; then
  GLOBAL_UVICORN_VER=$(uvicorn --version 2>/dev/null || true)
  echo "global_uvicorn_version=$GLOBAL_UVICORN_VER" > "$WORKSPACE/.uvicorn_info" || true
fi
# By design we use the venv-installed uvicorn for start/validation to ensure isolation
echo "using_uvicorn=venv" >> "$WORKSPACE/.uvicorn_info" || true
# Verify critical imports inside venv python
$V_PY - <<'PY'
import sys
try:
    import fastapi, httpx, sqlalchemy, pydantic, sqlite3
except Exception as e:
    print('import check failed:', e, file=sys.stderr)
    sys.exit(11)
print('imports ok')
PY
# write requirements-dev.txt
$V_PIP freeze > "$WORKSPACE/requirements-dev.txt"
