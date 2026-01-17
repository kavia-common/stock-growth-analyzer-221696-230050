#!/usr/bin/env bash
set -euo pipefail
# Run pytest async test against in-memory FastAPI app using workspace venv pytest
WORKSPACE="/home/kavia/workspace/code-generation/stock-growth-analyzer-221696-230050/stock_data_backend"
cd "$WORKSPACE"
VENV_PYTEST="$WORKSPACE/.venv/bin/pytest"
if [ ! -x "$VENV_PYTEST" ]; then echo "pytest not found in venv" >&2; exit 13; fi
# create pytest.ini to silence marker warnings and set asyncio mode
cat > "$WORKSPACE/pytest.ini" <<'INI'
[pytest]
asyncio_mode = auto
INI
# create async test file
cat > "$WORKSPACE/test_health.py" <<'PY'
import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_health_endpoint():
    async with AsyncClient(app=app, base_url='http://test') as ac:
        r = await ac.get('/health')
        assert r.status_code == 200
        assert r.json() == {'status': 'ok'}
PY
# run pytest explicitly from venv
"$VENV_PYTEST" -q "$WORKSPACE/test_health.py" || { echo "tests failed" >&2; exit 14; }
exit 0
