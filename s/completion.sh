#!/bin/bash

if [ "$(cut -d '.' -f 1 <<<"$BASH_VERSION")" -ge 4 ]; then

  # shellcheck disable=SC2207
  _entando_ent_complete() {
    local curr=${COMP_WORDS[COMP_CWORD]}
    local partial="${COMP_WORDS[*]}" query=""
    local line last values
    if [ "$COMP_CWORD" -gt 1 ]; then
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
        query=""
        local i=0
        local V
        while [ $i -lt "$COMP_CWORD" ]; do
          V="${COMP_WORDS[$i]}"
          query+="${V} "
          if [ "$V" = "--AND" ]; then
            query="ent "
          fi
          ((i++))
        done
      fi
    fi

    if [ -z "$query" ]; then
      values="$(ent --cmplt 2>/dev/null)"
    else
      values="$($query --cmplt 2>/dev/null)"
    fi

    COMPREPLY=()
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

fi