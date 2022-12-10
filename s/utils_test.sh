#!/bin/bash

_require 's/var-utils.sh'
_require 's/utils.sh'

#TEST:unit,lib,args
test_index_of_arg() {

  ( _IT "should find arguments in args list"

    index_of_arg "FIND-ME" "A" "B" "C" "FIND-ME" "D"
    [[ $? -eq 4 ]] || _FAIL

    index_of_arg "FIND-ME" "A" "B" "C" "D" "E"
    [[ $? -eq 255 ]] || _FAIL

    index_of_arg -p "FIND-ME=" "A" "B" "C" "FIND-ME=1" "D"
    [[ $? -eq 4 ]] || _FAIL

    index_of_arg -p "app.name=" "A" "B" "C" "app.name=myapp" "D"
    [[ $? -eq 4 ]] || _FAIL

    index_of_arg -p "app.name=" "A" "B" "C" "app-name=myapp" "D"
    [[ $? -eq 255 ]] || _FAIL

    index_of_arg "FIND-ME=" "A" "B" "C" "FIND-ME=1" "D"
    [[ $? -eq 255 ]] || _FAIL

    index_of_arg -p -n 1 "[^-]" "-A" "-B" "-C" "FIND-ME" "OR-ME" "-D"
    [[ $? -eq 4 ]] || _FAIL

    index_of_arg -p -n 2 "[^-]" "-A" "-B" "-C" "FIND-ME" "OR-ME" "-D"
    [[ $? -eq 5 ]] || _FAIL
  )
}

#TEST:unit,lib,config
test_cfg_helper() {
  
  ( _IT "should find arguments in args list"
  
    CFG_FILE="/tmp/ent-test"

    save_cfg_value "XX1" "hey" "$CFG_FILE"
    save_cfg_value "XX2" "hey hey" "$CFG_FILE"
    save_cfg_value "XX3" "hey hey// \"/'" "$CFG_FILE"
    save_cfg_value "XX4" "\" && echo \"**INJECTION ATTEMPT**\"\\ / && \"" "$CFG_FILE"
    save_cfg_value "XX5" "\\\" && echo \"**INJECTION ATTEMPT2**\"\\ / && \\\"" "$CFG_FILE"
    reload_cfg "$CFG_FILE"

    [ "$XX1" = "hey" ] || _FAIL
    [ "$XX2" = "hey hey" ] || _FAIL
    [ "$XX3" = "hey hey// \"/'" ] || _FAIL
    [ "$XX3" = "hey hey// \"/'" ] || _FAIL
    [ "$XX4" = "\" && echo \"**INJECTION ATTEMPT**\"\\ / && \"" ] || _FAIL
    [ "$XX5" = "\\\" && echo \"**INJECTION ATTEMPT2**\"\\ / && \\\"" ] || _FAIL
  )
}

#TEST:unit,lib,ui,mock
test_ask() {

  ( _IT "should get proper answer to yes-no questions"
    {
      (echo "y" | ask "Should I proceed anyway?") || _FAIL
      (echo "n" | ask "Should I proceed anyway?") && _FAIL
      (echo "" | ask "Should I proceed anyway?" "Y") || _FAIL
      echo ""
      (echo "n" | ask "Should I proceed anyway?" "Y") && _FAIL
      echo ""
    } > /dev/null
  )
}

#TEST:unit,lib,ui,mock
test_select_one() {
  
  ( _IT "should select one element from a list"
  
    _flag_status -t "FZF_SELECT" false
    local select_one_res select_one_res_alt

    declare -a arr
    arr[0]="test1"
    arr[1]="test2"
    echo "2" | (
      select_one "TestValue" "${arr[@]}" >/dev/null
      [ "$select_one_res:$select_one_res_alt" = "2:test2" ] || _FAIL
    ) || return "$?"

    declare -a arr2
    arr2[0]="test1"
    echo "2" | (
      select_one -s "TestValue" "${arr2[@]}" >/dev/null
      [ "$select_one_res:$select_one_res_alt" = "1:test1" ] || _FAIL
    ) || return "$?"
  )
}

