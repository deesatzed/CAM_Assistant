#!/bin/zsh
# Probe common local OpenAI-compatible endpoints. Records honesty, not fiction.
set -euo pipefail

print "CAM_ASSISTANT_LOCAL_MODEL_PROBE begin"
found=0
for url in \
  "http://127.0.0.1:1234/v1/models" \
  "http://127.0.0.1:11434/v1/models" \
  "http://localhost:1234/v1/models" \
  "http://localhost:11434/v1/models"
do
  code="$(curl -sS -o /tmp/cam-model-probe.json -w '%{http_code}' -m 2 "$url" 2>/dev/null || print "000")"
  if [[ "$code" == "200" ]]; then
    found=1
    print "READY $url"
    head -c 500 /tmp/cam-model-probe.json 2>/dev/null || true
    print ""
  else
    print "DOWN  $url http=$code"
  fi
done
if [[ "$found" -eq 0 ]]; then
  print "CAM_ASSISTANT_LOCAL_MODEL_PROBE status=none_ready"
  print "Offline Find/Talk-coach paths remain valid; live synthesis not proven this host."
  exit 0
fi
print "CAM_ASSISTANT_LOCAL_MODEL_PROBE status=ready"
exit 0
