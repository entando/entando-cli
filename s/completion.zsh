#!/usr/bin/zsh

_entando_ent_complete_zsh() {
  local line state last count

  _arguments -C "1: :($(ent --cmplt 2>/dev/null))" "*::arg:->args"

  count="${#line}"

  local query=("ent")
  local i=0 V
  while [ $i -lt "$count" ]; do
    V="${line[$i]}"
    query+=("$V")
    if [ "$V" = "--AND" ]; then
      query=("ent")
    fi
    ((i++))
  done
  query+=("--cmplt")

  if [[ "$state" == "args" ]]; then
    while IFS= read -r arg; do
      last=${#arg}; ((last--))
      if [ "${arg:$last:1}" = "=" ]; then
        compadd -S '' -- "${arg}"
      else
        compadd -S ' ' -- "${arg}"
      fi
    done < <(${query[*]} 2>/dev/null)
  fi
  return 0
}

export _entando_ent_complete_zsh
compdef _entando_ent_complete_zsh ent
