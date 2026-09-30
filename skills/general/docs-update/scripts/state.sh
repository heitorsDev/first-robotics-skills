#!/usr/bin/env bash
# Sourced helper. Reads docs/.docsync/state.json without requiring jq.
#
#   source scripts/state.sh
#   state_get source_branch master      # scalar, with default
#   state_list ignore                   # array, one item per line
#
# Resolution order for the JSON reader: jq > python3 > sed (best effort).

STATE_FILE="${STATE_FILE:-docs/.docsync/state.json}"
MAP_FILE="${MAP_FILE:-docs/.docsync/map.json}"

_json_tool() {
  if command -v jq >/dev/null 2>&1; then echo jq
  elif command -v python3 >/dev/null 2>&1; then echo python3
  else echo sed
  fi
}

state_get() { # state_get <key> [default]
  local key="$1" def="${2:-}" out=""
  [ -f "$STATE_FILE" ] || { printf '%s' "$def"; return 0; }
  case "$(_json_tool)" in
    jq)
      out="$(jq -r --arg k "$key" '.[$k] // empty' "$STATE_FILE" 2>/dev/null)" ;;
    python3)
      out="$(python3 -c '
import json,sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
v = d.get(sys.argv[2], "")
print(v if isinstance(v, str) else "")
' "$STATE_FILE" "$key" 2>/dev/null)" ;;
    *)
      out="$(sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$STATE_FILE" | head -1)" ;;
  esac
  if [ -n "$out" ]; then printf '%s' "$out"; else printf '%s' "$def"; fi
}

state_list() { # state_list <key>  -> one element per line
  local key="$1"
  [ -f "$STATE_FILE" ] || return 0
  case "$(_json_tool)" in
    jq)
      jq -r --arg k "$key" '(.[$k] // []) | .[]' "$STATE_FILE" 2>/dev/null ;;
    python3)
      python3 -c '
import json,sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for item in d.get(sys.argv[2], []) or []:
    if isinstance(item, str):
        print(item)
' "$STATE_FILE" "$key" 2>/dev/null ;;
    *)
      tr -d '\n' < "$STATE_FILE" \
        | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p" \
        | tr ',' '\n' | sed 's/[[:space:]]*"\{0,1\}//; s/"\{0,1\}[[:space:]]*$//' | grep -v '^$' ;;
  esac
}
