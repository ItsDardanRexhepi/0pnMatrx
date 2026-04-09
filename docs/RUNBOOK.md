# 0pnMatrx Operations Runbook

This runbook covers the on-call playbook for the 0pnMatrx gateway:
healthy state, common failure modes, and recovery steps. Treat it as the
starting point — the source of truth for behaviour is the code under
`runtime/`, `gateway/`, and `hivemind/`.

## Service overview

The gateway process is a single aiohttp server (see `gateway/server.py`)
that exposes:

- `GET  /health` — liveness probe (no auth)
- `GET  /metrics` — JSON metrics snapshot
- `GET  /metrics/prom` — Prometheus text exposition format
- `POST /chat`, `POST /chat/stream`, `GET /ws` — chat surfaces
- `POST /memory/read`, `POST /memory/write`
- `POST /auth/nonce`, `POST /auth/verify` — SIWE auth handshake

State that survives a restart:

- `data/0pnmatrx.db` — SQLite database (memory, sessions, nonces, turns)
- `data/backups/` — daily SQLite snapshots (retention configurable,
  default 7)
- `memory/` — legacy on-disk JSON snapshots (still read for migration)

## Healthy steady state

`GET /health` returns `{"status":"ok"}` within ~50ms. The Prometheus
endpoint reports `opnmatrx_uptime_seconds` increasing monotonically and
`opnmatrx_requests_total{...}` ticking up under load. The backup loop
emits `Database backup written to ...` once per `backup.interval`
(default 24h). The cleanup loop runs every 5 minutes and reports
`caches.evicted` when oracle/service caches drop expired entries.

## Common incidents

### Gateway is unreachable

1. Check the process is alive: `docker ps` or `systemctl status
   opnmatrx-gateway`.
2. Check `GET /health` from the host: `curl -fsS http://localhost:18790/health`.
3. Tail logs for the most recent stack trace.
4. If the process is up but `/health` hangs, the event loop is wedged —
   restart the container. Conversation state is in SQLite so a restart
   does not lose history.

### Database is locked / corrupt

Symptoms: `sqlite3.OperationalError: database is locked` or
`malformed database schema` in the logs.

1. **Stop the gateway** so nothing is writing to the database.
2. List available backups:

   ```bash
   ls -1t data/backups/
   ```

3. Restore from the most recent good snapshot. From a Python shell with
   the venv active:

   ```python
   import asyncio, json
   from runtime.db.database import Database
   from runtime.db.backup import BackupManager

   cfg = json.load(open("openmatrix.config.json"))
   db = Database(cfg)
   mgr = BackupManager(db, backup_dir=cfg["backup"]["dir"])

   async def main():
       restored = await mgr.restore_latest()
       print("Restored from", restored)
       print("Schema version:", db.schema_version)
       await db.close()

   asyncio.run(main())
   ```

   To restore from a specific snapshot, use
   `await mgr.restore_from("data/backups/0pnmatrx-20260108T013000000000Z.db")`.

4. Start the gateway again and confirm `GET /health` is green.

`Database.restore_from` closes the live connection, atomically swaps the
database file (via a `*.restoring` temp file + `os.replace`), reopens
the connection with the same PRAGMAs, and re-runs migrations so the
restored snapshot is brought up to the current schema version.

### Oracle / service caches growing without bound

The cleanup loop calls `dispatcher.prune_caches(grace_seconds=300)`
every 5 minutes. If `metrics["caches.evicted"]` is climbing but RSS is
still growing, look for a service that does not implement
`prune_caches` — the prune walks the registry duck-typed.

### Rate limiter is shedding legitimate traffic

`/metrics` reports `requests.rate_limited`. To raise the limits without
a restart, edit `gateway.rate_limit_rpm_authenticated` in
`openmatrix.config.json` and reload the process. Tests for rate
limiting live in `tests/test_gateway.py::TestRateLimiting`.

### Backup loop is failing

`Backup loop iteration failed: ...` in the logs. Verify
`data/backups/` is writable and that the disk is not full. The next
iteration runs after `backup.interval` — to take an immediate snapshot,
exec into the container and call `await mgr.create_backup()` from the
same shell sketched above.

## Database migrations

All schema is owned by the ordered list `MIGRATIONS` in
`runtime/db/database.py`. Each entry is
`(version, description, [sql_statements])`. The applied set lives in
the `schema_version` table. Rules:

- Never edit a released migration. Append a new one with the next
  integer version.
- Statements within a migration run inside `BEGIN IMMEDIATE` so a
  partial failure rolls back and the version row is never recorded.
- `Database.schema_version` reports the highest applied version.

## Deploys

Production builds use the `Dockerfile` multi-stage build. CI builds the
image, runs the test suite with coverage, and a smoke test job boots
the container and curls `/health` before the change can land on
`main`. See `.github/workflows/ci.yml`.

## Backups configuration

Defaults (override in `openmatrix.config.json` under `backup`):

| Key                  | Default                | Notes                              |
|----------------------|------------------------|------------------------------------|
| `enabled`            | `true`                 | Set false in dev to disable.       |
| `dir`                | `data/backups`         | Created on startup.                |
| `retention`          | `7`                    | Daily snapshots kept.              |
| `interval_seconds`   | `86400` (24h)          | First snapshot is one full period. |

## Useful commands

```bash
# Tail structured logs
docker logs -f opnmatrx-gateway

# Hit the metrics endpoint
curl -fsS http://localhost:18790/metrics | jq .

# Prometheus scrape format
curl -fsS http://localhost:18790/metrics/prom

# Run the full test suite locally
pytest tests/ -v --cov=runtime --cov=gateway --cov=hivemind
```
