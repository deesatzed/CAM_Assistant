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
    swift test --disable-sandbox --scratch-path .swift-build --filter RoutingTests
    ;;
  models)
    swift test --disable-sandbox --scratch-path .swift-build --filter ModelProfileTests
    swift test --disable-sandbox --scratch-path .swift-build --filter ModelCatalogTests
    swift test --disable-sandbox --scratch-path .swift-build --filter ModelCommandTests
    swift test --disable-sandbox --scratch-path .swift-build --filter LocalModelInferenceTests
    ;;
  privacy)
    swift test --disable-sandbox --scratch-path .swift-build --filter PrivacyTests
    swift test --disable-sandbox --scratch-path .swift-build --filter AuditTests
    ;;
  cam)
    swift test --disable-sandbox --scratch-path .swift-build --filter CAMAdapterTests
    ;;
  research)
    swift test --disable-sandbox --scratch-path .swift-build --filter ResearchTests
    ;;
  ingest)
    swift test --disable-sandbox --scratch-path .swift-build --filter IngestTests
    ;;
  knowledge)
    swift test --disable-sandbox --scratch-path .swift-build --filter KnowledgeTests
    ;;
  repositories)
    swift test --disable-sandbox --scratch-path .swift-build --filter RepositoryTests
    ;;
  repository-semantic)
    swift test --disable-sandbox --scratch-path .swift-build --filter RepositoryTests
    ;;
  mac-care)
    swift test --disable-sandbox --scratch-path .swift-build --filter MacCareTests
    ;;
  conversation)
    swift test --disable-sandbox --scratch-path .swift-build --filter ConversationTests
    ;;
  tasks)
    swift test --disable-sandbox --scratch-path .swift-build --filter TaskStoreTests
    ;;
  coordination)
    swift test --disable-sandbox --scratch-path .swift-build --filter CoordinationTests
    ;;
  modules)
    swift test --disable-sandbox --scratch-path .swift-build --filter ModuleRegistryTests
    ;;
  backup)
    swift test --disable-sandbox --scratch-path .swift-build --filter FullVaultBackupTests
    ;;
  storage)
    swift test --disable-sandbox --scratch-path .swift-build --filter StorageTests
    ;;
  app)
    swift test --disable-sandbox --scratch-path .swift-build --filter CAMAssistantAppTests
    ;;
  portability)
    "$SCRIPT_DIR/verify-portability.sh"
    ;;
  fresh-clone)
    "$SCRIPT_DIR/verify-fresh-clone.sh"
    ;;
  retrieval)
    swift test --disable-sandbox --scratch-path .swift-build --filter RetrievalTests
    ;;
  generated)
    swift test --disable-sandbox --scratch-path .swift-build \
      --filter GeneratedAnswerEvaluationTests
    swift test --disable-sandbox --scratch-path .swift-build \
      --filter LocalModelInferenceTests
    swift test --disable-sandbox --scratch-path .swift-build \
      --filter ConversationTests
    ;;
  retrieval-report)
    swift run --disable-sandbox --scratch-path .swift-build cam-assistant evaluate-retrieval \
      Tests/Fixtures/Retrieval/v2/manifest.json \
      docs/evidence/task-06-retrieval-v2-report.json
    ;;
  retrieval-project-contract-report)
    swift run --disable-sandbox --scratch-path .swift-build cam-assistant evaluate-retrieval \
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
  goal-map)
    "$REPOSITORY_ROOT/Tests/ReleaseProofTests/goal-gate-map-tests.sh"
    ;;
  package-reproducibility)
    "$REPOSITORY_ROOT/Tests/ReleaseProofTests/package-reproducibility-tests.sh"
    ;;
  all)
    "$SCRIPT_DIR/verify-portability.sh"
    "$SCRIPT_DIR/verify.sh" goal-map
    swift test --disable-sandbox --scratch-path .swift-build
    swift build --disable-sandbox --scratch-path .swift-build -c release
    "$SCRIPT_DIR/verify.sh" package-reproducibility
    "$SCRIPT_DIR/verify.sh" release-privacy
    if [[ "${CAM_ASSISTANT_SKIP_FRESH_CLONE:-0}" != "1" ]]; then
      "$SCRIPT_DIR/verify-fresh-clone.sh"
    fi
    ;;
  *)
    print -u2 "usage: $0 [routing|models|privacy|cam|research|ingest|knowledge|repositories|repository-semantic|mac-care|conversation|tasks|coordination|modules|backup|storage|app|portability|fresh-clone|retrieval|generated|retrieval-report|retrieval-project-contract-report|smoke|package|release-privacy|goal-map|package-reproducibility|all]"
    exit 64
    ;;
esac
