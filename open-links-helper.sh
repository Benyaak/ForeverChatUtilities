#!/usr/bin/env bash
set -euo pipefail

# Optional companion helper for Forever Chat Utilities (macOS).
# When World of Warcraft is the active window and you copy an http(s) URL
# from the in-game navigation dialog (Cmd+C), this helper opens it in your
# default web browser automatically.

echo "Forever Chat Utilities - Browser Link Helper (macOS)"
echo "Listening for URLs copied from World of Warcraft... Press Ctrl+C to stop."

last_clip="$(pbpaste 2>/dev/null || true)"

is_wow_frontmost() {
  local app_name
  app_name="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)"
  case "$app_name" in
    *"World of Warcraft"*|*"Wow"*|*"WoW"*) return 0 ;;
    *) return 1 ;;
  esac
}

is_safe_http_url() {
  local value="$1"
  local regex='^https?://[]A-Za-z0-9._~:/?#[@!&'\''()*+,;=%-]+$'
  [[ "$value" =~ $regex ]]
}

while true; do
  clip="$(pbpaste 2>/dev/null || true)"
  if [[ -n "$clip" && "$clip" != "$last_clip" ]]; then
    last_clip="$clip"
    if is_wow_frontmost && is_safe_http_url "$clip"; then
      echo "Opening: $clip"
      open "$clip"
    fi
  fi
  sleep 0.4
done
