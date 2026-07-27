#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
cd "$REPOSITORY_ROOT"

required_files=(
  AGENTS.md
  GOAL.md
  GOAL_FINISH_WIKI.md
  STANDARDS.md
  IMPLEMENT.md
  DECISIONS.md
  PROGRESS.md
  TASK_QUEUE.md
  README.md
  Package.swift
  scripts/verify.sh
  scripts/package-app.sh
  scripts/smoke-app.sh
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    print -u2 "missing required repository file: $required_file"
    exit 1
  fi
done

truth_files=(
  AGENTS.md
  GOAL.md
  GOAL_FINISH_WIKI.md
  STANDARDS.md
  IMPLEMENT.md
  DECISIONS.md
  PROGRESS.md
  TASK_QUEUE.md
  README.md
  docs/VERIFICATION_REPORT.md
)

if rg -n '\.\./(GOAL|docs/)' "${truth_files[@]}"; then
  print -u2 "governing project truth must not depend on files outside the repository"
  exit 1
fi

if git ls-files | rg '(^|/)(\.DS_Store|\.build|\.swift-build[^/]*|artifacts)(/|$)'; then
  print -u2 "generated build or Finder artifacts must not be tracked"
  exit 1
fi

git diff --check

print "CAM_ASSISTANT_PORTABILITY required_files=ok external_truth_links=none tracked_generated_artifacts=none diff_check=ok"
