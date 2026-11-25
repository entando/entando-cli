#!/bin/bash

# Frontend function for pkg module commands
# $1   command
# $..  commond specific args
#
_ent.pkg() {
  bgn_help_parsing ":ENT-PKG" "$@"
  CMD="$1"; shift;

  case "$CMD" in
    "list"|"ls") 
      end_help_parsing
      # shellcheck disable=SC2010
      ls -l "$ENTANDO_BINS" | grep -v "^.*\.tmp$";;
    "get")
      args_or_ask -h "$HH" -a -n -- PKG '1///%sp name of the package' "$@"
      args_or_ask -h "$HH" -n -- VER '--version///%sp version of the package' "$@"
      end_help_parsing
      shift 1
      NONNULL -s PKG
      assert_strict_file_name "PKG" "$PKG" fatal-nst
      _nn VER && assert_acceptable_version_tag "VER" "$VER" fatal-nst
      [ "$PKG" = "ent" ] && _FATAL -s "Denied"
      _pkg_get --verbose "$PKG" "$VER"
      ;;
    "which")
      args_or_ask -h "$HH" -a -n -- PKG '2/strict_file_name//%sp name of the package' "$@"
      end_help_parsing
      shift 1
      end_help_parsing
      _pkg_get_path RES "$PKG"
      echo "$RES"
      ;;
    "run")
      args_or_ask -h "$HH" -a -n -- PKG '1/strict_file_name//%sp name of the package' "$@"
      shift 1

      if type -t "_pkg_$PKG" > /dev/null; then
        "_pkg_$PKG" "$@"
      else
        _pkg_get_path RES "$PKG"
        "$RES" "$@"
      fi
      ;;
    "rm"|"delete")
      args_or_ask -h "$HH" -a -n -- PKG '1/strict_file_name//%sp name of the package' "$@"
      shift 1
      _pkg_get_path --strict RES "$PKG"
      ask "Are you sure?" "n" && rm "$RES"
      ;;
    "--help")
      args_or_ask -h "$HH" -a -n -- CMD '1///%sp command (ls|get|run|which|rm)' "$@"
      end_help_parsing
      ;;
    *)
      simple_cmplt_handler "ls get run which rm"
      [ -n "$CMD" ] && _FATAL "Unknown command \"$CMD\""
      ;;
  esac
}

