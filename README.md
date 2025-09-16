```markdown
# GestaltMatcher MCP Server

This project provides an **MCP (Model Context Protocol)** wrapper for the **GestaltMatcher REST API**.  
It uses `awslabs.openapi-mcp-server` (OpenAPI → MCP mapper) together with `mcp-proxy` to expose your FastAPI endpoints as MCP tools over **Streamable HTTP** and **SSE**.

---

## Architecture

```

\[MCP Client / Inspector]
│  (Streamable HTTP or SSE)
▼
mcp-proxy  (HTTP/SSE bridge)
│  (stdio)
▼
awslabs.openapi-mcp-server (reads FastAPI OpenAPI spec, calls GM API)
│  (HTTP + Basic Auth)
▼
GestaltMatcher API (FastAPI)

````

---

## Prerequisites

- **Docker** installed
- A running **GestaltMatcher API** container, published on your host at port **5001**. For example:
  ```bash
  docker run -p 5001:5000 --name gm-api gm-api
````

* **GM API credentials** (defined in `config.json` inside the API container). Example:

  * **Username:** `bh25`
  * **Password:** `gestaltmatcher`

> Tip: Verify your API is alive:
>
> ```bash
> curl -i http://127.0.0.1:5001/status
> curl -i http://127.0.0.1:5001/openapi.json
> ```

---

## Configuring `GM_API_BASE_URL`

The `GM_API_BASE_URL` tells the MCP server where to reach your **GestaltMatcher API**.
It depends on *where and how* the API is running:

### 🖥️ Running `gm-api` locally (Mac / Windows Docker Desktop)

If you started `gm-api` on your laptop with:

```bash
docker run -p 5001:5000 gm-api
```

then use:

```
GM_API_BASE_URL=http://host.docker.internal:5001
API_SPEC_URL=http://host.docker.internal:5001/openapi.json
```

### 🐧 Running `gm-api` locally (Linux)

On Linux, `host.docker.internal` is often unavailable. Instead use:

```
GM_API_BASE_URL=http://127.0.0.1:5001
API_SPEC_URL=http://127.0.0.1:5001/openapi.json
```

Or run the MCP container with:

```bash
--network=host
```

and keep the URL as `http://127.0.0.1:5001`.

### 🌐 Running `gm-api` on a remote server

If your API runs on another machine (say, `myserver.example.com`), then:

```
GM_API_BASE_URL=http://myserver.example.com:5001
API_SPEC_URL=http://myserver.example.com:5001/openapi.json
```

Make sure:

* Port `5001` is open on that server.
* You can `curl http://myserver.example.com:5001/status` from your MCP host.

### 🐳 Running `gm-api` inside the same Docker network as MCP

If you run both services with `docker compose` or on a shared Docker network, you can reference the container name directly:

```
GM_API_BASE_URL=http://gm-api:5000
API_SPEC_URL=http://gm-api:5000/openapi.json
```

(where `gm-api` is the container/service name and `5000` is the container’s internal port).

---

## Quickstart (Run the MCP server)

If you already have a local image named `gm-openapi-mcp` (built from this repo), run:

```bash
docker run --rm -p 18080:18080 --name gm-openapi-mcp \
  -e GM_API_BASE_URL="http://host.docker.internal:5001" \
  -e GM_API_USERNAME="bh25" \
  -e GM_API_PASSWORD="gestaltmatcher" \
  -e API_SPEC_URL="http://host.docker.internal:5001/openapi.json" \
  gm-openapi-mcp
```

This exposes the MCP server at:

