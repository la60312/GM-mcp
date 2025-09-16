#!/usr/bin/env bash
set -euo pipefail

# Required env
: "${GM_API_BASE_URL:?Set GM_API_BASE_URL (e.g., http://host.docker.internal:5001)}"
: "${GM_API_USERNAME:?Set GM_API_USERNAME}"
: "${GM_API_PASSWORD:?Set GM_API_PASSWORD}"

# Where the FastAPI spec lives (default: /openapi.json)
API_SPEC_URL="${API_SPEC_URL:-${GM_API_BASE_URL%/}/openapi.json}"

exec mcp-proxy \
  --host 0.0.0.0 \
  --port "${MCP_PROXY_PORT:-18080}" \
  --allow-origin "${MCP_PROXY_ALLOW_ORIGIN:-*}" \
  -- \
  awslabs.openapi-mcp-server \
    --api-name "${API_NAME:-gestaltmatcher}" \
    --api-url  "${GM_API_BASE_URL}" \
    --spec-url "${API_SPEC_URL}" \
    --auth-type basic \
    --auth-username "${GM_API_USERNAME}" \
    --auth-password "${GM_API_PASSWORD}" \
    --log-level "${LOG_LEVEL:-INFO}"
