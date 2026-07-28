#!/usr/bin/env bash
#
# PR 9b — the external reconcile trigger. An out-of-process loop that POSTs the
# reconcile endpoint on an interval, aging the board forward (carry-forward lapsed
# one-off tasks + auto-archive past events). Deliberately outside the Ruby app to
# dodge in-process-thread/forking footguns (see docs/DECISIONS.md PR 9a ADR); the
# planned rufus-scheduler swap can replace this later without touching the endpoint.
#
# reconcile is global + idempotent, so calling it repeatedly is safe — a run that
# carries nothing and archives nothing is a no-op.
#
# Usage:
#   LISTS_API=http://localhost:9292 ACCOUNT_ID=<account> bin/reconcile_loop.sh
# Optional:
#   RECONCILE_INTERVAL=<seconds>   # default 3600 (hourly)
set -u

: "${LISTS_API:?set LISTS_API to the API base URL, e.g. http://localhost:9292}"
: "${ACCOUNT_ID:?set ACCOUNT_ID to the account header the API expects}"

interval="${RECONCILE_INTERVAL:-3600}"

while true; do
  # || true: a transient failure (server restart, network blip) must never kill the
  # loop — the next tick just tries again.
  curl -s -X POST "$LISTS_API/api/reconcile" -H "ACCOUNT_ID: $ACCOUNT_ID" || true
  sleep "$interval"
done
