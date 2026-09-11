#!/usr/bin/env bash
# 0pnMatrx — Cloud Agent install script.
#
# Idempotent: safe to run repeatedly and against cached / partially
# prepared state. Prepares the Python virtualenv, installs runtime and
# test dependencies, and seeds a local development config.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ── System packages ──────────────────────────────────────────────────
# The default base image ships Python 3.12 but not the venv/ensurepip
# module, and some wheels (pynacl, cffi) need a native toolchain to build.
if command -v apt-get >/dev/null 2>&1; then
  SUDO=""
  if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi
  $SUDO apt-get update -qq || true
  $SUDO apt-get install -y -qq \
    python3-venv python3-pip build-essential libssl-dev libffi-dev pkg-config || true
fi

# ── Python virtualenv ────────────────────────────────────────────────
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install --upgrade pip --quiet
pip install --quiet -r requirements.txt
# Test tooling for the pytest suite under tests/.
pip install --quiet pytest pytest-asyncio pytest-aiohttp

# ── Local development config ─────────────────────────────────────────
# The gateway requires openmatrix.config.json (gitignored — it normally
# holds secrets). Seed it from the committed example on first run and
# never overwrite an existing, possibly edited, config.
if [ ! -f "openmatrix.config.json" ]; then
  cp openmatrix.config.json.example openmatrix.config.json
fi

echo "0pnMatrx install complete."
