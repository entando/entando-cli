#!/bin/bash
# ECR UTILS

#-----------------------------------------------------------------------------------------------------------------------
# Runs general operation to prepare running actions against the ECR
# $1: the received of the url to use for the action
# $2: the received of the authentication token to use for the action
#
ecr-prepare-action() {
  local var_url="$1"
  shift
  local var_token="$1"
  shift
  print_current_profile_info
  # shellcheck disable=SC2034
  local main_ingress ecr_ingress ignored url_scheme
  app-get-main-ingresses url_scheme main_ingress ecr_ingress ignored
  [ -z "$main_ingress" ] && FATAL "Unable to determine the main ingress url (s1)"
  [ -z "$ecr_ingress" ] && FATAL "Unable to determine the ecr ingress url (s1)"
  if [ -n "$url_scheme" ]; then
    main_ingress="$url_scheme://$main_ingress"
  else
    case "$FORCE_URL_SCHEME" in
      "http")
        http-get-working-url main_ingress "http://$main_ingress" "https://$main_ingress"
        ;;
      *)
        http-get-working-url main_ingress "https://$main_ingress" "http://$main_ingress"
        ;;
    esac
  fi
  [ -z "$main_ingress" ] && FATAL "Unable to determine the main ingress url (s2)"
  http-get-url-scheme url_scheme "$main_ingress"
  save_cfg_value LATEST_URL_SCHEME "$url_scheme"
  local token
  keycloak-get-token token "$url_scheme"
  _set_var "$var_url" "$url_scheme://$ecr_ingress"
  _set_var "$var_token" "$token"
}

# Runs an ECR action for a bundle given:
# $1: the received of the of the http status
# $2: the http verb
# $3: the action
# $4: the ingress url
# $5: the authentication token
# $6: the bundle id
#
# returns:
# - the http status in $1
# - the http operation output in stdout
#
ecr-bundle-action() {
  local DEBUG=false; [ "$1" == "--debug" ] && DEBUG=true && shift
  local res_var="$1";shift
  local verb="$1";shift
  local action="$1";shift
  local ingress="$1";shift
  local token="$1";shift
  local bundle_id="$1";shift
  local raw_data="$1";shift
  
  local url
  path-concat url "${ingress}" ""
  url+="components"
  
  local http_status OUT

  [ -n "$bundle_id" ] && url+="/$bundle_id"
  [ -n "$action" ] && url+="/$action"

  local OUT="$(mktemp /tmp/ent-auto-XXXXXXXX)"
  
  # shellcheck disable=SC2155
  if "$DEBUG"; then
      local ERR="$(mktemp /tmp/ent-auto-XXXXXXXX)"
      local STATUS="$(mktemp /tmp/ent-auto-XXXXXXXX)"
      curl --insecure -o "$OUT" -sL -w "%{http_code}\n" -X "$verb" -v "$url" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "Origin: ${ingress}" \
        ${raw_data:+--data-raw "$raw_data"} \
        1> "$STATUS" 2> "$ERR"
      
      # shellcheck disable=SC2155 disable=SC2034
      {
        local T_STATUS="$(cat "$STATUS")"
        local T_OUT="$(cat "$OUT")"
        local T_ERR="$(cat "$ERR")"
        _pp T_STATUS T_OUT T_ERR
      } > /dev/tty
      
    rm "$STATUS" "$ERR" "$OUT"
    return
  else
    http_status=$(
      curl --insecure -o "$OUT" -sL -w "%{http_code}\n" -X "$verb" -v "$url" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $token" \
        -H "Origin: ${ingress}" \
        ${raw_data:+--data-raw "$raw_data"} \
        2> /dev/null
    )
  fi
  
  if [ "$res_var" != "%" ]; then
    if [ "$res_var" != "" ]; then
      _set_var "$res_var" "$http_status"
    fi
  else
    if [ "$http_status" -ge 300 ]; then
      echo "%$http_status"
      return 1
    fi
  fi
  
  if [ -s "$OUT" ]; then
    cat "$OUT"
  else
    if [ "$res_var" = "%" ]; then
      echo "%$http_status"
    fi
  fi
  rm "$OUT"
}

# Runs an ECR action for a bundle given:
# $1: the received of the of the http status
# $2: the http verb
#
ecr-watch-installation-result() {
  local action="$1";shift
  local ingress="$1";shift
  local token="$1";shift
  local bundle_id="$1";shift
  local http_res

  local start_time end_time elapsed
  start_time="$(date -u +%s)"

  echo ""

  while true; do
    http_res=$(
      ecr-bundle-action "%" "GET" "$action" "$ingress" "$token" "$bundle_id"
    )
    
    if [ "${http_res:0:1}" != '%' ]; then
      http_res=$(
        echo "$http_res" | _jq -r ".payload.status" 2> /dev/null
      )
  
      end_time="$(date -u +%s)"
      elapsed="$((end_time - start_time))"
      printf "\r                                  \r"
      printf "%4ds STATUS: %s.." "$elapsed" "$http_res"
    fi

    case "$http_res" in
      "INSTALL_IN_PROGRESS" | "INSTALL_CREATED" | "UNINSTALL_IN_PROGRESS" | "UNINSTALL_CREATED") ;;
      "INSTALL_COMPLETED")
        echo -e "\nTerminated."
        return 0
        ;;
      "UNINSTALL_COMPLETED")
        echo -e "\nTerminated."
        return 0
        ;;
      "INSTALL_ROLLBACK") ;;
      "INSTALL_ERROR")
        echo -e "\nTerminated."
        return 1
        ;;
      %*)
        echo -e "\nTerminated \"$http_res\""
        return 2
        ;;
      *)
        echo ""
        FATAL "Unknown status \"$http_res\""
        return 99
        ;;
    esac
    sleep 3
  done
}

#-----------------------------------------------------------------------------------------------------------------------
# Generates the and EntandoDeBundle CR given:
# $1: the name of the bundle
# $2: the bundle plugin repository address
# $3: the thumbnail file
# $4: the thumbnail url (alternative to $3)
#
ecr.generate-custom-resource() {
  local NAME="$1"
  local REPOSITORY="$2"
  local THUMBNAIL_FILE="$3"
  local THUMBNAIL_URL="$4"
  
  if [ "$THUMBNAIL_FILE" == "<auto>" ]; then
    THUMBNAIL_FILE="$ENTANDO_ENT_HOME/$C_ENTANDO_LOGO_FILE"
  fi
  
  if [ -n "$THUMBNAIL_FILE" ]; then
    OPT="--thumbnail-file"
    OPT_VALUE="$THUMBNAIL_FILE"
  elif [ -n "$THUMBNAIL_URL" ]; then
    OPT="--thumbnail-url"
    OPT_VALUE="$THUMBNAIL_URL"
  fi

  _ent-bundler from-git \
    --dry-run \
    --name "$NAME" \
    --repository "$REPOSITORY" \
    $OPT "$OPT_VALUE"
}
