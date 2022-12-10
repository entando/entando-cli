#!/bin/bash

_require 's/essentials.sh'
_require 's/var-utils.sh'

#TEST:unit,lib
test_var_to_param() {
  ( _IT  "shoult propery convert a variable to an argument parameter"
    
    [ "$(var_to_param "test" "test-value")" = "--test='test-value'" ] || FATAL "failed! $LINENO"
    [ "$(var_to_param -d "test" "")" = "" ] || FATAL "failed! $LINENO"
    [ "$(var_to_param -d "test" "-")" = "--test" ] || FATAL "failed! $LINENO"
    [ "$(var_to_param -f "test-flag" "true")" = "--test-flag" ] || FATAL "failed! $LINENO"
    [ "$(var_to_param -f "test-flag" "false")" = "--test-flag=false" ] || FATAL "failed! $LINENO"
    [ "$(var_to_param -f "test-flag" "")" = "" ] || FATAL "failed! $LINENO"
  )
}

true
