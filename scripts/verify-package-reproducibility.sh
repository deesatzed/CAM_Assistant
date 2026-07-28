#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
PACKAGE_SCRIPT="$SCRIPT_DIR/package-app.sh"
IDENTITY_TEST="$REPOSITORY_ROOT/Tests/ReleaseProofTests/package-build-identity-tests.sh"
APP="$REPOSITORY_ROOT/artifacts/CAM Assistant.app"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-package-repro.XXXXXX")"
FIRST_MANIFEST="$TEST_ROOT/first.manifest"
SECOND_MANIFEST="$TEST_ROOT/second.manifest"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

write_manifest() {
  /usr/bin/find "$APP" -mindepth 1 -print \
    | LC_ALL=C /usr/bin/sort \
    | while IFS= read -r entry; do
        relative="${entry#"$APP"/}"
        mode="$(/usr/bin/stat -f '%Lp' "$entry")"
        if [[ -f "$entry" && ! -L "$entry" ]]; then
          digest="$(shasum -a 256 "$entry" | awk '{print $1}')"
          print "file $mode $digest $relative"
        elif [[ -L "$entry" ]]; then
          target="$(/usr/bin/readlink "$entry")"
          digest="$(print -n -- "$target" | shasum -a 256 | awk '{print $1}')"
          print "link $mode $digest $relative"
        elif [[ -d "$entry" ]]; then
          print "directory $mode - $relative"
        else
          print -u2 "unsupported app-bundle entry type"
          exit 1
        fi
      done
}

"$PACKAGE_SCRIPT" >"$TEST_ROOT/first-build.txt"
"$IDENTITY_TEST" >"$TEST_ROOT/first-identity.txt"
write_manifest >"$FIRST_MANIFEST"

"$PACKAGE_SCRIPT" >"$TEST_ROOT/second-build.txt"
"$IDENTITY_TEST" >"$TEST_ROOT/second-identity.txt"
write_manifest >"$SECOND_MANIFEST"

if ! /usr/bin/cmp -s "$FIRST_MANIFEST" "$SECOND_MANIFEST"; then
  print -u2 "unsigned app package content is not reproducible"
  exit 1
fi

entry_count="$(wc -l <"$FIRST_MANIFEST" | tr -d ' ')"
manifest_sha="$(shasum -a 256 "$FIRST_MANIFEST" | awk '{print $1}')"
print \
  "CAM_ASSISTANT_PACKAGE_REPRODUCIBILITY status=pass builds=2 entries=$entry_count manifest_sha256=$manifest_sha"