# Installs a command given its package name and version
#
# Params:
# $1: config var to store the result
# $2: name of the package to install
# $3: version of the package to install
# $4: download url linux
# $5: file name of the executable inside the linux archive
# $6: checksum url linux
# $7: download url darwin
# $8: file name of the executable inside the darwin archive
# $9: checksum url darwin
# $10: download url windows
# $11: file name of the executable inside the windows archive
# $12: checksum url windows
# $13: the arguments (space separated) of a quick non-interactive run used to verify that
#      the executable can run on this host (eg: "--version"); if empty the check is skipped
#
_pkg_download_and_install() {
  local _tmp_resvar="$1" _tmp_name="$2" _tmp_ver="$3" _tmp_runchk="${13}"
  local COMMENT

  case "$SYS_OS_TYPE" in
    "linux") local _tmp_url="$4" _tmp_ext_fn="$5" _tmp_chkurl="$6" EXT="";;
    "darwin") local _tmp_url="$7" _tmp_ext_fn="$8" _tmp_chkurl="$9" EXT="";;
    "windows") local _tmp_url="${10}" _tmp_ext_fn="${11}" _tmp_chkurl="${12}" EXT=".exe";;
  esac

  local RESFILE="$(mktemp /tmp/ent-resfile-XXXXXXXX)"
  touch "$RESFILE"

  (
    mkdir -p "$ENTANDO_BINS"
    __cd "$ENTANDO_BINS"

    local CMD_NAME="$_tmp_name.$_tmp_ver$EXT"

    # a binary that cannot run on this host (eg: an x86-64 one downloaded on arm64 by an older ent) is replaced
    if [ -f "$CMD_NAME" ] && ! _pkg_runs "./$CMD_NAME" "$_tmp_runchk"; then
      _log_w "The installed binary of $_tmp_name \"$_tmp_ver\" cannot run on this host and will be downloaded again"
      rm -f "$CMD_NAME" "$CMD_NAME.sha256"
    fi

    if [ ! -f "$CMD_NAME" ]; then
      _log_i "I don't have the package (\"$_tmp_ver\"). I'll try to download it"
      
      # DOWNLOAD
      _log_i "Downloading $_tmp_name \"$_tmp_ver\""

      RES=$(curl -Ls --write-out '%{http_code}' -o ".download.tmp~" "$_tmp_url")
      [[ "$RES" != "200" ]] && FATAL "Unable to download $_tmp_name from \"$_tmp_url\""
      
      (
        PRE() {
          DD="$PWD"
          TMPDIR="$(mktemp -d /tmp/_ent.pkg-XXXXXXXXXXXXX)"
          # shellcheck disable=SC2064
          trap "[[ \"$TMPDIR\" = *\"/_ent.pkg-\"* ]] && rm -rf \"$TMPDIR\"" exit
          cd "$TMPDIR"
        }
        case "$_tmp_url" in
          *".tar.gz") PRE; tar xfz "$DD/.download.tmp~"; mv "$_tmp_ext_fn" "$DD/.download.tmp~";;
          *".tar") PRE; tar xf "$DD/.download.tmp~"; mv "$_tmp_ext_fn" "$DD/.download.tmp~";;
          *".zip") PRE; unzip "$DD/.download.tmp~"; mv "$_tmp_ext_fn" "$DD/.download.tmp~";;
        esac
      )
      
      if [ -n "$_tmp_chkurl" ]; then
        # DOWNLOAD checksum
        _log_i "Downloading $_tmp_name \"$_tmp_ver\" checksum"
        
        RES=$(curl -Ls --write-out '%{http_code}' -o "$CMD_NAME.sha256" "$_tmp_chkurl")
        
        [[ "$RES" != "200" ]] && {
          #~
          rm "$CMD_NAME.sha256"
          _log_w "Unable to download the $_tmp_name checksum file"
          ask "Should I proceed anyway?" || {
            rm ".download.tmp~"
            FATAL "Quitting"
          }
          _log_w "$_tmp_name checksum verification skipped by the user"
          COMMENT=" but not checked"
        }

        # VERIFY checksum
        [[ -f "$CMD_NAME.sha256" ]] && {
            [ "$(<"$CMD_NAME.sha256")" = "$(echo .download.tmp~ | _sha256sum)" ] || {
            rm ".download.tmp~"
            FATAL "Checksum verification failed, operation interrupted"
          }
          COMMENT=" and checked"
        }
      fi
      
      # FINALIZE THE NAME
      mv ".download.tmp~" "$CMD_NAME"
      chmod +x "$CMD_NAME"
      _pkg_runs "./$CMD_NAME" "$_tmp_runchk" || {
        rm -f "$CMD_NAME" "$CMD_NAME.sha256"
        FATAL "The downloaded $_tmp_name \"$_tmp_ver\" cannot run on this host ($SYS_OS_TYPE/$SYS_CPU_ARCH)"
      }
      _log_i "$_tmp_name \"$_tmp_ver\" downloaded$COMMENT"
    else
      _log_i "I already have the binary for this version of $_tmp_name"
    fi
    
    echo "$PWD/$CMD_NAME" > "$RESFILE"
  ) || exit "$?"
  
  _set_var "$_tmp_resvar" "$(cat "$RESFILE")"
  rm -r "$RESFILE"
}

#  Checks for the presence of a command
#
# Params:
# $1: the command
#
# Options:
# [-m] if provided failing finding the command is fatal
#
_pkg_is_command_available() {
  local MANDATORY=false;[ "$1" = "-m" ] && { MANDATORY=true; shift; }
  command -v "$1" >/dev/null || { "$MANDATORY" && _FATAL "Unable to find required command \"$1\""; }
  return 0
}

# Tells if the given executable can run on this host
#
# Params:
# $1: the executable
# $2: the arguments (space separated) of a quick non-interactive run; if empty the check is skipped
#
_pkg_runs() {
  [ -z "$2" ] && return 0
  # shellcheck disable=SC2086
  "$1" $2 &>/dev/null </dev/null
}

