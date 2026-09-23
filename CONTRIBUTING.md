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

Run `./scripts/chart-version.sh plan` locally to preview the bump.

Note: the `mktxp` v2 upgrade shipped as `0.7.0` under the previous rule. The next major upgrade
of an upstream dependency will go to `1.0.0`.
