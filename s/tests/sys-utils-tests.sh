#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

test_check_ver_num() {
  print_current_function_name "> " ".."

  {
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

    check_ver "tester" "11.*.*" "11" || FATAL "FAILED $LINENO"
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
    
    check_ver "1.8.1" "1.8.*" "" "string" || FATAL "FAILED $LINENO"
    check_ver "1.8.1" "1.8.>1" "" "string" && FATAL "FAILED $LINENO"
    check_ver "1.8.2" "1.8.>1" "" "string" || FATAL "FAILED $LINENO"
    
    check_ver "6.3.2" "6.3.>=2" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "6.4.0" "6.>3.*" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "7.0.0" ">6.*.*" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "6.3.2-pre" "6.3.>=2" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "6.4.0-pre" "6.>3.*" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "7.0.0-pre" ">6.*.*" "" "string" || FATAL "FAILED $LINENO $?"
    
    check_ver "5.3.2" "4.3.>=2" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "5.4.0" "6.>4.*" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "5.0.0" ">6.*.*" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "5.3.2-pre" "4.3.>=2" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "5.4.0-pre" "6.>4.*" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "5.0.0-pre" ">6.*.*" "" "string" && FATAL "FAILED $LINENO $?"

    check_ver "v6.3.2" "6.3.>=2" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "v6.4.0" "6.>3.*" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "v7.0.0" ">6.*.*" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "v6.3.2-pre" "6.3.>=2" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "v6.4.0-pre" "6.>3.*" "" "string" || FATAL "FAILED $LINENO $?"
    check_ver "v7.0.0-pre" ">6.*.*" "" "string" || FATAL "FAILED $LINENO $?"
    
    check_ver "v5.3.2" "4.3.>=2" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "v5.4.0" "6.>4.*" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "v5.0.0" ">6.*.*" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "v5.3.2-pre" "4.3.>=2" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "v5.4.0-pre" "6.>4.*" "" "string" && FATAL "FAILED $LINENO $?"
    check_ver "v5.0.0-pre" ">6.*.*" "" "string" && FATAL "FAILED $LINENO $?"
  } > /dev/null
}

test_is_ver_ge_ver() {
  print_current_function_name "> " ".."

  # GE
  check_ver_ge "22.44.88" "22.44.88" || FATAL "FAILED $LINENO $?"
  check_ver_ge "22.44.88-pre1" "22.44.88" || FATAL "FAILED $LINENO $?"
  check_ver_ge "22.44.88" "22.44.88-pre2" || FATAL "FAILED $LINENO $?"
  check_ver_ge "22.44.88-pre1" "22.44.88-pre2" || FATAL "FAILED $LINENO $?"
  check_ver_ge "22.44.89" "22.44.88" || FATAL "FAILED $LINENO $?"
  # GE with v
  check_ver_ge "v22.44.88" "22.44.88" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.88-pre1" "22.44.88" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.88" "22.44.88-pre2" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.88-pre1" "22.44.88-pre2" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.89" "22.44.88" || FATAL "FAILED $LINENO $?"
  # GE with v v
  check_ver_ge "v22.44.88" "v22.44.88" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.88-pre1" "v22.44.88" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.88" "v22.44.88-pre2" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.88-pre1" "v22.44.88-pre2" || FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.89" "v22.44.88" || FATAL "FAILED $LINENO $?"
  # NGE
  check_ver_ge "22.44.87" "22.44.88" && FATAL "FAILED $LINENO $?"
  check_ver_ge "22.44.87-pre1" "22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  check_ver_ge "22.43.99" "22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  check_ver_ge "22.4.99" "22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  # NGE with v
  check_ver_ge "v22.44.87" "22.44.88" && FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.87-pre1" "22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.43.99" "22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.4.99" "22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  # NGE with v v
  check_ver_ge "v22.44.87" "v22.44.88" && FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.44.87-pre1" "v22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.43.99" "v22.44.88-pre2" && FATAL "FAILED $LINENO $?"
  check_ver_ge "v22.4.99" "v22.44.88-pre2" && FATAL "FAILED $LINENO $?"
}