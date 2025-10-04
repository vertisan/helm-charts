# Helm Charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/vrs-factory)](https://artifacthub.io/packages/search?repo=vrs-factory)

## Usage

```shell
$ helm repo add vrs-factory https://helm.vrs-factory.dev
$ helm repo update
$ helm search repo -r "vrs-factory/*"
```

## Development

This repository uses [semantic-release](https://github.com/semantic-release/semantic-release) to automate version management and releases for all charts. 

### Contributing

When contributing changes, please use [Conventional Commits](https://www.conventionalcommits.org/) format:

- `feat:` - New features (triggers minor version bump)
- `fix:` - Bug fixes (triggers patch version bump)
- `perf:` - Performance improvements (triggers patch version bump)
- `BREAKING CHANGE:` - Breaking changes (triggers major version bump)

For more details on the release process, see [SEMANTIC_RELEASE.md](SEMANTIC_RELEASE.md).
