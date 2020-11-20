#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 "$OPT" && pwd)"

test_var_to_param() {
  print_current_function_name "> " ".."
  [ "$(var_to_param "test" "test-value")" = "--test='test-value'" ] || FATAL "failed! $LINENO"
  [ "$(var_to_param -d "test" "")" = "" ] || FATAL "failed! $LINENO"
  [ "$(var_to_param -d "test" "-")" = "--test" ] || FATAL "failed! $LINENO"
  [ "$(var_to_param -f "test-flag" "true")" = "--test-flag" ] || FATAL "failed! $LINENO"
  [ "$(var_to_param -f "test-flag" "false")" = "--test-flag=false" ] || FATAL "failed! $LINENO"
  [ "$(var_to_param -f "test-flag" "")" = "" ] || FATAL "failed! $LINENO"
}

true