#!/bin/bash

#
# LICENSE: Public Domain
#

XDEV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$XDEV_SCRIPT_DIR/xdev-lib.sh"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

RUN() {
  local FOUNDERR=false

  # note: process_errors must be run in the current subshell
  process_errors < <(
    # shellcheck disable=SC2046
    shellcheck ${XDEV_SHELLCHECK_IGNORE:+--exclude "$XDEV_SHELLCHECK_IGNORE"} $(_xdev.list-src-files "$XDEV_SRC") \
    | alter_line_format
  )

  "$FOUNDERR" && return 77
  return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

alter_line_format() {
  sed -E "s/In (.*) line /##\1:/"
}

process_errors() {
  while read i; do
    if [ "${i:0:2}" = "##" ]; then
      echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      echo -e "$PWD/${i:2} \n"
      FOUNDERR=true
    else
      echo "$i"
    fi
  done
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

_xdev.ensure-project-type "sh"

XDEV_SRC=$(_xdev.get-config "XDEV_SRC")
XDEV_SHELLCHECK_IGNORE=$(_xdev.get-config "XDEV_SHELLCHECK_IGNORE")

RUN"$@"
