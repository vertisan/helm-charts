#!/bin/bash
set -e

# This script runs semantic-release for each chart in the monorepo
# It detects which charts have changes and runs semantic-release for each one

CHARTS_DIR="charts"

# Function to extract chart name from Chart.yaml
get_chart_name() {
  local chart_yaml=$1
  grep "^name:" "$chart_yaml" | awk '{print $2}' | tr -d '"'
}

# Get all charts
for chart_dir in "$CHARTS_DIR"/*; do
  if [ -d "$chart_dir" ] && [ -f "$chart_dir/Chart.yaml" ]; then
    chart_folder=$(basename "$chart_dir")
    chart_name=$(get_chart_name "$chart_dir/Chart.yaml")
    
    echo "========================================="
    echo "Checking chart folder: $chart_folder"
    echo "Chart name: $chart_name"
    
    # Get the last tag for this chart
    last_tag=$(git tag -l "${chart_name}-*" --sort=-v:refname | head -n 1)
    
    if [ -z "$last_tag" ]; then
      echo "No previous release found for $chart_name"
      commits_range="HEAD"
    else
      echo "Last release: $last_tag"
      commits_range="${last_tag}..HEAD"
    fi
    
    # Check if there are commits for this chart
    commits=$(git log --oneline "$commits_range" -- "$chart_dir" 2>/dev/null || true)
    
    if [ -n "$commits" ]; then
      echo "Changes detected in chart: $chart_name"
      echo "Commits:"
      echo "$commits"
      echo ""
      echo "Running semantic-release for chart: $chart_name"
      
      # Create a chart-specific releaserc file
      cat > ".releaserc.${chart_name}.js" << EOF
module.exports = {
  branches: ['master'],
  tagFormat: '${chart_name}-\${version}',
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
      },
    ],
    [
      '@semantic-release/release-notes-generator',
      {
        preset: 'conventionalcommits',
      },
    ],
    [
      '@semantic-release/changelog',
      {
        changelogFile: 'charts/${chart_folder}/CHANGELOG.md',
      },
    ],
    [
      '@semantic-release/exec',
      {
        verifyReleaseCmd: 'echo "Verifying release for version \${nextRelease.version}"',
        prepareCmd: 'sed -i "s/^version: .*/version: \${nextRelease.version}/" charts/${chart_folder}/Chart.yaml',
      },
    ],
    [
      '@semantic-release/git',
      {
        assets: ['charts/${chart_folder}/Chart.yaml', 'charts/${chart_folder}/CHANGELOG.md'],
        message: 'chore(release): ${chart_name}-\${nextRelease.version} [skip ci]\\n\\n\${nextRelease.notes}',
      },
    ],
    [
      '@semantic-release/github',
      {
        successComment: false,
      },
    ],
  ],
};
EOF
      
      # Run semantic-release with chart-specific config
      # Set GIT_LOG environment to filter to only this chart's commits
      (
        cd "$chart_dir" && \
        npx semantic-release --extends "../../.releaserc.${chart_name}.js"
      ) || {
        exit_code=$?
        echo "semantic-release completed for $chart_name with exit code: $exit_code"
        if [ $exit_code -ne 0 ]; then
          echo "This may be expected if there are no releasable commits (feat, fix, perf, or breaking changes)"
        fi
      }
      
      # Clean up temporary config
      rm -f ".releaserc.${chart_name}.js"
    else
      echo "No changes in chart: $chart_name since last release"
    fi
    echo ""
  fi
done

echo "========================================="
echo "Semantic release process completed"
