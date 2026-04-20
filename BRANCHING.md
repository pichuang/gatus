# Branching Strategy

This repository is a fork of [TwiN/gatus](https://github.com/TwiN/gatus) with custom modifications. This document describes how branches are managed and how upstream updates are integrated.

## Branch Layout

```
upstream/master  ←  TwiN/gatus (read-only mirror)
     │
     ▼
  sync/upstream-YYYYMMDD  (temporary sync branch, auto-created by CI)
     │
     ▼  PR (requires manual review)
   pichuang  ←  pichuang/gatus main branch (upstream + all customizations)
     │
     ├── feature/{name}   (new feature development)
     ├── fix/{name}       (bug fixes)
     └── infra/{name}     (CI/CD, Dockerfile, deployment changes)
```

## Branches

| Branch | Purpose | Rules |
|--------|---------|-------|
| `pichuang` | Main branch containing upstream code + all custom modifications | Protected: merge via PR only |
| `feature/*` | New feature development | Branch from `pichuang`, merge back via PR |
| `fix/*` | Bug fixes | Branch from `pichuang`, merge back via PR |
| `infra/*` | CI/CD, Dockerfile, deployment changes | Branch from `pichuang`, merge back via PR |
| `sync/upstream-*` | Temporary upstream sync branches | Auto-created by CI or sync script, deleted after merge |

## Upstream Sync

### Automatic (GitHub Actions)

The `sync-upstream` workflow ([.github/workflows/sync-upstream.yml](.github/workflows/sync-upstream.yml)) runs daily at 08:00 UTC and can also be triggered manually.

**When no conflicts exist:**
1. CI detects new upstream commits
2. Creates a `sync/upstream-YYYYMMDD` branch with the merge
3. Opens a PR to `pichuang` labeled `upstream-sync`
4. Maintainer reviews and merges the PR

**When conflicts exist:**
1. CI detects merge conflicts
2. Creates a GitHub Issue labeled `upstream-sync` + `conflict`
3. Issue lists conflicting files and resolution instructions
4. Maintainer resolves conflicts locally using the sync script

### Manual (Local Script)

```bash
./scripts/sync-upstream.sh          # Interactive mode
./scripts/sync-upstream.sh --force  # Skip confirmation
```

The script handles:
- Adding/verifying the `upstream` remote
- Fetching latest upstream changes
- Showing pending commits for review
- Creating a `sync/upstream-YYYYMMDD` branch
- Attempting the merge
- Providing conflict resolution guidance if needed

## Custom Code Markers

When adding custom modifications to files that also exist upstream, use comment markers to identify custom code blocks:

```go
// CUSTOM: pichuang - start
// ... your custom code ...
// CUSTOM: pichuang - end
```

This makes it easier to identify custom code during merge conflict resolution.

## Workflow for New Changes

1. Create a branch from `pichuang`:
   ```bash
   git checkout pichuang
   git pull origin pichuang
   git checkout -b feature/my-change
   ```

2. Make changes, commit, and push:
   ```bash
   git add .
   git commit -m "feat: description of change"
   git push origin feature/my-change
   ```

3. Create a PR to `pichuang` and wait for CI to pass.

4. Merge the PR (squash or merge commit, your choice).

## Tips for Reducing Merge Conflicts

- **Keep custom changes modular**: When possible, add new files rather than modifying existing upstream files.
- **Use comment markers**: Always mark custom code blocks with `// CUSTOM: pichuang` comments.
- **Sync frequently**: Don't let upstream changes accumulate — merge sync PRs promptly.
- **Vendor dependencies**: After any dependency change, run `go mod tidy && go mod vendor`.
- **Frontend builds**: After changes in `web/app/`, run `make frontend-build` to regenerate `web/static/`.
