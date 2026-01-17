#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/stock-growth-analyzer-221696-230050/stock_data_backend"
mkdir -p "$WORKSPACE"
MAIN="$WORKSPACE/main.py"
if [ ! -f "$MAIN" ]; then
  cat > "$MAIN" <<'PY'
from fastapi import FastAPI

app = FastAPI()

@app.get('/health')
async def health():
    return {'status': 'ok'}
PY
fi
# create start script referencing canonical WORKSPACE and venv python (uses module-level app)
START="$WORKSPACE/start.sh"
cat > "$START" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/stock-growth-analyzer-221696-230050/stock_data_backend"
VENV_PY="$WORKSPACE/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
  exec "$VENV_PY" -m uvicorn main:app --host 0.0.0.0 --port 8000
else
  exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
fi
SH
chmod +x "$START"
[ -f "$MAIN" ] || { echo "main.py missing after scaffold" >&2; exit 12; }
exit 0
