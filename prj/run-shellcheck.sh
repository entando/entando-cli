#!/bin/bash

CHK() {
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC2046
cd "$SCRIPT_DIR/.." || { echo "Unable to enter the script dir"; exit 99; }
local "FOUNDERR"=false
# shellcheck disable=SC2046
while read i; do
  if [ "${i:0:2}" = "##" ]; then
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -e "$PWD/${i:2} \n"
    FOUNDERR=true
  else
    echo "$i"
  fi
done < <(
  shellcheck --exclude "SC2181,SC2155,SC2119,SC2031" \
    $(find bin -maxdepth 3 -type f) \
    $(find s -maxdepth 2 -type f -not -name "*.zsh" -not -name "*.cmd") \
    hr/auto activate deactivate \
    | sed -E "s/In (.*) line /##\1:/" \
  ;
)

  "$FOUNDERR" && return 77
  return 0
}

CHK "$@"
