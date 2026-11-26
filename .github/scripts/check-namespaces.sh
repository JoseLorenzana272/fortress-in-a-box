#!/bin/bash
# The platform namespaces are written in several files - they must all match
set -e
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }

# Same PLATFORM_NS in the CLI and the installer
[ "$(grep -h "^PLATFORM_NS=" fortress install.sh | sort -u | wc -l)" -eq 1 ] || fail "PLATFORM_NS differs between fortress and install.sh"
platform=$(grep -m1 "^PLATFORM_NS=" fortress | sed "s/.*'^(\(.*\))\$'/\1/; s/\.\*/*/g" | tr '|' '\n' | sort)

# The user project blocks exactly those namespaces
project=$(grep -o 'namespace: "![^"]*"' k8s/argocd/user-project.yaml | sed 's/.*"!//; s/"$//' | sort)
[ "$platform" = "$project" ] || fail "user-project.yaml does not block the same namespaces as PLATFORM_NS"

# Every policy excludes the same namespaces, and only platform ones
[ "$(grep -h -A1 -E "name: exclude-(system-)?namespaces" k8s/policies/*.yaml | grep expression | sort -u | wc -l)" -eq 1 ] || fail "policies exclude different namespaces"
for ns in $(grep -h -m1 -A1 -E "name: exclude-(system-)?namespaces" k8s/policies/*.yaml | grep -o "'[^']*'" | tr -d "'" | sed 's/-$/-*/' | sort -u); do
    echo "$platform" | grep -qxF -- "$ns" || fail "policies exclude $ns, which is not in PLATFORM_NS"
done

# Every policy except debug containers has the same exception check
blocks=$(for f in k8s/policies/*.yaml; do sed -n '/name: skip-allowed-namespaces/,/^  [a-z#]/{/^  [a-z#]/!p}' "$f" | md5sum; done | grep -v "^d41d8cd98f00b204" | sort | uniq -c)
[ "$(echo "$blocks" | wc -l)" -eq 1 ] && [ "$(echo "$blocks" | awk '{print $1}')" -eq $(( $(ls k8s/policies/*.yaml | wc -l) - 1 )) ] || fail "the exception check differs between policies"
! grep -q "skip-allowed-namespaces" k8s/policies/disallow-insecure-ephemeral-containers.yaml || fail "debug containers must not use exceptions"

echo "OK: platform namespaces and exception checks match in every file"
