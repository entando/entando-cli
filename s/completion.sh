#!/bin/bash

# shellcheck disable=SC2207
_entando_ent_complete() {
  local curr=${COMP_WORDS[COMP_CWORD]}
  local partial="${COMP_WORDS[*]}"
  local line last values

  COMPREPLY=()

  if [ "$COMP_CWORD" -eq 1 ]; then
    values="$(ent --cmplt 2>/dev/null)"
  else
    if [ -n "$partial" ]; then
      last=${#partial}
      ((last--))

      case "${partial:$last:1}" in
        " ") partial=${partial:0:$last} ;;
        "=") ;;
        *) IS_STUB=true ;;
      esac
    fi

    if $IS_STUB; then
      partial=""
      local i=0
      while [ $i -lt "$COMP_CWORD" ]; do
        partial+="${COMP_WORDS[$i]} "
        ((i++))
      done
    fi

    values="$($partial --cmplt 2>/dev/null)"
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
