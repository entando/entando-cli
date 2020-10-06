#!/bin/bash

[ "$1" = "-h" ] && echo -e "Helps in having help | Syntax: ${0##*/}" && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir"
  exit
}

. s/_base.sh

echo ""
echo "~~~~~~~~~~~~~~~~~~~"
echo " Entando CLI tools "
echo "~~~~~~~~~~~~~~~~~~~"
echo ""

echo "> Essentials:"

echo -e "  - Activate using:  $PWD/activate"
echo -e "  - Dectivate using: $PWD/deactivate"
echo ""

echo "> Available tools:"

printf "" 1>/dev/null 2>&1
[ $? -eq 0 ] && PRINTF_AVAILABLE=true || PRINTF_AVAILABLE=false

cd bin
for file in *.sh; do
  H=$($file -h)
  $PRINTF_AVAILABLE &&
    printf "  - %-20s => %s\n" "$file" "$H" ||
    echo -e "  - $file => $H"
done

cd ..

echo ""
echo "> Further info about entando:"
echo -e "  - $PWD/README.md"
echo -e "  - https://www.entando.com/"
echo -e "  - https://dev.entando.org/"

echo ""
echo "> ⚠ RECOMMENDED FIRST STEP ⚠ :"

echo -e "  - Check the dependencies (ent-check-env.sh -h full-help)"

echo ""