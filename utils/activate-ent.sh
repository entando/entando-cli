#!/usr/bin/env bash
set -eux

echo "BUNDLE_CLI_VERSION: $BUNDLE_CLI_VERSION"
echo "NODE_VERSION: $NODE_VERSION"


if [ -n "$BUNDLE_CLI_VERSION" ]; then
    BUNDLE_CLI_FLAG="--entando-bundle-cli-version=$BUNDLE_CLI_VERSION"
fi

if [ -n "$NODE_VERSION" ]; then
    NODE_VERSION_FLAG="--node-version=$NODE_VERSION"
fi

ent check-env develop --yes ${BUNDLE_CLI_FLAG:=} ${NODE_VERSION_FLAG:=} --lenient