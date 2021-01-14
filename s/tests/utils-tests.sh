#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

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

  index_of_arg -p -n 1 "[^-]" "-A" "-B" "-C" "FIND-ME" "OR-ME" "-D"
  [[ $? -eq 4 ]] || FATAL "failed! $LINENO"

  index_of_arg -p -n 2 "[^-]" "-A" "-B" "-C" "FIND-ME" "OR-ME" "-D"
  [[ $? -eq 5 ]] || FATAL "failed! $LINENO"
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

test_ask() {
  print_current_function_name "> " ".."

  {
    (echo "y" | ask "Should I proceed anyway?") || FATAL "failed! $LINENO"
    (echo "n" | ask "Should I proceed anyway?") && FATAL "failed! $LINENO"
    (echo "" | ask "Should I proceed anyway?" "Y") || FATAL "failed! $LINENO"
    echo ""
    (echo "n" | ask "Should I proceed anyway?" "Y") && FATAL "failed! $LINENO"
    echo ""
  } > /dev/null
}

# HELPER "SELECT ONE"
test_select_one() {
  print_current_function_name "> " ".."
  local select_one_res select_one_res_alt

  declare -a arr
  arr[0]="test1"
  arr[1]="test2"
  echo "2" | (
    select_one "TestValue" "${arr[@]}" >/dev/null
    [ "$select_one_res:$select_one_res_alt" = "2:test2" ] || FATAL "failed! $LINENO"
  ) || return "$?"

  declare -a arr2
  arr2[0]="test1"
  echo "2" | (
    select_one -s "TestValue" "${arr2[@]}" >/dev/null
    [ "$select_one_res:$select_one_res_alt" = "1:test1" ] || FATAL "failed! $LINENO"
  ) || return "$?"
}

test_args_or_ask() {
  print_current_function_name "> " ".."

  args_or_ask "RES" "anything" id=1 anything="x!@ adsa" surname=asurname || FATAL "failed! $LINENO"
  [ "$RES" = 'x!@ adsa' ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" "--anything" --pos=1 --anything="x!@ adsa" --surname=asurname || FATAL "failed! $LINENO"
  [ "$RES" = 'x!@ adsa' ] || FATAL "failed! $LINENO"
  args_or_ask "RES" "name/id//" id=1 name=aname surname=asurname || FATAL "failed! $LINENO"
  [ "$RES" = "aname" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" "name/id//" id=1 name=aname surname=asurname || FATAL "failed! $LINENO"
  [ "$RES" = "aname" ] || FATAL "failed! $LINENO"
  echo "" | (
    args_or_ask "RES" "name/id/defaultname/" || FATAL "failed! $LINENO"
    [ "$RES" = "defaultname" ] || FATAL "failed! $LINENO"
  ) || exit $?
  args_or_ask -n "RES" "name/id/defaultname/" || FATAL "failed! $LINENO"
  [ "$RES" = "defaultname" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" 'name/id//' && FATAL "failed! $LINENO"
  [ "$RES" = "" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" 'name/id/not-a-valid-id!/' && FATAL "failed! $LINENO"
  [ "$RES" = "" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" "--name/id//" --os=1 --name=aname --surname=asurname || FATAL "failed! $LINENO"
  [ "$RES" = "aname" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" "--name/id//" id=1 name=aname surname=asurname && FATAL "failed! $LINENO"
  [ "$RES" = "" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" "name/id//" --pos=1 --name=aname --surname=asurname && FATAL "failed! $LINENO"
  [ "$RES" = "" ] || FATAL "failed! $LINENO"
  args_or_ask -n "RES" "--name" --pos=1 --name --surname=asurname || FATAL "failed! $LINENO"
  [ "$RES" = "" ] || FATAL "failed! $LINENO"
  # Pure Flags
  args_or_ask -f -- "--clean" --build --clean || FATAL "failed! $LINENO"
  args_or_ask -f -- "--find" --build --clean && FATAL "failed! $LINENO"
  # Flags with assigned var (-a)
  args_or_ask -n -F "RES" "--yes///Assumes yes for all yes-no questions" "--yes"
  [ "$RES" = "true" ] || FATAL "failed! $LINENO"
  args_or_ask -F "RES" "--clean" --build --clean || FATAL "failed! $LINENO"
  [ "$RES" = "true" ] || FATAL "failed! $LINENO"
  args_or_ask -F "RES" "--find" --build --clean && FATAL "failed! $LINENO"
  [ "$RES" = "false" ] || FATAL "failed! $LINENO"
  RES="XXX"
  args_or_ask -n -p -F "RES" "--find" --build --clean && FATAL "failed! $LINENO"
  [ "$RES" = "XXX" ] || FATAL "failed! $LINENO"
  RES="XXX"
  args_or_ask -n -F -p "RES" "--find" --build --clean --find=false || FATAL "failed! $LINENO"
  [ "$RES" = "false" ] || FATAL "failed! $LINENO"
  args_or_ask -n -F -p "RES" "--find" --build --clean --find=true || FATAL "failed! $LINENO"
  [ "$RES" = "true" ] || FATAL "failed! $LINENO"
  args_or_ask -n -F -p "RES" "--find" --build --clean --find || FATAL "failed! $LINENO"
  [ "$RES" = "true" ] || FATAL "failed! $LINENO"
  args_or_ask -F "RES" "--find//true" --build --clean && FATAL "failed! $LINENO"
  [ "$RES" = "true" ] || FATAL "failed! $LINENO"
  RES="XXX"
  args_or_ask -n -F "RES" "--auto-hostname///Automatically registers the VM" "$@" && FATAL "failed! $LINENO"
  [ "$RES" = "false" ] || FATAL "failed! $LINENO"
  # Positional arguments (-a)
  args_or_ask -a "RES" "1" --build --clean name surname || FATAL "failed! $LINENO"
  [ "$RES" = "name" ] || FATAL "failed! $LINENO"
  args_or_ask -a "RES" "2" --build --clean name surname || FATAL "failed! $LINENO"
  [ "$RES" = "surname" ] || FATAL "failed! $LINENO"
  args_or_ask -n -a "RES" "3" --build --clean name surname && FATAL "failed! $LINENO"
  [ "$RES" = "" ] || FATAL "failed! $LINENO"
  # Space separated argument
  args_or_ask -n -s "RES" "-n" -n entando || FATAL "failed! $LINENO"
  [ "$RES" = "entando" ] || FATAL "failed! $LINENO"
}

test_remotes() {
    print_current_function_name "> " ".."
    map-clear REMOTES
    map-save REMOTES
    map-count REMOTES N
    [ "$N" = 0 ] || FATAL "failed! $LINENO"
    map-set REMOTES "test" "a-test"
    map-set REMOTES "test2" "another test"
    map-count REMOTES N
    [ "$N" = 2 ] || FATAL "failed! $LINENO"
    map-save REMOTES
    map-clear REMOTES
    reload_cfg
    map-count REMOTES N
    [ "$N" = 2 ] || FATAL "failed! $LINENO"
    map-get REMOTES V "test"
    [ "$V" = "a-test" ] || FATAL "failed! $LINENO"
    map-get REMOTES V "test2"
    [ "$V" = "another test" ] || FATAL "failed! $LINENO"
}

true