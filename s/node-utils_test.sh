#!/bin/bash

_require 's/var-utils.sh'
_require 's/utils.sh'
_require 's/node-utils.sh'

# Stubs "uname" and "sysctl" to simulate a host
#
# Params:
# $1  the "uname -m" output
# $2  the "uname -s" output
# $3  the "sysctl -n hw.optional.arm64" output ("" for a missing key)
#
_test_simulate_host() {
  _TEST_UNAME_M="$1"
  _TEST_UNAME_S="$2"
  _TEST_SYSCTL_ARM64="$3"
  uname() { if [ "$1" = "-s" ]; then echo "$_TEST_UNAME_S"; else echo "$_TEST_UNAME_M"; fi; }
  sysctl() { [ -n "$_TEST_SYSCTL_ARM64" ] && echo "$_TEST_SYSCTL_ARM64"; }
}

# Resolves the node download arch for the given host and prints "<rc> <arch>"
#
_test_resolve_dist_arch() {
  (
    SYS_OS_TYPE="$1"
    SYS_CPU_ARCH="$2"
    ENT_NODE_DIST_ARCH=""
    node.resolve_dist_arch "$3" &>/dev/null
    echo "$? $ENT_NODE_DIST_ARCH"
  )
}

#TEST:unit,lib,node
test_sys_detect_cpu_arch() {
  ( _IT "should detect the real CPU architecture of the host"

    _test_simulate_host "x86_64" "Linux" ""
    _ASSERT -v "linux x86_64" "$(_sys_detect_cpu_arch)" = "x86-64"

    _test_simulate_host "aarch64" "Linux" ""
    _ASSERT -v "linux aarch64" "$(_sys_detect_cpu_arch)" = "arm64"

    _test_simulate_host "i686" "Linux" ""
    _ASSERT -v "linux i686" "$(_sys_detect_cpu_arch)" = "x86"

    _test_simulate_host "arm64" "Darwin" "1"
    _ASSERT -v "apple silicon" "$(_sys_detect_cpu_arch)" = "arm64"

    _test_simulate_host "x86_64" "Darwin" "1"
    _ASSERT -v "apple silicon from a shell running under rosetta" "$(_sys_detect_cpu_arch)" = "arm64"

    _test_simulate_host "x86_64" "Darwin" ""
    _ASSERT -v "intel mac" "$(_sys_detect_cpu_arch)" = "x86-64"

    _test_simulate_host "x86_64" "MINGW64_NT-10.0" ""
    _ASSERT -v "windows git bash" "$(_sys_detect_cpu_arch)" = "x86-64"
  )
}

#TEST:unit,lib,node
test_node_resolve_dist_arch() {
  ( _IT "should choose the node build that runs on the host"

    arch() { true; }   # rosetta available

    _ASSERT -v "linux x64" "$(_test_resolve_dist_arch "linux" "x86-64" "v14.20.0")" = "0 x64"
    _ASSERT -v "intel mac" "$(_test_resolve_dist_arch "darwin" "x86-64" "v14.20.0")" = "0 x64"
    _ASSERT -v "windows x64" "$(_test_resolve_dist_arch "windows" "x86-64" "v14.20.0")" = "0 x64"
    _ASSERT -v "linux arm64" "$(_test_resolve_dist_arch "linux" "arm64" "v14.20.0")" = "0 arm64"
    _ASSERT -v "apple silicon node 14" "$(_test_resolve_dist_arch "darwin" "arm64" "v14.20.0")" = "0 x64"
    _ASSERT -v "apple silicon node 16" "$(_test_resolve_dist_arch "darwin" "arm64" "v16.0.0")" = "0 arm64"
    _ASSERT -v "apple silicon node 20" "$(_test_resolve_dist_arch "darwin" "arm64" "v20.11.0")" = "0 arm64"
    _ASSERT -v "windows on arm node 14" "$(_test_resolve_dist_arch "windows" "arm64" "v14.20.0")" = "0 x64"
    _ASSERT -v "windows on arm node 20" "$(_test_resolve_dist_arch "windows" "arm64" "v20.11.0")" = "0 arm64"
    _ASSERT -v "unparsable version" "$(_test_resolve_dist_arch "darwin" "arm64" "lts")" = "0 x64"
  )
}

#TEST:unit,lib,node
test_node_require_rosetta() {
  ( _IT "should require rosetta 2 for node 14 on apple silicon"

    _TEST_ROSETTA=false
    _TEST_SWUPDATE_CALLS=0
    arch() { "$_TEST_ROSETTA"; }
    softwareupdate() { _TEST_SWUPDATE_CALLS=$((_TEST_SWUPDATE_CALLS+1)); _TEST_ROSETTA="$_TEST_SWUPDATE_RESULT"; "$_TEST_SWUPDATE_RESULT"; }
    _sudo() { "$@"; }

    # declined
    ask() { return 1; }
    _ASSERT -v "declined" "$(_test_resolve_dist_arch "darwin" "arm64" "v14.20.0")" = "1 arm64"

    # accepted, installation fails (also through sudo)
    ask() { return 0; }
    _TEST_SWUPDATE_RESULT=false
    _ASSERT -v "install failed" "$(_test_resolve_dist_arch "darwin" "arm64" "v14.20.0")" = "1 arm64"

    # accepted, installation succeeds
    _TEST_SWUPDATE_RESULT=true
    _ASSERT -v "installed" "$(_test_resolve_dist_arch "darwin" "arm64" "v14.20.0")" = "0 x64"

    # not asked when rosetta is already there, nor for a node with a native build
    ask() { _FAIL "unexpected question"; }
    _TEST_ROSETTA=true
    _ASSERT -v "already installed" "$(_test_resolve_dist_arch "darwin" "arm64" "v14.20.0")" = "0 x64"
    _TEST_ROSETTA=false
    _ASSERT -v "native node" "$(_test_resolve_dist_arch "darwin" "arm64" "v20.11.0")" = "0 arm64"
  )
}

