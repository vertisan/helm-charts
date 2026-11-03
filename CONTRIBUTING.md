# Contributing

## Chart versions

Chart versions are derived from [Conventional Commits](https://www.conventionalcommits.org/);
don't edit `version:` in `Chart.yaml` by hand.

PRs are squash-merged, so **the PR title is what gets parsed**, not the individual commit subjects.

| PR title | Bump |
|---|---|
| `feat!: ...`, any type with `!`, or a `BREAKING CHANGE:` footer | major |
| `feat: ...` | minor |
| `fix:` `perf:` `refactor:` `build:` `revert:` `docs:` | patch |
| `chore:` `ci:` `style:` `test:` | none |

After a merge, `scripts/chart-version.sh` opens a `chore(release)` PR carrying the bump; merging it
publishes the release. Renovate PRs bump their own chart version and publish on merge.

Renovate titles chart dependency updates `fix(deps):` (`feat(deps)!:` for upstream majors) and CI-only updates `ci(deps):`, so their titles follow the table above.

Run `./scripts/chart-version.sh plan` locally to preview the bump.

The GitHub release body is generated from the same commits: the chart description, then the commits since the previous chart tag that touch the chart, grouped by type (breaking, features, fixes, ...). Only types that bump a version are listed. Run `./scripts/chart-version.sh notes` to preview it; it writes the git-ignored `charts/<chart>/RELEASE-NOTES.md`.

Note: the `mktxp` v2 upgrade shipped as `0.7.0` under the previous rule. The next major upgrade
of an upstream dependency will go to `1.0.0`.
