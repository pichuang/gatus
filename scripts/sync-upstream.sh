#!/usr/bin/env bash
#
# sync-upstream.sh — Sync local fork with upstream TwiN/gatus
#
# Usage:
#   ./scripts/sync-upstream.sh          # Interactive sync
#   ./scripts/sync-upstream.sh --force  # Skip confirmation prompt
#
set -euo pipefail

UPSTREAM_REMOTE="upstream"
UPSTREAM_URL="https://github.com/TwiN/gatus.git"
UPSTREAM_BRANCH="master"
LOCAL_BRANCH="pichuang"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }

# -------------------------------------------------------------------
# 1. Ensure upstream remote exists
# -------------------------------------------------------------------
if ! git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  info "Adding upstream remote: $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
else
  CURRENT_URL=$(git remote get-url "$UPSTREAM_REMOTE")
  if [ "$CURRENT_URL" != "$UPSTREAM_URL" ]; then
    warn "Upstream remote points to $CURRENT_URL (expected $UPSTREAM_URL)"
    warn "Updating upstream remote URL..."
    git remote set-url "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
  fi
fi

# -------------------------------------------------------------------
# 2. Fetch upstream
# -------------------------------------------------------------------
info "Fetching upstream/$UPSTREAM_BRANCH..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"

# -------------------------------------------------------------------
# 3. Check for new commits
# -------------------------------------------------------------------
COMMIT_COUNT=$(git rev-list "$LOCAL_BRANCH".."$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --count)

if [ "$COMMIT_COUNT" -eq 0 ]; then
  ok "Already up to date with upstream. Nothing to do."
  exit 0
fi

UPSTREAM_SHA=$(git rev-parse --short "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")
info "Found $COMMIT_COUNT new upstream commit(s) (up to $UPSTREAM_SHA):"
echo ""
git log "$LOCAL_BRANCH".."$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --oneline --no-merges | head -30
echo ""

if [ "$COMMIT_COUNT" -gt 30 ]; then
  warn "... and $((COMMIT_COUNT - 30)) more (showing first 30)"
  echo ""
fi

# -------------------------------------------------------------------
# 4. Confirm (unless --force)
# -------------------------------------------------------------------
if [ "${1:-}" != "--force" ]; then
  read -rp "Proceed with merge? [y/N] " REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    info "Aborted."
    exit 0
  fi
fi

# -------------------------------------------------------------------
# 5. Ensure we are on the local branch
# -------------------------------------------------------------------
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" != "$LOCAL_BRANCH" ]; then
  info "Switching to $LOCAL_BRANCH..."
  git checkout "$LOCAL_BRANCH"
fi

# -------------------------------------------------------------------
# 6. Create sync branch
# -------------------------------------------------------------------
SYNC_BRANCH="sync/upstream-$(date +%Y%m%d)"
if git show-ref --verify --quiet "refs/heads/$SYNC_BRANCH"; then
  SYNC_BRANCH="sync/upstream-$(date +%Y%m%d-%H%M%S)"
fi

info "Creating branch: $SYNC_BRANCH"
git checkout -b "$SYNC_BRANCH"

# -------------------------------------------------------------------
# 7. Merge upstream
# -------------------------------------------------------------------
info "Merging upstream/$UPSTREAM_BRANCH..."
if git merge "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --no-edit; then
  ok "Merge successful!"
  echo ""
  info "Next steps:"
  echo "  1. Review changes:  git log --oneline $LOCAL_BRANCH..$SYNC_BRANCH"
  echo "  2. Run tests:       make test"
  echo "  3. Push branch:     git push origin $SYNC_BRANCH"
  echo "  4. Create PR:       gh pr create --base $LOCAL_BRANCH --head $SYNC_BRANCH --label upstream-sync"
  echo ""
  echo "  Or push and create PR in one step:"
  echo "    git push origin $SYNC_BRANCH && gh pr create --base $LOCAL_BRANCH --head $SYNC_BRANCH --label upstream-sync --title \"sync: upstream TwiN/gatus @ $UPSTREAM_SHA\""
else
  error "Merge conflict detected!"
  echo ""
  warn "Conflicting files:"
  git diff --name-only --diff-filter=U
  echo ""
  info "How to resolve:"
  echo "  1. Open conflicting files and resolve conflicts"
  echo "     Tip: Look for '// CUSTOM: pichuang' markers to identify custom code"
  echo "  2. Stage resolved files:   git add <file>"
  echo "  3. Complete the merge:     git commit"
  echo "  4. Run tests:              make test"
  echo "  5. Push branch:            git push origin $SYNC_BRANCH"
  echo "  6. Create PR:              gh pr create --base $LOCAL_BRANCH --head $SYNC_BRANCH --label upstream-sync"
  echo ""
  warn "To abort the merge:  git merge --abort && git checkout $LOCAL_BRANCH && git branch -D $SYNC_BRANCH"
  exit 1
fi
