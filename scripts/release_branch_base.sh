#!/bin/bash

set -euo pipefail

export VERSION=$1
echo "VERSION: ${VERSION}"

echo "=== Building Gem ===="
gem build branch_base.gemspec

echo "=== Pushing gem ===="
gem push branch_base-"$VERSION".gem

echo "=== Sleeping for 15s ===="
sleep 15

echo "=== Pushing tags to github ===="
git tag v"$VERSION"
git push origin --tags

echo "=== Cleaning up ===="
rm branch_base-"$VERSION".gem
