#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 "$OPT" && pwd)"


test_asserters() {
  print_current_function_name "> " ".."

  OPT="silent"

  assert_strict_id "STRICT ID" "object" "$OPT" || FATAL "failed! $LINENO"
  assert_strict_id "STRICT ID" "my_object" "$OPT" && FATAL "failed! $LINENO"
  assert_strict_id "STRICT ID" "my-object" "$OPT" && FATAL "failed! $LINENO"
  assert_strict_id "STRICT ID" "myObject" "$OPT" || FATAL "failed! $LINENO"
  assert_strict_id "STRICT ID" "MyObject" "$OPT" && FATAL "failed! $LINENO"
  assert_strict_id "STRICT ID" "my object" "$OPT" && FATAL "failed! $LINENO"
  assert_strict_id "STRICT ID" "my.Object" "$OPT" && FATAL "failed! $LINENO"

  assert_id "ID" "object" "$OPT" || FATAL "failed! $LINENO"
  assert_id "ID" "my_object" "$OPT" || FATAL "failed! $LINENO"
  assert_id "ID" "my-object" "$OPT" && FATAL "failed! $LINENO"
  assert_id "ID" "myObject" "$OPT" || FATAL "failed! $LINENO"
  assert_id "ID" "MyObject" "$OPT" && FATAL "failed! $LINENO"
  assert_id "ID" "my object" "$OPT" && FATAL "failed! $LINENO"
  assert_id "ID" "my.Object" "$OPT" && FATAL "failed! $LINENO"

  assert_spc_id "SPC ID" "object" "$OPT" || FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "my_object" "$OPT" || FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "my-object" "$OPT" && FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "myObject" "$OPT" || FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "MyObject" "$OPT" || FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "my object" "$OPT" || FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "My Object" "$OPT" || FATAL "failed! $LINENO"
  assert_spc_id "SPC ID" "my.Object" "$OPT" && FATAL "failed! $LINENO"

  assert_ext_ic_id_spc "IC ID SPC" "My Object" "$OPT" || FATAL "failed! $LINENO"
  assert_ext_ic_id_spc "IC ID SPC" "My-Object" "$OPT" || FATAL "failed! $LINENO"
  assert_ext_ic_id_spc "IC ID SPC" "My- Object" "$OPT" || FATAL "failed! $LINENO"

  assert_dn "DN" "domain" "$OPT" || FATAL "failed! $LINENO"
  assert_dn "DN" "domai@n" "$OPT" && FATAL "failed! $LINENO"
  assert_dn "DN" "domain?" "$OPT" && FATAL "failed! $LINENO"
  assert_dn "DN" "domain99" "$OPT" || FATAL "failed! $LINENO"
  assert_dn "DN" "my_domain" "$OPT" || FATAL "failed! $LINENO"
  assert_dn "DN" "my-domain" "$OPT" || FATAL "failed! $LINENO"
  assert_dn "DN" "mydomain.example.com" "$OPT" && FATAL "failed! $LINENO"
  assert_dn "DN" "myDomain" "$OPT" && FATAL "failed! $LINENO"
  assert_dn "DN" "MyDomain" "$OPT" && FATAL "failed! $LINENO"
  assert_dn "DN" "my domain" "$OPT" && FATAL "failed! $LINENO"
  assert_dn "DN" "my.Domain" "$OPT" && FATAL "failed! $LINENO"

  assert_fdn "FDN" "domain" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "d@omain" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "domain?" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "domain99" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "my_domain" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "my-domain" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "mydomain.example.com" "$OPT" || FATAL "failed! $LINENO"
  assert_fdn "FDN" "my-d_omain.example.com" "$OPT" || FATAL "failed! $LINENO"
  assert_fdn "FDN" "myDomain.example.com" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "myDomain.example.com" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "MyDomain.example.com" "$OPT" && FATAL "failed! $LINENO"
  assert_fdn "FDN" "my domain.example.com" "$OPT" && FATAL "failed! $LINENO"

  assert_url "URL" "domain" "$OPT" && FATAL "failed! $LINENO"
  assert_url "URL" "http://example.com" "$OPT" || FATAL "failed! $LINENO"
  assert_url "URL" "http://example.com?q=1#f" "$OPT" || FATAL "failed! $LINENO"

  assert_email "MAIL" "domain" "$OPT" && FATAL "failed! $LINENO"
  assert_email "MAIL" "domain@example.com" "$OPT" || FATAL "failed! $LINENO"
  assert_email "MAIL" "asb.s@example.com" "$OPT" || FATAL "failed! $LINENO"
  assert_email "MAIL" "asb.s@an.example.com" "$OPT" || FATAL "failed! $LINENO"
  assert_email "MAIL" ".s@example.com" "$OPT" && FATAL "failed! $LINENO"

  assert_ip "IP" "192.168.0.1" "$OPT" || FATAL "failed! $LINENO"
  assert_ip "IP" "" "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" "...." "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" ".168.1.0" "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" "192.168..0" "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" "192.168.0." "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" "192.168.0" "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" "192.168.0.a1" "$OPT" && FATAL "failed! $LINENO"
  assert_ip "IP" "192.168a.0.1" "$OPT" && FATAL "failed! $LINENO"

  assert_ver "VER" "0.0.1" "$OPT" || FATAL "failed! $LINENO"
  assert_ver "VER" "0.0.1-SNAPSHOT" "$OPT" || FATAL "failed! $LINENO"
  assert_ver "VER" "0.0.1-SNAPSHOT-2" "$OPT" || FATAL "failed! $LINENO"
  assert_ver "VER" "0.1-SNAPSHOT" "$OPT" || FATAL "failed! $LINENO"
  assert_ver "VER" "1-SNAPSHOT" "$OPT" || FATAL "failed! $LINENO"
  assert_ver "VER" "0.0.1+SNAPSHOT" "$OPT" && FATAL "failed! $LINENO"
  assert_ver "VER" "0.0.1:2" "$OPT" && FATAL "failed! $LINENO"
  assert_ver "VER" "0.0.1_3" "$OPT" && FATAL "failed! $LINENO"
  assert_ver "VER" "v0.0.1" "$OPT" || FATAL "failed! $LINENO"

  assert_giga "VER" "10G" "$OPT" || FATAL "failed! $LINENO"
  assert_giga "VER" "10GG" "$OPT" && FATAL "failed! $LINENO"
  assert_giga "VER" "10" "$OPT" && FATAL "failed! $LINENO"
  
  # Bundle SEMVER
  # .. accepted bundle semver
  assert_semver "SEMVER" "0.0.1" "$OPT" || FATAL "failed! $LINENO"
  assert_semver "SEMVER" "0.0.1-SNAPSHOT" "$OPT" || FATAL "failed! $LINENO"
  assert_semver "SEMVER" "v0.0.1" "$OPT" || FATAL "failed! $LINENO"
  assert_semver "SEMVER" "v0.0.1-SNAPSHOT" "$OPT" || FATAL "failed! $LINENO"
  # .. ver but not bundle semver
  assert_semver "SEMVER" "1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "0.0.0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "v1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "v0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "v0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "v0.0.0.1" "$OPT" && FATAL "failed! $LINENO"
  # .. corrupted bundle semver
  assert_semver "SEMVER" "v.0.0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "x0.0.1" "$OPT" && FATAL "failed! $LINENO"
  assert_semver "SEMVER" "0.0.1-" "$OPT" && FATAL "failed! $LINENO"
}

test_map_functions() {
    print_current_function_name "> " ".."
    map-clear REMOTES
    map-save REMOTES
    map-count REMOTES N
    [ "$N" = 0 ] || FATAL "failed! $LINENO"
    map-set REMOTES "test" "a-test"
    map-set REMOTES "test2" "another test"
    map-count REMOTES N
    [ "$N" = 2 ] || FATAL "failed! $LINENO"
    map-save REMOTES
    map-clear REMOTES
    reload_cfg
    map-count REMOTES N
    [ "$N" = 2 ] || FATAL "failed! $LINENO"
    map-get REMOTES V "test"
    [ "$V" = "a-test" ] || FATAL "failed! $LINENO"
    map-get REMOTES V "test2"
    [ "$V" = "another test" ] || FATAL "failed! $LINENO"
}

true