#!/usr/bin/zsh

_entando_ent_complete_zsh() {
  local line state last count

  _arguments -C "1: :($(ent --cmplt 2>/dev/null))" "*::arg:->args"

  count="${#line}"
  echo $LINENO: "${line[*]}" >> /tmp/t

  local CMPLTCMD=("ent")
  local i=0
  while [ $i -lt "$count" ]; do
    CMPLTCMD+=("${line[$i]}")
    ((i++))
  done
  CMPLTCMD+=("--cmplt")

  if [[ "$state" == "args" ]]; then
    while IFS= read -r arg; do
      last=${#arg}; ((last--))
      if [ "${arg:$last:1}" = "=" ]; then
        compadd -S '' -- "${arg}"
      else
        compadd -S ' ' -- "${arg}"
      fi
    done < <(${CMPLTCMD[*]} 2>/dev/null)
  fi
  return 0
}

export _entando_ent_complete_zsh
compdef _entando_ent_complete_zsh ent