#TEST:unit,lib,ui,args,mock
test_args_or_ask() {

  ( _IT "should extract an argument from the args list"
  
    args_or_ask "RES" "anything" id=1 anything="x!@ adsa" surname=asurname || _FAIL
    [ "$RES" = 'x!@ adsa' ] || _FAIL
    args_or_ask -n "RES" "--anything" --pos=1 --anything="x!@ adsa" --surname=asurname || _FAIL
    [ "$RES" = 'x!@ adsa' ] || _FAIL
    args_or_ask "RES" "name/id//" id=1 name=aname surname=asurname || _FAIL
    [ "$RES" = "aname" ] || _FAIL
    args_or_ask -n "RES" "name/id//" id=1 name=aname surname=asurname || _FAIL
    [ "$RES" = "aname" ] || _FAIL
    echo "" | (
      args_or_ask "RES" "name/id/defaultname/" || _FAIL
      [ "$RES" = "defaultname" ] || _FAIL
    ) || exit $?
    args_or_ask -n "RES" "name/id/defaultname/" || _FAIL
    [ "$RES" = "defaultname" ] || _FAIL
    args_or_ask -n "RES" 'name/id//' && _FAIL
    [ "$RES" = "" ] || _FAIL
    args_or_ask -n "RES" 'name/id/not-a-valid-id!/' && _FAIL
    [ "$RES" = "" ] || _FAIL
    args_or_ask -n "RES" "--name/id//" --os=1 --name=aname --surname=asurname || _FAIL
    [ "$RES" = "aname" ] || _FAIL
    args_or_ask -n "RES" "--name/id//" id=1 name=aname surname=asurname && _FAIL
    [ "$RES" = "" ] || _FAIL
    args_or_ask -n "RES" "name/id//" --pos=1 --name=aname --surname=asurname && _FAIL
    [ "$RES" = "" ] || _FAIL
    args_or_ask -n "RES" "--name" --pos=1 --name --surname=asurname || _FAIL
    [ "$RES" = "" ] || _FAIL
    # Pure Flags
    args_or_ask -f -- "--clean" --build --clean || _FAIL
    args_or_ask -f -- "--find" --build --clean && _FAIL
    # Flags with assigned var (-F)
    args_or_ask -n -F "RES" "--yes///Assumes yes for all yes-no questions" "--yes"
    [ "$RES" = "true" ] || _FAIL
    args_or_ask -F "RES" "--clean" --build --clean || _FAIL
    [ "$RES" = "true" ] || _FAIL
    args_or_ask -F "RES" "--find" --build --clean && _FAIL
    [ "$RES" = "false" ] || _FAIL
    RES="XXX"
    args_or_ask -n -p -F "RES" "--find" --build --clean && _FAIL
    [ "$RES" = "XXX" ] || _FAIL
    RES="XXX"
    args_or_ask -n -F -p "RES" "--find" --build --clean --find=false || _FAIL
    [ "$RES" = "false" ] || _FAIL
    args_or_ask -n -F -p "RES" "--find" --build --clean --find=true || _FAIL
    [ "$RES" = "true" ] || _FAIL
    args_or_ask -n -F -p "RES" "--find" --build --clean --find || _FAIL
    [ "$RES" = "true" ] || _FAIL
    args_or_ask -F "RES" "--find//true" --build --clean && _FAIL
    [ "$RES" = "true" ] || _FAIL
    RES="XXX"
    args_or_ask -n -F "RES" "--auto-hostname///Automatically registers the VM" "$@" && _FAIL
    [ "$RES" = "false" ] || _FAIL
    # Positional arguments (-a)
    args_or_ask -a "RES" "1" --build --clean name surname || _FAIL
    [ "$RES" = "name" ] || _FAIL
    args_or_ask -a "RES" "2" --build --clean name surname || _FAIL
    [ "$RES" = "surname" ] || _FAIL
    args_or_ask -n -a "RES" "3" --build --clean name surname && _FAIL
    [ "$RES" = "" ] || _FAIL
    # Space separated argument
    args_or_ask -n -s "RES" "-n" -n entando || _FAIL
    [ "$RES" = "entando" ] || _FAIL
  )
}

#TEST:unit,lib,url
test_url_functions() {

  ( _IT "properly concatenate paths"
    local RES
    
    path-concat RES "a" "b"
    [ "$RES" = "a/b" ] || _FAIL
    path-concat RES "a/" "b"
    [ "$RES" = "a/b" ] || _FAIL
    path-concat RES "a" "/b"
    [ "$RES" = "a/b" ] || _FAIL
    path-concat RES "a/" "/b"
    [ "$RES" = "a/b" ] || _FAIL
    
    path-concat RES "a" ""
    [ "$RES" = "a/" ] || _FAIL
    path-concat RES "a/" ""
    [ "$RES" = "a/" ] || _FAIL
    path-concat RES "" "b"
    [ "$RES" = "b" ] || _FAIL
    path-concat RES "" "/b"
    [ "$RES" = "/b" ] || _FAIL
    
    path-concat RES "" ""
    [ "$RES" = "" ] || _FAIL
    
    path-concat -t RES "a" "b"
    [ "$RES" = "a/b/" ] || _FAIL
  )
  
  ( _IT "should remove the last subpath"
    
    RES="$(_url_remove_last_subpath "http://example.com/entando-de-app")"
    [ "$RES" = "http://example.com" ] || _FAIL
    RES="$(_url_remove_last_subpath "http://example.com/subpath/entando-de-app")"
    [ "$RES" = "http://example.com/subpath" ] || _FAIL
    RES="$(_url_remove_last_subpath "http://example.com/subpath/entando-de-app/")"
    [ "$RES" = "http://example.com/subpath" ] || _FAIL
  )
}

#TEST:unit,lib,digest
test_shell_replacements() {

  ( _IT "should properly calculate digest of a stream"
  
    local plain="ABCDEFGHI"
    local RES
    
    # SHA256 - STDIN
    local encoded="afc78172c81880ae10a1fec994b5b4ee33d196a001a1b66212a15ebe573e00b5"
    RES="$(echo "$plain" | _sha256sum)"
    [ "$RES" = "$encoded" ] || _FAIL
    
    # BASE64
    local encoded="QUJDREVGR0hJCg=="
    RES="$(echo "$plain" | _base64_e)"
    [ "$RES" = "$encoded" ] || _FAIL
    RES="$(echo "$encoded" | _base64_d)"
    [ "$RES" = "$plain" ] || _FAIL
  )
}

#TEST:unit,lib,string
test_string_misc() {
  
  ( _IT "should modify the case of a stream"
  
    RES="$(_upper "1x8299zzuiIO")"
    [ "$RES" = "1X8299ZZUIIO" ] || _FAIL
  )
}

#TEST:unit,lib,ui
test_spinner() {
  
  ( _IT "should show a spinner and hide the output of the executed command"
  
    testtmp(){
      local i=0
      while [[ $((i++)) -lt 10 ]]; do
        echo -e "line"
        sleep 0.1
      done | _with_spinner
    }
    
    export -f testtmp _with_spinner _spin print_fullsize_hbar
    RES="$(bash -c "testtmp" | wc -l)"

    [[ "$RES" -gt 1 ]] && _FAIL
  )
}


true
