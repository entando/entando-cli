#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh

set -e
[ "$1" == "force" ] && {
  [ -d "d/crd" ] && rm -rf "d/crd"
  [ -f "d/$DEPL_SPEC_YAML_FILE.tpl" ] && rm "d/$DEPL_SPEC_YAML_FILE.tpl"
  shift
}

reload_cfg

# CHECKS
CURRENT_HELM_VERSION=$(helm version --client | sed 's/.*SemVer:"\([^"]*\)".*/\1/')
[[ ! "$CURRENT_HELM_VERSION" =~ $REQUIRED_HELM_VERSION_REGEX ]] && echo "> FATAL: Found helm version $CURRENT_HELM_VERSION, required: $REQUIRED_HELM_VERSION_REGEX" 1>&2 && exit

# CUSTOM MODEL
cp -i -r "w/hqs/$REPO_CUSTOM_MODEL_DIR/src/main/resources/crd/" "d"

# SPECIFICATION FOR OPENSHIFT
cd "w/hqs/$REPO_QUICKSTART_DIR"

cat values.yaml.tpl |
  sed "s/supportOpenshift:.*$/supportOpenshift: true/" |
  sed "s/name:.*/name: ##ENTANDO_APPNAME##/" \
    >values.yaml

helm template "PLACEHOLDER_ENTANDO_APPNAME" --namespace="PLACEHOLDER_ENTANDO_NAMESPACE" ./ >"$DEPL_SPEC_YAML_FILE"

cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}
mv "w/hqs/$REPO_QUICKSTART_DIR/$DEPL_SPEC_YAML_FILE" "d/$DEPL_SPEC_YAML_FILE.OKD.tpl"

# SPECIFICATION NON-OPENSHIFT
cd "w/hqs/$REPO_QUICKSTART_DIR"

cat values.yaml.tpl |
  sed "s/supportOpenshift:.*$/supportOpenshift: false/" |
  sed "s/name:.*/name: PLACEHOLDER_ENTANDO_APPNAME/" \
    >values.yaml

helm template "PLACEHOLDER_ENTANDO_APPNAME" --namespace="PLACEHOLDER_ENTANDO_NAMESPACE" ./ >"$DEPL_SPEC_YAML_FILE"

cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}
mv "w/hqs/$REPO_QUICKSTART_DIR/$DEPL_SPEC_YAML_FILE" "d/$DEPL_SPEC_YAML_FILE.tpl"