* **Streamable HTTP:** [http://127.0.0.1:18080/mcp](http://127.0.0.1:18080/mcp)
* **SSE:** [http://127.0.0.1:18080/sse](http://127.0.0.1:18080/sse)

### Don’t have the `gm-openapi-mcp` image yet?

Build it from the included `Dockerfile` and `entrypoint.sh`:

```bash
# From the repo root (where the Dockerfile for the MCP proxy lives)
docker build -t gm-openapi-mcp .
```

Then run the container using the command above.

---

## Verify the MCP server is running

### SSE probe (should return `200 OK` and stay open)

```bash
curl -i -N -H "Accept: text/event-stream" http://127.0.0.1:18080/sse
```

### MCP bridge probe (Streamable HTTP)

```bash
curl -i http://127.0.0.1:18080/mcp
```

### Follow logs

```bash
docker logs -f gm-openapi-mcp
```

---

## Use MCP Inspector

Interactively explore and call the MCP tools.

1. **Launch Inspector** (Node 18+ recommended):

   ```bash
   npx @modelcontextprotocol/inspector
   ```

   This opens a UI at [http://localhost:6274](http://localhost:6274)

2. **Connect**

   * **Transport Type:** *Streamable HTTP*
   * **Server URL:** `http://127.0.0.1:18080/mcp`
   * Click **Connect**

3. **List tools**
   You should see tools generated from your FastAPI spec, e.g.:

   * `status`
   * `predict`
   * `encode`
   * `crop`

4. **Call a tool**

   * `status` requires no arguments; expect:

     ```json
     {"status": "running"}
     ```
   * `predict`, `encode`, `crop` expect a JSON object with an `img` field containing a **base64** image (PNG/JPEG).

   Generate base64 from a PNG (no newlines):

   ```bash
   IMG=$(base64 < /path/to/face.png | tr -d '\n')
   ```

   Then paste the arguments in Inspector:

   ```json
   {"img": "<paste the $IMG value here>"}
   ```

> **Tip:** In another terminal, watch your API logs to confirm real calls are happening:
>
> ```bash
> docker logs -f gm-api
> ```
>
> You should see `GET /status` or `POST /predict` requests whenever you run tools from Inspector.

---

## Test the GM API directly (optional sanity)

These calls bypass MCP and hit your API so you can compare outputs.

* **Status** (no auth):

  ```bash
  curl -i http://127.0.0.1:5001/status
  ```

* **Predict** (Basic Auth + base64 image):

  ```bash
  IMG=$(base64 < /path/to/face.png | tr -d '\n')
  curl -sS -u bh25:gestaltmatcher \
    -X POST http://127.0.0.1:5001/predict \
    -H 'Content-Type: application/json' \
    --data @<(jq -n --arg img "$IMG" '{img:$img}') | jq .
  ```

* **Crop → save to file**:

  ```bash
  curl -sS -u bh25:gestaltmatcher \
    -X POST http://127.0.0.1:5001/crop \
    -H 'Content-Type: application/json' \
    --data @<(jq -n --arg img "$IMG" '{img:$img}') \
  | jq -r '.crop' | base64 --decode > cropped.png
  ```

---

## Optional: `.env` and Docker Compose

If you prefer environment files and Compose, add a `.env`:

```dotenv
GM_API_BASE_URL=http://host.docker.internal:5001
GM_API_USERNAME=bh25
GM_API_PASSWORD=gestaltmatcher
API_SPEC_URL=http://host.docker.internal:5001/openapi.json
MCP_PROXY_PORT=18080
```

`docker-compose.yml`:

```yaml
version: "3.9"
services:
  gm-openapi-mcp:
    image: gm-openapi-mcp
    ports:
      - "${MCP_PROXY_PORT:-18080}:18080"
    env_file:
      - .env
```

Run:

```bash
docker compose up --build
```

---

## Troubleshooting

* **Port already in use (18080)**
  Either stop the old container or map a different host port:

  ```bash
  docker run --rm -p 18081:18080 ... gm-openapi-mcp
  ```

  Then connect Inspector to `http://127.0.0.1:18081/mcp`.

* **Cannot fetch tools / spec**
  Ensure the API spec is reachable:

  ```bash
  curl -i http://127.0.0.1:5001/openapi.json
  ```

  If your spec lives elsewhere, set `API_SPEC_URL` accordingly.

* **401 Unauthorized from API**
  The MCP server forwards Basic Auth using `GM_API_USERNAME` / `GM_API_PASSWORD`. These **must match** the credentials in the API’s `config.json`.

* **Face alignment error on /predict**
  Use a clear, front-facing image; try `/crop` first to confirm the face detector works.

* **Linux: host.docker.internal**
  If unavailable, use `--network=host` and `GM_API_BASE_URL="http://127.0.0.1:5001"`, or place both services on the same Docker network and use the API service name (e.g., `http://gm-api:5000`).

---

## Security Notes

* The MCP server attaches **HTTP Basic** credentials to every protected API call.
* Do not commit real credentials to the repo; prefer `.env` files ignored by `.gitignore`, or pass them via CI secrets.

---

## License

MIT (or your preferred license)

```

---

Would you like me to also add a **Quickstart TL;DR** (just 3 commands: run gm-api → run MCP → test `/status`) at the very top so new users don’t have to scroll?
```
