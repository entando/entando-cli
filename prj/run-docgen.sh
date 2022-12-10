#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC2046
cd "$SCRIPT_DIR/.." || { echo "Unable to enter the script dir"; exit 99; }

RUN() {
  case "$1" in
    macro)  IN="ppl--";;
    high)    IN="ppl-,ppl,_ppl";OUT="ppl--";;
    low)    IN=".*";OUT="ppl-,ppl,_ppl";;
    all)    IN=".*";OUT="";;
  esac

  for label in ${IN//,/ }; do

    # FILE LOOP
    while read -r file; do

      UNDOCUMENTED=""
      
      #LATCHED_FILE_HEADER=$'\n---\n'
      #LATCHED_FILE_HEADER+="# $file"$'\n'
      
      # FUNCTION LOOP
      while read -r fn; do
        _list_contains "$OUT" "$fn" && break
        
        BRIEF=""
        
        DOC="$(
          {
            # LINE LOOP
            first_line=true
            while read -r ln; do
              $first_line && { first_line=false; continue; }
              [ "${ln:0:1}" != "#" ] && break;
              echo "${ln:1}"
            done < <(tac "$file" | grep "$fn()" -A 100)
          } | tac
        )"
        
        if [ -n "$DOC" ]; then
          if [ -n "$LATCHED_FILE_HEADER" ]; then
            echo "$LATCHED_FILE_HEADER"
            LATCHED_FILE_HEADER=""
          fi

          BRIEF="$(head -1 <<<"$DOC" | xargs)"
          DOC="$(tail +2 <<<"$DOC" | sed '1{/^[[:space:]]*$/d}')"
          echo -e "\n---\n"
          echo -e "### \`${fn}()\`\n"
          echo -e "**$BRIEF**\n"
          if [ -n "$DOC" ]; then
            echo "<details>"$'\n'
            echo "\`\`\`"
            echo "$DOC"
            echo "\`\`\`"$'\n'
            echo "</details>"$'\n'
          fi
        else
          UNDOCUMENTED+=" \`$fn\`"
        fi
      
      done < <(grep -- "^$label.*()" "$file" | sed 's/().*//')
      
      #if [  -n "$UNDOCUMENTED" ]; then
      #  echo -e "## undocumented functions:\n"
      #  echo "${UNDOCUMENTED:1}"
      #fi
      
    done  < <(grep -lr -- "^$label.*()" "./macro" "./lib")
    
  done
}

_list_contains() {
  for item in ${1//,/ }; do
    [[ "$2" =~ $item ]] && return 0
  done
  return 1
}

RUN "$@"
