#!/usr/bin/env bash
#
# Derive Helm chart versions from conventional commits.
#
#   plan    print the computed bump for every chart; change nothing
#   apply   rewrite `version:` in each chart's Chart.yaml
#
# Environment (PR mode; both unset on master):
#   PR_TITLE  the pull request title, parsed because squash merges discard
#             individual commit subjects and keep the PR title as the subject
#   BASE_REF  the base branch to diff against, e.g. origin/master
#
# Renovate keeps bumping chart versions in its own PRs via `bumpVersions` in
# renovate.json. The already-bumped guard below is what keeps the two from
# colliding: if `version:` has already moved past the newest chart tag, this
# script leaves it alone.
set -euo pipefail

MODE="${1:-plan}"
PR_TITLE="${PR_TITLE:-}"
BASE_REF="${BASE_REF:-}"

rank() { case "$1" in major) echo 3;; minor) echo 2;; patch) echo 1;; *) echo 0;; esac; }

# classify <full commit message> -> major|minor|patch|none
classify() {
  local msg="$1" subject type bang
  subject="${msg%%$'\n'*}"
  if [[ "$subject" =~ ^([a-zA-Z]+)(\(([^\)]*)\))?(!)?: ]]; then
    type="$(tr '[:upper:]' '[:lower:]' <<<"${BASH_REMATCH[1]}")"
    bang="${BASH_REMATCH[4]}"
  else
    echo none; return
  fi
  if [[ -n "$bang" ]] || grep -qE '^BREAKING[ -]CHANGE:' <<<"$msg"; then
    echo major; return
  fi
  case "$type" in
    feat)                                echo minor ;;
    fix|perf|refactor|build|revert|docs) echo patch ;;
    *)                                   echo none  ;;
  esac
}

# next <current version> <level> -> bumped version
next() {
  local IFS=. M m p
  read -r M m p <<<"${1%%-*}"
  case "$2" in
    major) echo "$((M+1)).0.0" ;;
    minor) echo "$M.$((m+1)).0" ;;
    patch) echo "$M.$m.$((p+1))" ;;
  esac
}

exit_code=0

for dir in charts/*/; do
  dir="${dir%/}"
  [[ -f "$dir/Chart.yaml" ]] || continue

  chart="$(awk '/^name:/{print $2; exit}'    "$dir/Chart.yaml")"
  cur="$(  awk '/^version:/{print $2; exit}' "$dir/Chart.yaml")"

  last="$(git tag --list "${chart}-*" --sort=-v:refname | head -1)"

  # Already-bumped guard: Renovate (or a human) moved the version past the
  # newest release tag, so the bump is pending and nothing is owed here.
  if [[ -n "$last" && "$last" != "${chart}-${cur}" ]]; then
    echo "$chart: $cur (bump already pending; newest tag $last) - skipping"
    continue
  fi

  if [[ -n "$BASE_REF" ]]; then
    range="$(git merge-base "$BASE_REF" HEAD)..HEAD"
  else
    range="${last:+${last}..HEAD}"
  fi

  level=none
  reason=""
  while read -r sha; do
    [[ -n "$sha" ]] || continue
    l="$(classify "$(git log -1 --format=%B "$sha")")"
    if (( $(rank "$l") > $(rank "$level") )); then
      level="$l"
      reason="$(git log -1 --format=%s "$sha")"
    fi
  done < <(git log --no-merges --format=%H "${range:-HEAD}" -- "$dir")

  if [[ -n "$PR_TITLE" ]]; then
    l="$(classify "$PR_TITLE")"
    if (( $(rank "$l") > $(rank "$level") )); then
      level="$l"
      reason="PR title: $PR_TITLE"
    fi
  fi

  touched=false
  if [[ -n "${range:-}" ]] && [[ -n "$(git diff --name-only "${range}" -- "$dir")" ]]; then
    touched=true
  fi

  if [[ "$level" == none ]]; then
    echo "$chart: $cur (no bump)"
    if [[ -n "$BASE_REF" && "$touched" == true ]]; then
      echo "::error::$chart changed but no commit or PR title maps to a version bump."
      echo "  Use feat: / fix: / docs: / perf: / refactor: / build: , or feat!: for breaking."
      exit_code=1
    fi
    continue
  fi

  new="$(next "$cur" "$level")"
  echo "$chart: $cur -> $new ($level, from: $reason)"
  if [[ "$MODE" == apply ]]; then
    sed -i -E "0,/^version:/s|^version:.*|version: $new|" "$dir/Chart.yaml"
  fi
done

exit "$exit_code"
