#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh

ent-jhipster "$@"
