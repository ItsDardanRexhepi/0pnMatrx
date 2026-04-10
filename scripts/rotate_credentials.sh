#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# rotate_credentials.sh
#
# Credential rotation helper for 0pnMatrx. Prints step-by-step instructions
# for rotating all bot tokens, NeoWrite key, and Coinbase key. Generates a
# template .env.rotated file with placeholders.
#
# Usage: bash scripts/rotate_credentials.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "============================================================"
echo "  0pnMatrx Credential Rotation Guide"
echo "============================================================"
echo ""
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  This script prints step-by-step instructions and generates"
echo "  a template .env.rotated file with placeholders."
echo ""

# ---------------------------------------------------------------------------
# 1. Telegram Bot Tokens
# ---------------------------------------------------------------------------

echo "------------------------------------------------------------"
echo "  STEP 1: Rotate Telegram Bot Tokens"
echo "------------------------------------------------------------"
echo ""
echo "  You have three Telegram bots that need new tokens:"
echo "    - Trinity (conversation agent)"
echo "    - Neo (execution agent)"
echo "    - Morpheus (guidance agent)"
echo ""
echo "  For EACH bot, follow these exact steps in Telegram:"
echo ""
echo "  1. Open Telegram and search for @BotFather"
echo "  2. Send:  /revoke"
echo "  3. BotFather will show a list of your bots. Select the bot."
echo "  4. BotFather will respond with:"
echo '     "Done. Previous tokens are revoked. New token for @YourBot is:"'
echo "     followed by the new token."
echo "  5. Copy the new token (format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz)"
echo ""
echo "  Repeat for all three bots (Trinity, Neo, Morpheus)."
echo ""
echo "  IMPORTANT: Revoking a token immediately invalidates the old one."
echo "  The bot will stop working until you update the .env file and"
echo "  restart the gateway."
echo ""

# ---------------------------------------------------------------------------
# 2. NeoWrite API Key
# ---------------------------------------------------------------------------

echo "------------------------------------------------------------"
echo "  STEP 2: Rotate NeoWrite API Key"
echo "------------------------------------------------------------"
echo ""
echo "  1. Go to the NeoWrite console (your NeoWrite provider dashboard)"
echo "  2. Navigate to API Keys"
echo "  3. Revoke the current key"
echo "  4. Generate a new API key"
echo "  5. Copy the new key"
echo ""
echo "  The old key will be invalidated immediately."
echo ""

# ---------------------------------------------------------------------------
# 3. Coinbase API Key
# ---------------------------------------------------------------------------

echo "------------------------------------------------------------"
echo "  STEP 3: Rotate Coinbase API Keys"
echo "------------------------------------------------------------"
echo ""
echo "  1. Go to https://portal.cdp.coinbase.com/"
echo "  2. Navigate to API Keys in your project settings"
echo "  3. Click 'Create API Key' to generate a new key pair"
echo "  4. Copy both the API Key and API Secret"
echo "  5. Delete the old API key from the dashboard"
echo ""
echo "  NOTE: You need both the key and the secret. The secret is"
echo "  only shown once at creation time."
echo ""

# ---------------------------------------------------------------------------
# 4. Generate .env.rotated template
# ---------------------------------------------------------------------------

echo "------------------------------------------------------------"
echo "  STEP 4: Update Your Environment"
echo "------------------------------------------------------------"
echo ""

ENV_ROTATED="$PROJECT_ROOT/.env.rotated"

cat > "$ENV_ROTATED" << ENVEOF
# =============================================================================
# Rotated credentials for 0pnMatrx
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
#
# Replace each placeholder below with the new value, then:
#   1. Copy the values into your .env file
#   2. Restart the gateway: docker compose restart gateway
#   3. Delete this file: rm .env.rotated
# =============================================================================

# Telegram Bot Tokens (from @BotFather /revoke)
TELEGRAM_BOT_TOKEN_TRINITY=your_new_trinity_token
TELEGRAM_BOT_TOKEN_NEO=your_new_neo_token
TELEGRAM_BOT_TOKEN_MORPHEUS=your_new_morpheus_token

# NeoWrite API Key
NEOWRITE_API_KEY=your_new_neowrite_key

# Coinbase API Credentials (from portal.cdp.coinbase.com)
COINBASE_API_KEY=your_new_coinbase_key
COINBASE_API_SECRET=your_new_coinbase_secret
ENVEOF

echo "  Template generated at: $ENV_ROTATED"
echo ""
echo "  After filling in the new values:"
echo ""
echo "    1. Copy values into .env:"
echo "       cp .env .env.backup"
echo "       # Edit .env and replace the old values with new ones"
echo ""
echo "    2. Restart the gateway:"
echo "       docker compose restart gateway"
echo ""
echo "    3. Verify the bots are working:"
echo "       curl -sf https://openmatrix.io/health | python3 -m json.tool"
echo ""
echo "    4. Clean up:"
echo "       rm .env.rotated"
echo "       rm .env.backup  # only after confirming everything works"
echo ""

echo "============================================================"
echo "  Credential rotation guide complete."
echo "  Template written to: $ENV_ROTATED"
echo "============================================================"
