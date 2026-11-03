#!/usr/bin/env bash
#
# Derive Helm chart versions from conventional commits.
#
#   plan    print the computed bump for every chart; change nothing
#   apply   rewrite `version:` in each chart's Chart.yaml
#   notes   write RELEASE-NOTES.md into each chart dir for the pending release;
#           chart-releaser uses it as the GitHub release body
#           (CR_RELEASE_NOTES_FILE), so it must exist before packaging
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

# Release-note sections, "key|title". Bullets follow semantic-release's
# default (angular) preset: "* **scope:** subject (sha)", sorted by scope then
# subject; a breaking commit is listed under its type and again, with its
# BREAKING CHANGE note, under the breaking section. Sections are ordered as in
# the conventionalcommits preset so breaking changes come first. Only types
# that classify to a bump appear.
SECTIONS=(
  "breaking|⚠ BREAKING CHANGES"
  "feat|Features"
  "fix|Bug Fixes"
  "perf|Performance Improvements"
  "revert|Reverts"
  "docs|Documentation"
  "refactor|Code Refactoring"
  "build|Build System"
)

# breaking_note <full commit message> -> BREAKING CHANGE footer text, unwrapped;
# empty for a `type!:` commit without one
breaking_note() {
  awk '
    found && /^[[:space:]]*$/ { exit }
    found { note = note " " $0; next }
    /^BREAKING[ -]CHANGE:/ { found = 1; sub(/^BREAKING[ -]CHANGE:[[:space:]]*/, ""); note = $0 }
    END { print note }
  ' <<<"$1"
}

# write_notes <chart dir> <chart name> <version> <newest chart tag or "">
write_notes() {
  local dir="$1" chart="$2" cur="$3" last="$4"
  local out="$dir/RELEASE-NOTES.md" desc entries="" sha msg level subject
  local type scope text note link s body repo="" compare=""

  if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
    repo="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY"
  fi

  desc="$(awk '/^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$dir/Chart.yaml")"

  # entries: one "section<TAB>scope<TAB>text<TAB>link" line per bullet
  while read -r sha; do
    [[ -n "$sha" ]] || continue
    msg="$(git log -1 --format=%B "$sha")"
    level="$(classify "$msg")"
    [[ "$level" != none ]] || continue
    subject="${msg%%$'\n'*}"
    [[ "$subject" =~ ^([a-zA-Z]+)(\(([^\)]*)\))?(!)?:[[:space:]]*(.*)$ ]]
    type="$(tr '[:upper:]' '[:lower:]' <<<"${BASH_REMATCH[1]}")"
    scope="${BASH_REMATCH[3]}"
    text="${BASH_REMATCH[5]}"
    link="$(git rev-parse --short=7 "$sha")"
    [[ -z "$repo" ]] || link="[$link]($repo/commit/$sha)"

    entries+="$type"$'\t'"$scope"$'\t'"$text"$'\t'"$link"$'\n'
    if [[ "$level" == major ]]; then
      note="$(breaking_note "$msg")"
      entries+="breaking"$'\t'"$scope"$'\t'"${note:-$text}"$'\t'"$link"$'\n'
    fi
  done < <(git log --no-merges --format=%H "${last:+${last}..}HEAD" -- "$dir")

  {
    echo "$desc"
    for s in "${SECTIONS[@]}"; do
      body="$(awk -F'\t' -v k="${s%%|*}" '$1 == k' <<<"$entries" \
        | LC_ALL=C sort -t $'\t' -k2,2 -k3,3 \
        | awk -F'\t' '{ printf "* %s%s (%s)\n", ($2 != "" ? "**" $2 ":** " : ""), $3, $4 }')"
      if [[ -n "$body" ]]; then
        printf '\n### %s\n\n%s\n' "${s#*|}" "$body"
      fi
    done
    if [[ -n "$last" && "$last" != "${chart}-${cur}" ]]; then
      compare="$last...${chart}-${cur}"
      [[ -z "$repo" ]] || compare="$repo/compare/$compare"
      printf '\n**Full Changelog**: %s\n' "$compare"
    fi
  } >"$out"

  echo "$chart: wrote $out"
  cat "$out"
}

exit_code=0

for dir in charts/*/; do
  dir="${dir%/}"
  [[ -f "$dir/Chart.yaml" ]] || continue

  chart="$(awk '/^name:/{print $2; exit}'    "$dir/Chart.yaml")"
  cur="$(  awk '/^version:/{print $2; exit}' "$dir/Chart.yaml")"

  last="$(git tag --list "${chart}-*" --sort=-v:refname | head -1)"

  # Before the guard: in notes mode the version being ahead of the newest tag
  # is exactly the release being described.
  if [[ "$MODE" == notes ]]; then
    write_notes "$dir" "$chart" "$cur" "$last"
    continue
  fi

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
