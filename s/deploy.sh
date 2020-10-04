#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh

ADDR="$1"
[ -z $ADDR ] && ADDR="$(hostname -I | cut -d' ' -f 1)" && COMM=" (autodetected)"

set -e

reload_cfg

sed "s/your\\.domain\\.suffix\\.com/$ADDR.nip.io/" "d/$DEPL_SPEC_YAML_FILE.tpl" >"d/$DEPL_SPEC_YAML_FILE"

echo "> Using address: $ADDR$COMM"
echo "> Deploying.."

$KUBECTL create -f "d/$DEPL_SPEC_YAML_FILE"
