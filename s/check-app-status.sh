#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir" 1>&2
  exit
}

# PARAMS

[ -n "$1" ] && ENTANDO_APPNAME="$1" && shift
[ "$ENTANDO_APPNAME" = "" ] && echo "please provide the app name" 1>&2 && exit 1

[ -n "$1" ] && ENTANDO_NAMESPACE="$1" && shift
[ "$ENTANDO_NAMESPACE" = "" ] && echo "please provide the namespace name" 1>&2 && exit 1

# ~~~

start_time="$1"
if [ -n "$start_time" ]; then
  now="$(date -u +%s)"
  elapsed="$((now - start_time))"
  elapsed_mm="$((elapsed / 60))"
  elapsed_ss="$((elapsed - elapsed_mm * 60))"
fi

RUN() {
  # shellcheck disable=SC2015
  $SYS_GNU_LIKE && {
    DISKFREE="$(df . -h | tail -n 1 | awk '{print $4}')"
    MM="$(free -k -t | grep "Mem")"
    MMT="$(echo "$MM" | awk '{print $2}')"
    MMU="$(echo "$MM" | awk '{print $3}')"
    MEMFREE="$(((MMT - MMU) / 1048576))G"
    true
  } || {
    DISKFREE="N/A"
    MEMFREE="N/A"
  }

  local READY=false
  local PODS
  PODS="$(_kubectl get pods -n "$ENTANDO_NAMESPACE" 2>&1)"

  app-get-main-ingresses ENTANDO_URL_SCHEME SVC_INGR ECR_INGR APB_INGR
  
  if $ENTANDO_STANDARD_QUICKSTART; then
    local n=0
    ingr_check "ECR" "$ECR_INGR" && ((n++))
    ingr_check "APB" "$APB_INGR" && ((n++))
    # shellcheck disable=SC2015
    ingr_check "APP" "$SVC_INGR" && ((n++))
    if [ "$n" -ge 3 ]; then
      READY=true
    fi
  else
    local e c
    IFS='/' read -r e c < <(
      echo "$PODS" | grep -- '-server-deployment' | awk '{print $2}'
    )
    [[ -n "$e" && "$e" -eq "$c" ]] && {
      READY=true  
    }
  fi

  if $READY; then
    echo ''
    echo '| '
    echo '|   █████████████████'
    echo '| '
    echo '|         READY      '
    echo '| '
    echo '|   █████████████████'
    echo '| '
    echo '|  The Entando app is ready at the address:'
    echo '| '
    echo -e "|\t${ENTANDO_URL_SCHEME}://${APB_INGR:-???}"
    echo '|'
    true
  else
    echo ''
    echo '| '
    echo '|   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒'
    echo '| '
    echo '|       NOT READY    '
    echo '| '
    echo '|   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒'
    echo '| '
    if [ -n "$start_time" ]; then
      echo -e "|   - Elapsed time:  ${elapsed_mm}m${elapsed_ss}s"
    fi
    echo -e "|   - Free Disk:     $DISKFREE"
    echo -e "|   - Free Mem:      $MEMFREE"
    echo '|'
    true
  fi

  echo -e "\n~~~\n"
  echo "$PODS"
}

ingr_check() {
  local DRY=false
  [ "$1" = "--dry" ] && shift && DRY=true
  ADDR="$2"

  [ -z "$ADDR" ] && {
    echo "> $1 endpoint not registered.. ($2)"
    return 1
  }

  echo -n "> $1 endpoint is registered.."
  LAST_INGR_ADDR_CHECKED="$ENTANDO_URL_SCHEME://$ADDR"

  $DRY && return 0

  http_check "$LAST_INGR_ADDR_CHECKED" || true

  if [ -n "$ADDR" ] && [ "$http_check_res" != "000" ]; then
    echo -n " open.."

    T="\t($ENTANDO_URL_SCHEME://$ADDR)"

    case "$http_check_res" in
      2* | 401) echo -e " AND READY $T" && return 0 ;;
      000 | 4* | 503) echo -e " but not ready ($http_check_res) $T" && return 1 ;;
      5*) echo -e " AND IN ERROR ($http_check_res) $T" && return 1 ;;
      *) echo -e " AND IN UNEXPECTED STATUS ($http_check_res) $T" && return 1 ;;
    esac
  else
    echo " but it's still closed.."
    false
  fi
}

http_check() {
  http_check_res=$(curl --write-out '%{http_code}' --silent --output /dev/null "$1")

  case "$http_check_res" in
    2*) return 0 ;;
    *) return 1 ;;
  esac
}

RUN
