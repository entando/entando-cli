#!/bin/bash

[ -z "$1" ] && {
  echo "Syntax:"
  echo "  - ${0##*/} set-configmap {yaml file} {configmap-file}"
  echo "  - ${0##*/} set-cocoo-version {yaml file} {version}"
  exit 1
} >&2

CMD="$1"
YAML_FILE="$2"

stat "$YAML_FILE" &> /dev/null || { echo "Please provide an existing yaml file" 1>&2 && exit 1; }

case "$CMD" in
  "set-configmap")
    CONFIGMAP_FILE="$3"
    stat "$CONFIGMAP_FILE" &> /dev/null || { echo "Please provide an exiting configmap file" 1>&2 && exit 1; }

    if grep "entando-k8s-controller-coordinator:" "$CONFIGMAP_FILE" &>/dev/null; then
      echo "Warning, the key \"entando-k8s-controller-coordinator\" in configmaps is ignored" 1>&2
    fi

    perl -p0e 's/(.*)apiVersion: v1.*\nkind: ConfigMap.*/\1/msg' "$YAML_FILE"
    cat "$CONFIGMAP_FILE"
    echo -n "---"
    perl -p0e 's/.*apiVersion: v1.*\nkind: ConfigMap.*?^---$//msg' "$YAML_FILE"
    ;;
  "set-cocoo-version")
    VER="$3"
    C="s|"
    C+="(image:\s.*)/entando-k8s-controller-coordinator:.*|"
    C+="\1/entando-k8s-controller-coordinator:$VER|"
    perl -pe "$C" "$YAML_FILE"
    ;;
  *)
    echo "Unknown command \"$CMD\""
    ;;
esac
