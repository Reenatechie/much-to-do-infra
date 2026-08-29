#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Fix: Go needs GOPATH / GOMODCACHE / GOCACHE set explicitly, because
# EC2 user-data runs as root with no HOME environment variable.
#
# Run from INSIDE your much-to-do-infra folder:
#     bash fix-stage4-go-build.sh
# ---------------------------------------------------------------------------
set -euo pipefail

TPL="modules/compute/templates/app-user-data.sh.tftpl"

if [ ! -f "$TPL" ]; then
  echo "ERROR: cannot find $TPL"
  echo "Are you inside the much-to-do-infra folder?"
  exit 1
fi

if grep -q "GOMODCACHE" "$TPL"; then
  echo "Already patched. Nothing to do."
  exit 0
fi

awk '
{
  print
  if ($0 == "cd /tmp/app/Server/MuchToDo") {
    print "export HOME=/root"
    print "export GOPATH=/root/go"
    print "export GOMODCACHE=/root/go/pkg/mod"
    print "export GOCACHE=/root/.cache/go-build"
  }
}
' "$TPL" > "$TPL.tmp"

mv "$TPL.tmp" "$TPL"

echo "Patched. New build section:"
echo "---------------------------------------"
grep -A 7 "Building backend" "$TPL"
echo "---------------------------------------"
echo ""
echo "Next:  terraform apply    (this will rebuild both backend instances)"
