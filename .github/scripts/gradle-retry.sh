#!/usr/bin/env bash
# Run a Gradle command and retry it when the failure is a transient network error.
# GTNH dependency mirrors (notably gregtech.overminddl1.com) occasionally time out,
# which would otherwise fail an unrelated commit.
set -uo pipefail

attempts="${RETRY_ATTEMPTS:-3}"
delay="${RETRY_DELAY_SECONDS:-30}"
log="$(mktemp)"

for ((attempt = 1; attempt <= attempts; attempt++)); do
  if "$@" 2>&1 | tee "$log"; then
    rm -f "$log"
    exit 0
  fi

  if ! grep -Eq 'Connect timed out|Read timed out|Could not GET|Could not HEAD|Connection reset|Remote host terminated|Could not download|Could not resolve' "$log"; then
    echo "::error::Command failed for a reason other than a transient network error; not retrying." >&2
    exit 1
  fi

  if ((attempt == attempts)); then
    echo "::error::Command still failing after ${attempts} attempts." >&2
    exit 1
  fi

  echo "::warning::Attempt ${attempt}/${attempts} failed with a network error; retrying in ${delay}s." >&2
  sleep "$delay"
done
