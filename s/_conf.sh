#!/bin/bash
# shellcheck disable=SC2034

REPO_GENERATOR_JHIPSTER_ENTANDO_ADDR="https://github.com/entando/entando-blueprint/"

# UTILITIES CONFIGURATION
XU_LOG_LEVEL=9

ENTANDO_HOME=$(
  cd "$ENTANDO_ENT_HOME/../../../.." && pwd && exit
  echo "~"
)

ENTANDO_GLOBAL_CFG="$ENTANDO_HOME/.global-cfg"

ENT_WORK_DIR="$ENTANDO_ENT_HOME/w"
CFG_FILE="$ENT_WORK_DIR/.cfg"
ENT_KUBECONF_FILE_PATH="$ENT_WORK_DIR/.kubeconf"

# CONSTS
C_HOSTS_FILE="/etc/hosts"
C_BUNDLE_DESCRIPTOR_FILE_NAME="descriptor.yaml"
C_ENT_PRJ_FILE=".ent-prj"
C_ENT_STATE_FILE=".ent-state"

C_GENERATOR_JHIPSTER_ENTANDO_NAME="generator-jhipster-entando"
C_ENTANDO_BUNDLER_DIR="entando-bundle-tool"
C_ENTANDO_BUNDLER_NAME="entando-bundler"
C_ENTANDO_BUNDLE_BIN_NAME="entando-bundler"
C_QUICKSTART_DEFAULT_RELEASE="quickstart"

C_ENTANDO_LOGO_FILE="res/entando.png"

C_WIN_VM_HOSTNAME_SUFFIX="mshome.net"
C_AUTO_VM_HOSTNAME_SUFFIX="local.entando.org"

# More dynamic configurations

# shellcheck disable=SC1091
{
  [ -f dist/manifest ] && . dist/manifest
  [ -f d/_env ] && . d/_env
  [ -f w/_env ] && . w/_env
  [ -f _env ] && . _env
}