# Downloads (if needed) a well-known package and saves its path in the config var of the package
#
# On arm64 Linux and macOS the native arm64 build is used.
# On arm64 Windows the x64 build is used, through the OS emulation.
#
# Params:
# $1: the package name (jq|k9s|crane|fzf)
# $2: the package version (optional)
#
_pkg_get() {
  local VERBOSE=false;[ "$1" = "--verbose" ] && { VERBOSE=true;shift; }
  local pkg="$1" ver="$2" var="" url=""
  local arm64=false;[ "$SYS_CPU_ARCH" = "arm64" ] && arm64=true
  case "$pkg" in
    jq)
      var="JQ_PATH"
      if $arm64; then
        # jq < 1.7 has no arm64 build
        ver="${ver:-1.7.1}";url="https://github.com/jqlang/jq/releases/download/jq-$ver"
        _pkg_download_and_install "$var" "jq" "$ver" \
          "$url/jq-linux-arm64" "jq-linux-arm64" "" \
          "$url/jq-macos-arm64" "jq-macos-arm64" "" \
          "$url/jq-windows-amd64.exe" "jq-windows-amd64.exe" "" \
          "--version";
      else
        ver="${ver:-1.6}";url="https://github.com/stedolan/jq/releases/download/jq-$ver"
        _pkg_download_and_install "$var" "jq" "$ver" \
          "$url/jq-linux64" "jq-linux64" "" \
          "$url/jq-osx-amd64" "jq-osx-amd64" "" \
          "$url/jq-win64.exe" "jq-win64.exe" "" \
          "--version";
      fi
      ;;
    k9s)
      var="K9S_PATH";ver="${ver:-v0.32.7}";url="https://github.com/derailed/k9s/releases/download/$ver/"
      local k9s_arch="amd64";$arm64 && k9s_arch="arm64"
      _pkg_download_and_install "$var" "k9s" "$ver" \
        "$url/k9s_Linux_$k9s_arch.tar.gz" "k9s" "" \
        "$url/k9s_Darwin_$k9s_arch.tar.gz" "k9s" "" \
        "$url/k9s_Windows_amd64.tar.gz" "k9s.exe" "" \
        "version --short";
      ;;
    crane)
      var="CRANE_PATH";ver="${ver:-v0.9.0}";url="https://github.com/google/go-containerregistry/releases/download/$ver/"
      local crane_arch="x86_64";$arm64 && crane_arch="arm64"
      _pkg_download_and_install "$var" "crane" "$ver" \
        "$url/go-containerregistry_Linux_$crane_arch.tar.gz" "crane" "" \
        "$url/go-containerregistry_Darwin_$crane_arch.tar.gz" "crane" "" \
        "$url/go-containerregistry_Windows_x86_64.tar.gz" "crane.exe" "" \
        "version";
      ;;
    fzf)
      var="FZF_PATH";ver="${ver:-0.30.0}";url="https://github.com/junegunn/fzf/releases/download/$ver"
      local fzf_arch="amd64";$arm64 && fzf_arch="arm64"
      _pkg_download_and_install "$var" "fzf" "$ver" \
        "$url/fzf-$ver-linux_$fzf_arch.tar.gz" "fzf" "" \
        "$url/fzf-$ver-darwin_$fzf_arch.zip" "fzf" "" \
        "$url/fzf-$ver-windows_amd64.zip" "fzf.exe" "" \
        "--version";
      ;;
    *)
      _FATAL -s "Unknown package \"$pkg\""
      ;;
  esac
  
  [ -n "$var" ] && {
    $VERBOSE && {
      _log_i "Config var: ${var}"
      _log_i "Location: ${!var}"
    }
    save_cfg_value "$var" "${!var}" "$ENT_DEFAULT_CFG_FILE"
  }
}


_pkg_jq() {
  local RC SOE=false;[ "$1" == "--soe" ] && { SOE=true; shift; }
  local CMD; _pkg_get_path --strict CMD "jq"
  "$CMD" "$@"; RC="$?"
  "$SOE" && _FATAL "jq error detected (RC=$RC)"
  return "$RC"
}

_pkg_ok() {
  local CMD; _pkg_get_path --strict CMD "$1"
  test -n "$CMD"
}

_pkg_k9s() {
  local CMD; _pkg_get_path --strict CMD "k9s"
  if [ "$1" == "--direct" ]; then
    shift
    SYS_CLI_PRE "$CMD" "$@"
  else
    if _nn DESIGNATED_KUBECTX; then
      SYS_CLI_PRE "$CMD" "$@" --context="$DESIGNATED_KUBECTX" --namespace="$ENTANDO_NAMESPACE"
    elif _nn DESIGNATED_KUBECONFIG; then
      stdin_to_arr $'\n\r' ARR < <(yq '.contexts[].name' < "$DESIGNATED_KUBECONFIG")
      select_one -s "CONTEXT" "${ARR[@]}"
      # shellcheck disable=2154
      SELECTED_CONTEXT="$select_one_res_alt"
      SYS_CLI_PRE "$CMD" "$@" \
        --kubeconfig="$DESIGNATED_KUBECONFIG" \
        --context="$SELECTED_CONTEXT" \
        --namespace="$ENTANDO_NAMESPACE"
    else
      SYS_CLI_PRE "$CMD" "$@" --namespace="$ENTANDO_NAMESPACE"
    fi
  fi
}

_pkg_fzf() {
  local CMD; _pkg_get_path CMD "fzf"
  "$CMD" "$@"
}

_pkg_get_path() {
  local STRICT=false;[ "$1" = "--strict" ] && { STRICT=true;shift; }
  local _tmp_PKGPATH="$(_upper "${2}_PATH")"
  _tmp_PKGPATH="${!_tmp_PKGPATH}"
  if command -v "$_tmp_PKGPATH" &> /dev/null; then
    _set_or_print "$1" "$_tmp_PKGPATH"
    return 0
  elif command -v "$2" &> /dev/null; then
    ! $STRICT && {
      _set_or_print "$1" "$(command -v "$2")"
      return 0
    }
  fi
  _FATAL -S 1 "Package \"$2\" not found" 1>&2
}
