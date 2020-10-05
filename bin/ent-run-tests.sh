#!/bin/bash

H() { echo -e "Run the internal tests | Syntax: ${0##*/} update-hosts-file ..."; }
[ "$1" = "-h" ] && H && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh
. s/tests/*

test_check_ver_num
# CONFIG HELPER
CFG_FILE="/tmp/ent-test"

save_cfg_value "XX1" "hey" "$CFG_FILE"
save_cfg_value "XX2" "hey hey" "$CFG_FILE"
save_cfg_value "XX3" "hey hey// \"/'" "$CFG_FILE"
save_cfg_value "XX4" "\" && echo \"**INJECTION ATTEMPT**\"\\ / && \"" "$CFG_FILE"
save_cfg_value "XX5" "\\\" && echo \"**INJECTION ATTEMPT2**\"\\ / && \\\"" "$CFG_FILE"
reload_cfg "$CFG_FILE"

[ "$XX1" = "hey" ] || FATAL "failed! $LINENO"
[ "$XX2" = "hey hey" ] || FATAL "failed! $LINENO"
[ "$XX3" = "hey hey// \"/'" ] || FATAL "failed! $LINENO"
[ "$XX3" = "hey hey// \"/'" ] || FATAL "failed! $LINENO"
[ "$XX4" = "\" && echo \"**INJECTION ATTEMPT**\"\\ / && \"" ] || FATAL "failed! $LINENO"
[ "$XX5" = "\\\" && echo \"**INJECTION ATTEMPT2**\"\\ / && \\\"" ] || FATAL "failed! $LINENO"

# FIND ARG IDX
index_of_arg "FIND-ME" "A" "B" "C" "FIND-ME" "D"
[[ $? -eq 4 ]] || FATAL "failed! $LINENO"

index_of_arg "FIND-ME" "A" "B" "C" "D" "E"
[[ $? -eq 5 ]] || FATAL "failed! $LINENO"