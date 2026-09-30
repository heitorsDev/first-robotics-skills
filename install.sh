#!/usr/bin/env bash
# Vendor a single skill from this marketplace into the current repo's
# .claude/skills/<name>/ — the directory both Claude Code and opencode read.
#
# Usage (from inside the target repo):
#   curl -fsSL https://raw.githubusercontent.com/heitorsDev/first-robotics-skills/main/install.sh | sh -s -- <skill-name>
#   ./install.sh --local /path/to/first-robotics-skills <skill-name>   # local dev
set -euo pipefail

REPO="${FRS_REPO:-heitorsDev/first-robotics-skills}"
REF="${FRS_REF:-main}"
LOCAL_SRC=""

if [ "${1:-}" = "--local" ]; then
  LOCAL_SRC="$2"
  shift 2
fi

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "usage: install.sh [--local <path-to-repo>] <skill-name>" >&2
  exit 1
fi

TARGET_DIR=".claude/skills/$NAME"
if [ -e "$TARGET_DIR" ]; then
  echo "error: $TARGET_DIR already exists" >&2
  exit 1
fi

find_skill_dir() {
  # $1 = repo root -> prints skills/<scope>/<name>, or nothing
  local root="$1"
  local scope
  for scope in general frc ftc; do
    if [ -d "$root/skills/$scope/$NAME" ]; then
      echo "$root/skills/$scope/$NAME"
      return 0
    fi
  done
  return 1
}

if [ -n "$LOCAL_SRC" ]; then
  SRC_DIR="$(find_skill_dir "$LOCAL_SRC")" || {
    echo "error: no skill named '$NAME' under $LOCAL_SRC/skills/{general,frc,ftc}" >&2
    exit 1
  }
  mkdir -p "$(dirname "$TARGET_DIR")"
  cp -r "$SRC_DIR" "$TARGET_DIR"
else
  WORKDIR="$(mktemp -d)"
  trap 'rm -rf "$WORKDIR"' EXIT
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" | tar -xz -C "$WORKDIR"
  EXTRACTED="$WORKDIR"/*/
  SRC_DIR="$(find_skill_dir "$(echo $EXTRACTED)")" || {
    echo "error: no skill named '$NAME' in ${REPO}@${REF}" >&2
    exit 1
  }
  mkdir -p "$(dirname "$TARGET_DIR")"
  cp -r "$SRC_DIR" "$TARGET_DIR"
fi

# The .claude-plugin wrapper is generated for marketplace distribution only —
# strip it from a vendored copy, it has no meaning outside that flow.
rm -rf "$TARGET_DIR/.claude-plugin"

echo "installed $TARGET_DIR"
