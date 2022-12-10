#!/bin/bash

# Verifies a condition
#
# Expects a value to match an expected value according with an operator.
# If the verification fails an error and a callstack are printed.
# The function assumes to be wrapped so it skips 2 levels of the callstack.
#
# Syntax1 - Params:
# $1: The error messages prefix
# $2: Name of the variable containing the value to test
# $3: Operator
# $4: expected value
#
# Syntax2 - Params:
# $1: The error messages prefix
# $2: -v
# $3: A description of value
# $4: A value to test
# $5: Operator
# $6: expected value
#
_verify.verify-expression() {
  local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
  local PREFIX="${1:+"$1>" }"; shift
  local CENSOR=false;[ "$1" = "--censor" ] && { CENSOR=true; shift; }
  
  local _tmp_ver_N
  if [ "$1" = "-v" ]; then
    shift
    _tmp_ver_N="$1"; 
    local A B E="$2" O=$3 V=$4
    shift 4
  else
    _tmp_ver_N="$1";
    local A B E
    (E="${!_tmp_ver_N}") || _sys.fatal -S "${SKIP}" "Invalid variable name"
    E="${!_tmp_ver_N}"; O=$2; V=$3
    shift 4
  fi

  case "$O" in
    eq) O="==";OD="TO:  ";  [[ "$E" -eq "$V" ]];;
    ne) O="!=";OD="TO:  ";  [[ "$E" -ne "$V" ]];;
    gt) O=">";OD="THAN:";   [[ "$E" -gt "$V" ]];;
    ge) O=">=";OD="THAN:";  [[ "$E" -ge "$V" ]];;
    lt) O="<";OD="THAN:";   [[ "$E" -lt "$V" ]];;
    le) O="<=";OD="THAN:";  [[ "$E" -le "$V" ]];;
    =|==) O="=";OD="TO:  ";  [[ "$E" = "$V" ]];;
    !=) O="!=";OD="TO:  ";  [[ "$E" != "$V" ]];;
    =~) O="=~";OD="TO:  ";   [[ "$E" =~ $V ]];;
    !=~) O="=~";OD="TO:  ";   [[ ! "$E" =~ $V ]];;
    starts-with) O="starting";OD="WITH:";  [[ "$E" = "$V"* ]];;
    ends-with) O="ending";OD="WITH:";  [[ "$E" = *"$V" ]];;
    contains) O="containing";OD="THE VALUE:";  [[ "$E" = *"$V"* ]];;
    *) _sys.fatal -S "${SKIP}" "Unknown operator \"$O\"";;
  esac

  if [ $? != 0 ]; then
    #local ln fn fl
    #read -r ln fn fl < <(caller "1")

    local MSG MSG2

    if ! $CENSOR; then
      E="$(_verify._pp_adjust_var E 250)"
      V="$(_verify._pp_adjust_var V 250)"

      if [ "${#E}" -gt 30 ] || [ "${#V}" -gt 30 ]; then
        MSG="Validation Failed"
        MSG2="\n${PREFIX}Validation Failed in:\n> EXPECTED:  $_tmp_ver_N"
        MSG2+="\n> TO BE:     $O\n> $OD      $V\n\n> BUT WAS FOUND: $E"
      else
        MSG="Validation Failed"
        MSG2="\n${PREFIX}Expected $_tmp_ver_N $O \"$V\" but instead I've found \"$E\""
      fi
    else
        local B='\033[44m\033[1;37m'
        local A='\033[0;39m'
        MSG="Validation Failed"
        MSG2="\n${PREFIX}Expected $_tmp_ver_N $O ${B}[[CENSORED]]${A} but instead I've found ${B}[[CENSORED]]${A}"
    fi

    [ -n "$MSG2" ] && {
      echo "" 1>&2
      echo -e "$MSG2" 1>&2
    }
    _sys.fatal -S "$SKIP" -99 "$MSG" 1>&2
  fi
}

# See _verify.verify-expression, but with param $1
#
_verify() {
  local SKIP=1;[ "$1" = "-S" ] && { ((SKIP+=$2)); shift 2; }
  _verify.verify-expression -S "$SKIP" "" "$@"
}

# Adjust a variable for pretty printing
#
# Params:
# $1: the variable to cut
# $2: the max len
#
_verify._pp_adjust_var() {
  local _tmp_="${!1}"

  local B='\033[44m\033[1;37m'
  local A='\033[0;39m'

  if [ "${#_tmp_}" -gt "$2" ]; then
    echo "${_tmp_:0:$2}${B}[[CUTTED]]${A}"
  else
    echo "$_tmp_"
  fi
}
