#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR/.." || {
  echo "Internal error: unable to find the script source dir" 1>&2
  exit
}

test_check_ver_num() {
  echo "> test_check_ver_num.."

  check_ver_num "1" "*" || FATAL "FAILED $LINENO"
  check_ver_num "1" "1" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" ">1" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" ">=1" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" ">=2" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" ">=3" && FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" "<3" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" "<=3" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" "<=2" || FATAL "FAILED $LINENO"
  check_ver_num_start
  check_ver_num "2" "<=1" && FATAL "FAILED $LINENO"

  function tester() {
    echo "$@"
  }

  function openjdk-test() {
    echo "openjdk version \"1.8.0_265\""
    echo "OpenJDK Runtime Environment (build 1.8.0_265-8u265-b01-0ubuntu2~20.04-b01)"
    echo "OpenJDK 64-Bit Server VM (build 25.265-b01, mixed mode)"
  }

  check_ver "tester" "*.*.*" "11.0.0" || FATAL "FAILED $LINENO"
  check_ver "tester" ">11.*.*" "11.0.0" && FATAL "FAILED $LINENO"
  check_ver "tester" ">=11.*.*" "11.0.0" || FATAL "FAILED $LINENO"
  check_ver "tester" ">11.4.*" "11.4.0" && FATAL "FAILED $LINENO"
  check_ver "tester" ">=11.4.*" "11.3.0" && FATAL "FAILED $LINENO"
  check_ver "tester" ">=11.4.*" "11.4.0" || FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.0.265" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" || FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.0.>=265" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" || FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.0.>265" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" && FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.0.<265" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" && FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.0.265" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" || FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.>=0.265" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" || FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.>=0.264" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" && FATAL "FAILED $LINENO"
  check_ver "openjdk-test" "1.8.>=1.0" "-version | head -n 1 | awk '{gsub(/\"/, \"\", \$3);print \$3}'" && FATAL "FAILED $LINENO"

  echo "> test_check_ver_num: ok"
}
