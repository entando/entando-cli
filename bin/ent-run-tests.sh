#!/bin/bash

H() { echo -e "Run the internal tests | Syntax: ${0##*/} update-hosts-file ..."; }
[ "$1" = "-h" ] && H && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir" 1>&2
  exit
}

. s/_base.sh
. s/tests/sys-utils-tests.sh
. s/tests/utils-tests.sh

test_check_ver_num
test_index_of_arg
test_cfg_helper
