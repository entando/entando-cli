#!/bin/bash

# shellcheck disable=SC2207
_entando_ent_complete() {
  return 0
  local curr=${COMP_WORDS[COMP_CWORD]}
  local partial="${COMP_WORDS[*]}"
  local line last values

  COMPREPLY=()

  if [ "$COMP_CWORD" -eq 1 ]; then
    values="$(ent help --ent-base-comp)"
  else
    values="$($partial --cmplt)"
  fi

  while IFS= read -r line; do
    last=${#line}; ((last--))
    if [ "${line:$last:1}" = "=" ]; then
      COMPREPLY+=("${line}")
    else
      COMPREPLY+=("${line} ")
    fi
  done < <(compgen -W "$values" -- "$curr")

  return 0
}

export -f _entando_ent_complete
complete -o nosort -o nospace -F _entando_ent_complete ent -o nosort