#TEST:unit,lib,node
test_node_runs() {
  ( _IT "should tell whether a node installation can run"

    SYS_OS_TYPE="linux"
    mkdir -p "good/bin" "bad/bin"
    printf '#!/bin/sh\necho v14.20.0\n' > "good/bin/node"
    chmod +x "good/bin/node"
    printf 'x' > "bad/bin/node"

    node.runs "good"; _ASSERT_RC 0
    node.runs "bad" && _FAIL "a non executable node was reported as runnable"
    node.runs "missing" && _FAIL "a missing node was reported as runnable"
    true
  )
}

# Enters a new dir, prepares a fake node.js distribution in it and stubs everything
# node.install-node needs but the download and the extraction
#
# Params:
# $1  the content of the fake bin/node
#
# the variables set here are read by node.install-node
# shellcheck disable=SC2034
_test_prepare_node_install() {
  # the test work dir is shared by the tests of a file: every installation gets its own dir
  __cd "$(mktemp -d "$PWD/node-install.XXXXXX")"
  SYS_OS_TYPE="linux"
  SYS_CPU_ARCH="x86-64"
  C_DEF_ARCHIVE_FORMAT="tar.gz"
  URL_NODE_JS_DIST_ADDR="https://example.com/{NODE_VER}/node-{NODE_VER}-{OS}-{ARCH}.{EXT}"
  ENT_OPTS="$PWD/opt"
  mkdir -p "$ENT_OPTS" "dist/node-v14.20.0-linux-x64/bin"
  printf '%b' "$1" > "dist/node-v14.20.0-linux-x64/bin/node"
  printf '#!/bin/sh\necho 6.14.17\n' > "dist/node-v14.20.0-linux-x64/bin/npm"
  chmod +x "dist/node-v14.20.0-linux-x64/bin/node" "dist/node-v14.20.0-linux-x64/bin/npm"
  tar czf "dist/node.tar.gz" -C "dist" "node-v14.20.0-linux-x64"

  _TEST_DOWNLOADS="$PWD/downloads.log"
  : > "$_TEST_DOWNLOADS"
  _TEST_DOWNLOAD_FAILS=false
  _TEST_TGZ="$PWD/dist/node.tar.gz"
  curl() {
    echo "$2" >> "$_TEST_DOWNLOADS"
    "$_TEST_DOWNLOAD_FAILS" && return 22
    cat "$_TEST_TGZ"
  }
  save_cfg_value() { :; }
  reload_cfg() { ENT_NODE_VER="v14.20.0"; }
  _ent-npm-init-rc() { :; }
}

_test_download_count() {
  wc -l < "$_TEST_DOWNLOADS" | tr -d ' '
}

#TEST:unit,lib,node
test_node_install_node() {
  ( _IT "should install a node that runs and reuse it afterwards"

    _test_prepare_node_install '#!/bin/sh\necho v14.20.0\n'

    ( node.install-node "v14.20.0" ) &>/dev/null; _ASSERT_RC 0
    _ASSERT -v "downloaded url" "$(cat "$_TEST_DOWNLOADS")" \
      = "https://example.com/v14.20.0/node-v14.20.0-linux-x64.tar.gz"
    [ -f "opt/node-v14.20.0/.entando-finalized" ] || _FAIL "installation not finalized"

    ( node.install-node "v14.20.0" ) &>/dev/null; _ASSERT_RC 0
    _ASSERT -v "downloads after reuse" "$(_test_download_count)" = "1"
  )
}

#TEST:unit,lib,node
test_node_install_node_repairs_broken_installation() {
  ( _IT "should reinstall a finalized node that cannot run"

    _test_prepare_node_install '#!/bin/sh\necho v14.20.0\n'
    ( node.install-node "v14.20.0" ) &>/dev/null; _ASSERT_RC 0

    printf 'x' > "opt/node-v14.20.0/bin/node"

    ( node.install-node "v14.20.0" ) &>/dev/null; _ASSERT_RC 0
    _ASSERT -v "downloads" "$(_test_download_count)" = "2"
    opt/node-v14.20.0/bin/node --version &>/dev/null || _FAIL "the node binary was not repaired"
  )
}

#TEST:unit,lib,node
test_node_install_node_failures() {
  ( _IT "should fail without finalizing when the download fails or node cannot run"

    _test_prepare_node_install '#!/bin/sh\necho v14.20.0\n'
    _TEST_DOWNLOAD_FAILS=true
    ( node.install-node "v14.20.0" ) &>/dev/null; _ASSERT_RC 1
    [ -e "opt/node-v14.20.0" ] && _FAIL "a failed download left an installation behind"

    _test_prepare_node_install '#!/bin/sh\nexit 86\n'
    ( node.install-node "v14.20.0" ) &>/dev/null; _ASSERT_RC 1
    [ -e "opt/node-v14.20.0" ] && _FAIL "a node that cannot run was left installed"
    true
  )
}

true
