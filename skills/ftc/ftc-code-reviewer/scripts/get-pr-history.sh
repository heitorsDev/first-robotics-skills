#!/usr/bin/env bash
# Prints a Pull Request's conversation history: description, general comments,
# reviews, and inline comments (with file/line), in chronological order.
#
# Usage:
#   get-pr-history.sh            # discovers the PR number from the CI environment
#   get-pr-history.sh <number>   # explicit
#
# Requires an authenticated `gh` ($GH_TOKEN). Exits 1 with a message on stderr
# when there's no PR or no permission — in that case the review proceeds without history.

set -uo pipefail

# How many comments to bring back (the most recent ones). A huge history blows the context.
MAX_ITEMS="${PR_HISTORY_MAX:-40}"
# Truncate each comment body so a whole earlier review doesn't get pasted back in full.
MAX_BODY_CHARS="${PR_HISTORY_BODY_CHARS:-1200}"

REPO="${GITHUB_REPOSITORY:-}"
REPO_ARG=()
[ -n "$REPO" ] && REPO_ARG=(-R "$REPO")

# --- discover the PR number --------------------------------------------------
PR="${1:-${PR_NUMBER:-}}"
if [ -z "$PR" ] && [ -n "${GITHUB_REF:-}" ]; then
  case "$GITHUB_REF" in
    refs/pull/*) PR="$(printf '%s' "$GITHUB_REF" | cut -d/ -f3)" ;;
  esac
fi
if [ -z "$PR" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -r "${GITHUB_EVENT_PATH}" ]; then
  PR="$(grep -o '"number"[[:space:]]*:[[:space:]]*[0-9]*' "$GITHUB_EVENT_PATH" \
        | head -1 | grep -o '[0-9]*$' || true)"
fi
if [ -z "$PR" ] && command -v gh >/dev/null 2>&1; then
  PR="$(gh pr view "${REPO_ARG[@]}" --json number --jq .number 2>/dev/null || true)"
fi

if [ -z "$PR" ]; then
  echo "warning: no Pull Request identified — review will proceed without history." >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "warning: 'gh' not found — review will proceed without history for PR #${PR}." >&2
  exit 1
fi

SLUG="$(gh repo view "${REPO_ARG[@]}" --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [ -z "$SLUG" ]; then
  echo "warning: could not resolve the repository — review will proceed without history." >&2
  exit 1
fi

echo "### PR #${PR} HISTORY (${SLUG})"
echo

# --- PR description -----------------------------------------------------------
gh pr view "$PR" "${REPO_ARG[@]}" \
  --json title,author,body,reviewDecision,isDraft \
  --jq 'def blank: (. // "") | if (. | test("^\\s*$")) then null else . end;
        "#### Description\n**Title:** \(.title)\n**Author:** @\(.author.login)\n**Current decision:** \((.reviewDecision | blank) // "none")\n\n\((.body | blank) // "(no description)")"' \
  2>/dev/null || echo "(couldn't read the PR description)"
echo

# --- unified collection: issue comments + reviews + review comments ----------
# Each item becomes {created_at, kind, author, location, state, body}; sorted by date.
COMMENTS_JSON="$(gh api "repos/${SLUG}/issues/${PR}/comments" --paginate 2>/dev/null || echo '[]')"
REVIEWS_JSON="$(gh api "repos/${SLUG}/pulls/${PR}/reviews" --paginate 2>/dev/null || echo '[]')"
INLINE_JSON="$(gh api "repos/${SLUG}/pulls/${PR}/comments" --paginate 2>/dev/null || echo '[]')"

printf '%s\n%s\n%s\n' "$COMMENTS_JSON" "$REVIEWS_JSON" "$INLINE_JSON" \
| jq -rs --argjson max "$MAX_ITEMS" --argjson cut "$MAX_BODY_CHARS" '
    def trim: (. // "") | if (length > $cut)
      then (.[0:$cut] + "\n\n…(comment truncated)") else . end;

    ( ((.[0] // []) | map({
        at: .created_at,
        kind: "General comment",
        who: (.user.login // "?"),
        where: "",
        state: "",
        body: (.body | trim)
      }))
    + ((.[1] // []) | map(select((.state // "") != "PENDING" and ((.body // "") | length) > 0)) | map({
        at: (.submitted_at // .created_at),
        kind: "Review",
        who: (.user.login // "?"),
        where: "",
        state: (.state // ""),
        body: (.body | trim)
      }))
    + ((.[2] // []) | map({
        at: .created_at,
        kind: "Inline comment",
        who: (.user.login // "?"),
        where: ((.path // "?") + ":" + ((.line // .original_line // 0) | tostring)),
        state: (if .in_reply_to_id then "reply" else "" end),
        body: (.body | trim)
      }))
    )
    | sort_by(.at)
    | (if (length > $max) then .[-$max:] else . end) as $items
    | if ($items | length) == 0 then
        "#### Conversation\n(no comments yet — this is the first review on this PR)"
      else
        "#### Conversation (" + ($items | length | tostring) + " items, oldest first)\n"
        + ($items | map(
            "---\n**[" + .kind + "]** @" + .who
            + (if .where  != "" then " on `" + .where + "`" else "" end)
            + (if .state  != "" then " (" + .state + ")" else "" end)
            + " — " + .at + "\n\n" + .body
          ) | join("\n\n"))
      end
  ' 2>/dev/null || echo "(couldn't read the comments — missing read permission on the PR?)"
