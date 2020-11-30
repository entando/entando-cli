#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# FIND ARG IDX
test_mod_check-env_find_nvm_node() {
  print_current_function_name "> " ".."

  nvm() {
    S=""
    S+="->     v12.18.3"$'\n'
    S+="       v12.18.4"$'\n'
    S+="default -> lts/* (-> N/A)"$'\n'
    S+="node -> stable (-> v12.18.4) (default)"$'\n'
    S+="stable -> 12.18 (-> v12.18.4) (default)"$'\n'
    S+="iojs -> N/A (default)"$'\n'
    S+="lts/* -> lts/fermium (-> N/A)"$'\n'
    S+="lts/argon -> v4.9.1 (-> N/A)"$'\n'
    S+="lts/boron -> v6.17.1 (-> N/A)"$'\n'
    S+="lts/carbon -> v8.17.0 (-> N/A)"$'\n'
    S+="lts/dubnium -> v10.23.0 (-> N/A)"$'\n'
    S+="lts/erbium -> v12.20.0 (-> N/A)"$'\n'
    S+="lts/fermium -> v14.15.1 (-> N/A)"$'\n'
    echo "$S"
  }

  {
    find_nvm_node "RES" "v12.18.3" "v12.18.*" || FATAL "failed! $LINENO"
    [ "$RES" = "v12.18.3" ] || FATAL "failed! $LINENO"
  } > /dev/null

  nvm() {
    S=""
    S+="->     v12.18.3"$'\n'
    S+="       v12.18.4"$'\n'
    S+="default -> lts/* (-> N/A)"$'\n'
    S+="node -> stable (-> v12.18.4) (default)"$'\n'
    S+="stable -> 12.18 (-> v12.18.4) (default)"$'\n'
    S+="iojs -> N/A (default)"$'\n'
    S+="lts/* -> lts/fermium (-> N/A)"$'\n'
    S+="lts/argon -> v4.9.1 (-> N/A)"$'\n'
    S+="lts/boron -> v6.17.1 (-> N/A)"$'\n'
    S+="lts/carbon -> v8.17.0 (-> N/A)"$'\n'
    S+="lts/dubnium -> v10.23.0 (-> N/A)"$'\n'
    S+="lts/erbium -> v12.20.0 (-> N/A)"$'\n'
    echo "$S"
  }

  {
    find_nvm_node "RES" "v12.18.4" "v12.18.*" || FATAL "failed! $LINENO"
    [ "$RES" = "v12.18.4" ] || FATAL "failed! $LINENO"
   } > /dev/null

}

true
