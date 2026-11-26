#!/bin/bash

_require 's/var-utils.sh'
_require 's/utils.sh'
_require 's/pkg.sh'

#TEST:system,lib,pkg
test_pkg() {
#   [ "$XDEV_TEST_ENABLE_SYSTEM_TESTS" = "true" ] || exit 0
  
  ( _IT "should be able to make available a set of well-known executables"

    ENTANDO_ENT_HOME="$PWD/.entando"
    # shellcheck disable=SC2034
    CFG_FILE="$ENTANDO_ENT_HOME/cfg"
    # shellcheck disable=SC2034
    ENTANDO_BINS="$ENTANDO_ENT_HOME/bin"
    mkdir "$ENTANDO_ENT_HOME"

    _pkg_get "jq"
    _pkg_get "fzf"
    _pkg_get "k9s"
    _pkg_get "crane"

    _pkg_jq --version
    _pkg_fzf --version
    _pkg_k9s version  --short
    _ent.pkg run crane version
  )
}

# Prints "<version> <linux url> <darwin url> <windows url> | <run check>" of the given package on the given host
#
_test_pkg_urls() {
  (
    SYS_OS_TYPE="linux"
    SYS_CPU_ARCH="$1"
    _pkg_download_and_install() { echo "$3 $4 $7 ${10} | ${13}"; }
    save_cfg_value() { :; }
    _pkg_get "$2"
  )
}

#TEST:unit,lib,pkg
test_pkg_urls_by_arch() {
  ( _IT "should download the package build for the CPU architecture of the host"

    local gh="https://github.com"
    local u="$gh/stedolan/jq/releases/download/jq-1.6"
    _ASSERT -v "jq x86-64" "$(_test_pkg_urls "x86-64" "jq")" \
      = "1.6 $u/jq-linux64 $u/jq-osx-amd64 $u/jq-win64.exe | --version"
    u="$gh/jqlang/jq/releases/download/jq-1.7.1"
    _ASSERT -v "jq arm64" "$(_test_pkg_urls "arm64" "jq")" \
      = "1.7.1 $u/jq-linux-arm64 $u/jq-macos-arm64 $u/jq-windows-amd64.exe | --version"

    u="$gh/google/go-containerregistry/releases/download/v0.9.0//go-containerregistry"
    _ASSERT -v "crane x86-64" "$(_test_pkg_urls "x86-64" "crane")" \
      = "v0.9.0 ${u}_Linux_x86_64.tar.gz ${u}_Darwin_x86_64.tar.gz ${u}_Windows_x86_64.tar.gz | version"
    _ASSERT -v "crane arm64" "$(_test_pkg_urls "arm64" "crane")" \
      = "v0.9.0 ${u}_Linux_arm64.tar.gz ${u}_Darwin_arm64.tar.gz ${u}_Windows_x86_64.tar.gz | version"

    u="$gh/derailed/k9s/releases/download/v0.32.7//k9s"
    _ASSERT -v "k9s x86-64" "$(_test_pkg_urls "x86-64" "k9s")" \
      = "v0.32.7 ${u}_Linux_amd64.tar.gz ${u}_Darwin_amd64.tar.gz ${u}_Windows_amd64.tar.gz | version --short"
    _ASSERT -v "k9s arm64" "$(_test_pkg_urls "arm64" "k9s")" \
      = "v0.32.7 ${u}_Linux_arm64.tar.gz ${u}_Darwin_arm64.tar.gz ${u}_Windows_amd64.tar.gz | version --short"

    u="$gh/junegunn/fzf/releases/download/0.30.0/fzf-0.30.0"
    _ASSERT -v "fzf x86-64" "$(_test_pkg_urls "x86-64" "fzf")" \
      = "0.30.0 $u-linux_amd64.tar.gz $u-darwin_amd64.zip $u-windows_amd64.zip | --version"
    _ASSERT -v "fzf arm64" "$(_test_pkg_urls "arm64" "fzf")" \
      = "0.30.0 $u-linux_arm64.tar.gz $u-darwin_arm64.zip $u-windows_amd64.zip | --version"
  )
}

#TEST:unit,lib,pkg
test_pkg_runs() {
  ( _IT "should tell whether an executable can run on this host"

    # shellcheck disable=SC2016
    printf '#!/bin/sh\n[ "$1 $2" = "version --short" ]\n' > "good-exe"
    printf 'x' > "bad-exe"
    chmod +x "good-exe" "bad-exe"

    _pkg_runs "./good-exe" "version --short"; _ASSERT_RC 0
    _pkg_runs "./bad-exe" "--version" && _FAIL "a non executable binary was reported as runnable"
    _pkg_runs "./missing-exe" "--version" && _FAIL "a missing binary was reported as runnable"
    _pkg_runs "./bad-exe" ""; _ASSERT_RC 0
  )
}

# Enters a new dir and stubs the download of a package binary with a file having the given content
#
# Params:
# $1  the content of the downloaded binary
#
# the variables set here are read by _pkg_get
# shellcheck disable=SC2034
_test_prepare_pkg_install() {
  __cd "$(mktemp -d "$PWD/pkg-install.XXXXXX")"
  SYS_OS_TYPE="linux"
  SYS_CPU_ARCH="x86-64"
  ENTANDO_BINS="$PWD/bin"
  _TEST_DOWNLOADS="$PWD/downloads.log"
  _TEST_DOWNLOAD_CONTENT="$1"
  : > "$_TEST_DOWNLOADS"
  # stub of: curl -Ls --write-out '%{http_code}' -o <file> <url>
  curl() {
    echo "$6" >> "$_TEST_DOWNLOADS"
    printf '%b' "$_TEST_DOWNLOAD_CONTENT" > "$5"
    echo "200"
  }
  save_cfg_value() { :; }
}

_test_pkg_download_count() {
  wc -l < "$_TEST_DOWNLOADS" | tr -d ' '
}

#TEST:unit,lib,pkg
test_pkg_get_replaces_binaries_that_cannot_run() {
  ( _IT "should replace an installed binary that cannot run on this host"

    _test_prepare_pkg_install '#!/bin/sh\necho jq-1.6\n'

    # eg: an x86-64 binary downloaded on an arm64 host by an older ent
    mkdir -p "$ENTANDO_BINS"
    printf 'x' > "$ENTANDO_BINS/jq.1.6"
    chmod +x "$ENTANDO_BINS/jq.1.6"

    ( _pkg_get "jq" && echo "$JQ_PATH" > "jq-path" ) &>/dev/null; _ASSERT_RC 0
    _ASSERT -v "downloads" "$(_test_pkg_download_count)" = "1"
    _ASSERT -v "path" "$(cat "jq-path")" = "$ENTANDO_BINS/jq.1.6"
    _ASSERT -v "version" "$("$ENTANDO_BINS/jq.1.6" --version)" = "jq-1.6"

    # a binary that runs is reused
    ( _pkg_get "jq" ) &>/dev/null; _ASSERT_RC 0
    _ASSERT -v "downloads after reuse" "$(_test_pkg_download_count)" = "1"
  )
}

#TEST:unit,lib,pkg
test_pkg_get_rejects_downloads_that_cannot_run() {
  ( _IT "should not install a downloaded binary that cannot run on this host"

    _test_prepare_pkg_install 'x'

    ( _pkg_get "jq" ) &>/dev/null && _FAIL "a binary that cannot run was installed"
    [ -e "$ENTANDO_BINS/jq.1.6" ] && _FAIL "the binary that cannot run was left installed"
    true
  )
}

true
