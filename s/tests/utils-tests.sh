#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"


# FIND ARG IDX
test_index_of_arg() {
  print_current_function_name "> " ".."

  index_of_arg "FIND-ME" "A" "B" "C" "FIND-ME" "D"
  [[ $? -eq 4 ]] || FATAL "failed! $LINENO"

  index_of_arg "FIND-ME" "A" "B" "C" "D" "E"
  [[ $? -eq 255 ]] || FATAL "failed! $LINENO"

  index_of_arg -p "FIND-ME=" "A" "B" "C" "FIND-ME=1" "D"
  [[ $? -eq 4 ]] || FATAL "failed! $LINENO"

  index_of_arg -p "app.name=" "A" "B" "C" "app.name=myapp" "D"
  [[ $? -eq 4 ]] || FATAL "failed! $LINENO"

  index_of_arg -p "app.name=" "A" "B" "C" "app-name=myapp" "D"
  [[ $? -eq 255 ]] || FATAL "failed! $LINENO"

  index_of_arg "FIND-ME=" "A" "B" "C" "FIND-ME=1" "D"
  [[ $? -eq 255 ]] || FATAL "failed! $LINENO"
}

# CONFIG HELPER
test_cfg_helper() {
  print_current_function_name "> " ".."
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
}

true