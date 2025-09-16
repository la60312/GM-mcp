# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# (Optional, but useful for TLS root certs)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install OpenAPI→MCP server and stdio↔SSE bridge
RUN pip install --no-cache-dir awslabs.openapi-mcp-server mcp-proxy

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Default SSE port
EXPOSE 18080

# Sensible defaults (override via env or .env)
ENV API_NAME="gestaltmatcher" \
    MCP_PROXY_PORT="18080" \
    MCP_PROXY_ALLOW_ORIGIN="*"

CMD ["/app/entrypoint.sh"]
