#!/bin/bash
# shellcheck disable=SC2129

[ "$1" = "-h" ] && echo -e "Runs some diagnostic and collects the related info in a tgz file | Syntax: ${0##*/} namespace" && exit 0

NS="$1"
[ "$NS" == "" ] && NS="$ENTANDO_NAMESPACE"
[ "$NS" == "" ] && echo "please provide the namespace name" 1>&2 && exit 1

TT="$PWD/entando-diagdata"
mkdir -p "$TT"
cd "$TT"

#KUBECTL="sudo kubectl"
KUBECTL="${ENT_KUBECTL:-kubectl}"
$KUBECTL get nodes
echo "" >basics.txt

# DNS rebinding protection TEST
echo "## DNS rebinding protection TEST"
echo "## DNS rebinding protection TEST" >>basics.txt
echo "# Test 1:" >>basics.txt 2>&1
dig +short 192.168.1.1.nip.io >>basics.txt 2>&1
echo "# Test 2:" >>basics.txt 2>&1
dig +short 192.168.1.1.nip.io @8.8.8.8 >>basics.txt 2>&1
echo "" >>basics.txt

# Local info
echo "## LOCAL INFO"
echo "## LOCAL INFO" >>basics.txt
echo "# Hostname" >>basics.txt
hostname -I >>basics.txt 2>&1
echo "# OS Info" >>basics.txt
lsb_release -a >>basics.txt 2>/dev/null
cat /etc/os-release >>basics.txt 2>&1
echo "# Routes" >>basics.txt
ip r s >>basics.txt 2>&1

# PODs information collection
echo "## K8S INFO"

for pod in $($KUBECTL get pods -n "$NS" | awk 'NR>1' | awk '{print $1}'); do
  echo "> POD: $pod"
  $KUBECTL describe pods/"$pod" -n "$NS" 1>"$pod.describe.txt" 2>&1
  for co in $($KUBECTL get pods/"$pod" -o jsonpath='{.spec.containers[*].name}{"\n"}' -n "$NS"); do
    echo -e ">\tCONTAINER: $co"
    $KUBECTL logs pods/"$pod" -c "$co" -n "$NS" 1>"$pod-$co.logs.txt" 2>&1
  done
done

echo "> Collected diagdata available under \"./entando-diagdata\" for consultation"

cd ..
set +e
tar cfz entando-diagdata.tgz "entando-diagdata"

echo "> Collected diagdata available into archive \"entando-diagdata.tgz\""
