#!/usr/bin/env bash
set -eux

echo "BUNDLE_CLI_VERSION: $BUNDLE_CLI_VERSION"

if [ -n "$BUNDLE_CLI_VERSION" ] ; then
    ent check-env develop --yes --entando-bundle-cli-version="$BUNDLE_CLI_VERSION" --lenient
else
    ent check-env develop --yes  --lenient
fi