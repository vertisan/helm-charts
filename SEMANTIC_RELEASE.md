# Semantic Release Setup

This repository uses [semantic-release](https://github.com/semantic-release/semantic-release) to automate the release process for Helm charts in this monorepo.

## How it Works

1. **Commit Messages**: Use [Conventional Commits](https://www.conventionalcommits.org/) format:
   - `feat:` - triggers a minor version bump
   - `fix:` - triggers a patch version bump
   - `perf:` - triggers a patch version bump
   - `BREAKING CHANGE:` - triggers a major version bump

2. **Automatic Releases**: When commits are pushed to `master`, semantic-release will:
   - Analyze commits since the last release for each chart
   - Determine the next version number based on commit types
   - Update the `Chart.yaml` version
   - Generate/update `CHANGELOG.md` for the chart
   - Create a GitHub release with release notes
   - Create a git tag with the format `<chart-name>-<version>`

3. **Chart Packaging**: After semantic-release creates the tag, the `release.yaml` workflow:
   - Packages the chart
   - Signs it with GPG
   - Uploads it to the GitHub Pages Helm repository
   - **Does NOT** overwrite the release notes created by semantic-release

## Monorepo Support

Each chart in the `charts/` directory is released independently:
- Charts are identified by their `name` field in `Chart.yaml`
- Tags follow the format: `<chart-name>-<version>` (e.g., `prometheus-mikrotik-exporter-0.5.4`)
- Only commits affecting a specific chart trigger a release for that chart
- Each chart has its own `CHANGELOG.md`

## Example Commit Messages

```bash
# Patch release (0.5.3 -> 0.5.4)
git commit -m "fix(prometheus-mktxp): correct servicemonitor labels"

# Minor release (0.5.3 -> 0.6.0)
git commit -m "feat(prometheus-mktxp): add support for custom annotations"

# Major release (0.5.3 -> 1.0.0)
git commit -m "feat(prometheus-mktxp): redesign configuration structure

BREAKING CHANGE: configuration format has changed"

# No release (documentation, chores, etc.)
git commit -m "docs(prometheus-mktxp): update README"
git commit -m "chore: update CI workflow"
```

## Workflows

### semantic-release.yaml
Runs on push to `master`. Analyzes commits and creates releases for charts with changes.

### release.yaml
Triggered by tags. Packages and publishes charts to the Helm repository.
Configuration:
- `CR_SKIP_EXISTING: true` - Skips if release already exists
- `CR_RELEASE_NOTES_FILE: ""` - Prevents overwriting release notes from semantic-release

## Local Testing

To test semantic-release locally (dry-run):

```bash
npm install
GITHUB_TOKEN=<your-token> npx semantic-release --dry-run
```

## Migration Notes

- Previous releases used manual version bumps in `Chart.yaml`
- New releases will be automatic based on commit messages
- Old release tags are preserved and respected
- Chart-releaser now skips release note generation (handled by semantic-release)
