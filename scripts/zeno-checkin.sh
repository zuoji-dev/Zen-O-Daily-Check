#!/usr/bin/env bash
# =============================================================================
# Zen-O Daily Check-in Automation Script
# =============================================================================
# Usage:
#   ZENO_AUTH_TOKEN="your_token" bash scripts/zeno-checkin.sh
#
# Description:
#   Automates the daily check-in for Zen-O platform (https://app.zen-o.xyz/).
#   Designed to be run via GitHub Actions. Handles random delay within the
#   08:00–10:00 UTC+8 window, calls the attendance API, and reports results.
#
# Prerequisites:
#   - curl, jq installed
#   - ZENO_AUTH_TOKEN environment variable set
# =============================================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
API_BASE_URL="https://api.zen-o.xyz/functions/v1"
MAX_SLEEP_SECONDS=7200  # 2 hours max for randomization within 08:00–10:00 UTC+8

# ── Color output helpers ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Pre-flight checks ──────────────────────────────────────────────────────────
if [ -z "${ZENO_AUTH_TOKEN:-}" ]; then
  err "ZENO_AUTH_TOKEN is not set."
  echo ""
  echo "  How to get your token:"
  echo "    1. Log in at https://app.zen-o.xyz/"
  echo "    2. Open DevTools → Application → Local Storage → app.zen-o.xyz"
  echo "    3. Find key \"auth\" → copy the \"token\" value from the JSON"
  echo "    4. Set it as a GitHub Secret: ZENO_AUTH_TOKEN"
  echo ""
  exit 1
fi

if ! command -v curl &>/dev/null; then
  err "curl is required but not installed."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  warn "jq is not installed — will fall back to raw output parsing."
  JQ_AVAILABLE=false
else
  JQ_AVAILABLE=true
fi

# ── Random delay (0–2 hours) for 08:00–10:00 UTC+8 window ─────────────────────
RANDOM_SLEEP=$((RANDOM % MAX_SLEEP_SECONDS))
SLEEP_MINUTES=$((RANDOM_SLEEP / 60))
SLEEP_SECONDS_REMAINDER=$((RANDOM_SLEEP % 60))

info "Scheduling check-in at a random time within 08:00–10:00 UTC+8..."
info "Waiting ${SLEEP_MINUTES}m${SLEEP_SECONDS_REMAINDER}s before check-in..."

# Use a simple progress indicator while sleeping
for ((i = 0; i < RANDOM_SLEEP; i++)); do
  sleep 1
  # Show a dot every 60 seconds
  if ((i % 60 == 59)); then
    echo -n "."
  fi
done
echo ""
ok "Delay complete. Proceeding with check-in."

# ── Helper: API call with curl ─────────────────────────────────────────────────
api_call() {
  local method="$1"    # GET or POST
  local path="$2"      # e.g. /attendance-check-in
  local body="${3:-}"  # optional JSON body

  local url="${API_BASE_URL}${path}"
  local args=(
    -sS
    -X "${method}"
    -H "Authorization: Bearer ${ZENO_AUTH_TOKEN}"
    -H "Content-Type: application/json"
    --connect-timeout 15
    --max-time 30
  )

  if [ -n "${body}" ]; then
    args+=(-d "${body}")
  fi

  curl "${args[@]}" "${url}"
}

# ── Step 1: Get attendance info ─────────────────────────────────────────────────
info "Fetching attendance info..."
ATTENDANCE_INFO=$(api_call "GET" "/attendance-info" || true)

if [ -z "${ATTENDANCE_INFO}" ]; then
  err "Failed to fetch attendance info — check your token and network."
  exit 1
fi

echo "${ATTENDANCE_INFO}" | head -c 500
echo ""

if $JQ_AVAILABLE; then
  CHECKED_COUNT=$(echo "${ATTENDANCE_INFO}" | jq -r '.checked_count // "?"')
  REQUIRED_COUNT=$(echo "${ATTENDANCE_INFO}" | jq -r '.required_count // "?"')
  IS_COMPLETED=$(echo "${ATTENDANCE_INFO}" | jq -r '.is_completed // false')
  WEEK_START=$(echo "${ATTENDANCE_INFO}" | jq -r '.week_start // ""')
  WEEK_END=$(echo "${ATTENDANCE_INFO}" | jq -r '.week_end // ""')

  info "Week: ${WEEK_START} → ${WEEK_END}"
  info "Check-ins: ${CHECKED_COUNT} / ${REQUIRED_COUNT} completed"

  if [ "${IS_COMPLETED}" = "true" ]; then
    warn "Weekly check-in already completed for this week."
  fi
fi

# ── Step 2: Perform check-in ───────────────────────────────────────────────────
info "Performing daily check-in..."
CHECKIN_RESULT=$(api_call "POST" "/attendance-check-in" "{}" || true)

if [ -z "${CHECKIN_RESULT}" ]; then
  err "Check-in request failed (empty response)."
  exit 1
fi

echo "${CHECKIN_RESULT}" | head -c 500
echo ""

# ── Step 3: Parse result ───────────────────────────────────────────────────────
if $JQ_AVAILABLE; then
  CHECKED=$(echo "${CHECKIN_RESULT}" | jq -r '.checked // false')
  ALREADY_CHECKED=$(echo "${CHECKIN_RESULT}" | jq -r '.already_checked // false')
  CHECKIN_DATE=$(echo "${CHECKIN_RESULT}" | jq -r '.checkin_date // ""')
  CHECKED_COUNT_NEW=$(echo "${CHECKIN_RESULT}" | jq -r '.checked_count // ""')

  if [ "${CHECKED}" = "true" ]; then
    ok "Check-in successful! 🎉"
    info "Date: ${CHECKIN_DATE}"
    if [ -n "${CHECKED_COUNT_NEW}" ]; then
      info "Weekly progress: ${CHECKED_COUNT_NEW} / ${REQUIRED_COUNT}"
    fi
  elif [ "${ALREADY_CHECKED}" = "true" ]; then
    warn "Already checked in today (${CHECKIN_DATE}). Nothing changed."
  else
    err "Check-in failed with unexpected response."
    echo "${CHECKIN_RESULT}"
    exit 1
  fi
else
  # Without jq, just echo the raw response
  info "Raw response:"
  echo "${CHECKIN_RESULT}"
fi

# ── Done ────────────────────────────────────────────────────────────────────────
ok "Check-in process completed."