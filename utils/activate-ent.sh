#!/usr/bin/env bash
set -eux

echo "BUNDLE_CLI_VERSION: $BUNDLE_CLI_VERSION"
echo "NODE_VERSION: $NODE_VERSION"

ent check-env develop --yes --entando-bundle-cli-version="$BUNDLE_CLI_VERSION" --node-version="$NODE_VERSION" --lenient