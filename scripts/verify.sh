#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
cd "$REPOSITORY_ROOT"

export SWIFTPM_MODULECACHE_OVERRIDE="$REPOSITORY_ROOT/.swift-build/module-cache"
export CLANG_MODULE_CACHE_PATH="$REPOSITORY_ROOT/.swift-build/module-cache"

suite="${1:-all}"
case "$suite" in
  routing)
    swift test --scratch-path .swift-build --filter RoutingTests
    ;;
  models)
    swift test --scratch-path .swift-build --filter ModelProfileTests
    swift test --scratch-path .swift-build --filter ModelCatalogTests
    swift test --scratch-path .swift-build --filter ModelCommandTests
    swift test --scratch-path .swift-build --filter LocalModelInferenceTests
    ;;
  privacy)
    swift test --scratch-path .swift-build --filter PrivacyTests
    swift test --scratch-path .swift-build --filter AuditTests
    ;;
  cam)
    swift test --scratch-path .swift-build --filter CAMAdapterTests
    ;;
  research)
    swift test --scratch-path .swift-build --filter ResearchTests
    ;;
  knowledge)
    swift test --scratch-path .swift-build --filter KnowledgeTests
    ;;
  repositories)
    swift test --scratch-path .swift-build --filter RepositoryTests
    ;;
  mac-care)
    swift test --scratch-path .swift-build --filter MacCareTests
    ;;
  conversation)
    swift test --scratch-path .swift-build --filter ConversationTests
    ;;
  tasks)
    swift test --scratch-path .swift-build --filter TaskStoreTests
    ;;
  coordination)
    swift test --scratch-path .swift-build --filter CoordinationTests
    ;;
  portability)
    "$SCRIPT_DIR/verify-portability.sh"
    ;;
  fresh-clone)
    "$SCRIPT_DIR/verify-fresh-clone.sh"
    ;;
  retrieval)
    swift test --scratch-path .swift-build --filter RetrievalTests
    ;;
  generated)
    swift test --scratch-path .swift-build \
      --filter GeneratedAnswerEvaluationTests
    swift test --scratch-path .swift-build \
      --filter LocalModelInferenceTests
    swift test --scratch-path .swift-build \
      --filter ConversationTests
    ;;
  retrieval-report)
    swift run --scratch-path .swift-build cam-assistant evaluate-retrieval \
      Tests/Fixtures/Retrieval/v2/manifest.json \
      docs/evidence/task-06-retrieval-v2-report.json
    ;;
  retrieval-project-contract-report)
    swift run --scratch-path .swift-build cam-assistant evaluate-retrieval \
      Tests/Fixtures/Retrieval/project-contract-v1/manifest.json \
      docs/evidence/task-06-retrieval-project-contract-v1-report.json
    ;;
  smoke)
    "$SCRIPT_DIR/smoke-app.sh"
    ;;
  package)
    "$SCRIPT_DIR/package-app.sh"
    ;;
  release-privacy)
    "$REPOSITORY_ROOT/Tests/ReleaseProofTests/scan-release-privacy-tests.sh"
    "$SCRIPT_DIR/package-app.sh"
    "$REPOSITORY_ROOT/Tests/ReleaseProofTests/package-build-identity-tests.sh"
    "$SCRIPT_DIR/scan-release-privacy.sh" \
      "$REPOSITORY_ROOT/docs/evidence/task-18-release-privacy-scan.json" \
      "$REPOSITORY_ROOT/artifacts/CAM Assistant.app" \
      "$REPOSITORY_ROOT/docs/evidence"
    ;;
  all)
    "$SCRIPT_DIR/verify-portability.sh"
    swift test --scratch-path .swift-build
    swift build --scratch-path .swift-build -c release
    "$SCRIPT_DIR/verify.sh" release-privacy
    if [[ "${CAM_ASSISTANT_SKIP_FRESH_CLONE:-0}" != "1" ]]; then
      "$SCRIPT_DIR/verify-fresh-clone.sh"
    fi
    ;;
  *)
    print -u2 "usage: $0 [routing|models|privacy|cam|research|knowledge|repositories|mac-care|conversation|tasks|coordination|portability|fresh-clone|retrieval|generated|retrieval-report|retrieval-project-contract-report|smoke|package|release-privacy|all]"
    exit 64
    ;;
esac
