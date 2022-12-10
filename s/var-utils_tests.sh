#!/bin/bash

_require 's/var-utils.sh'
_require 's/utils.sh'

#TEST:unit,lib,assert
test_asserters() {
  OPT="silent"
  
  ( _IT "should assert for invalid strict id"

    assert_strict_id "STRICT ID" "object" "$OPT" || _FAIL
    assert_strict_id "STRICT ID" "my_object" "$OPT" && _FAIL
    assert_strict_id "STRICT ID" "my-object" "$OPT" && _FAIL
    assert_strict_id "STRICT ID" "myObject" "$OPT" || _FAIL
    assert_strict_id "STRICT ID" "MyObject" "$OPT" && _FAIL
    assert_strict_id "STRICT ID" "my object" "$OPT" && _FAIL
    assert_strict_id "STRICT ID" "my.Object" "$OPT" && _FAIL
  )

  ( _IT "should assert for invalid id"

    assert_id "ID" "object" "$OPT" || _FAIL
    assert_id "ID" "my_object" "$OPT" || _FAIL
    assert_id "ID" "my-object" "$OPT" && _FAIL
    assert_id "ID" "myObject" "$OPT" || _FAIL
    assert_id "ID" "MyObject" "$OPT" && _FAIL
    assert_id "ID" "my object" "$OPT" && _FAIL
    assert_id "ID" "my.Object" "$OPT" && _FAIL
  )
  
  ( _IT "should assert for invalid id+spaces"

    assert_spc_id "SPC ID" "object" "$OPT" || _FAIL
    assert_spc_id "SPC ID" "my_object" "$OPT" || _FAIL
    assert_spc_id "SPC ID" "my-object" "$OPT" && _FAIL
    assert_spc_id "SPC ID" "myObject" "$OPT" || _FAIL
    assert_spc_id "SPC ID" "MyObject" "$OPT" || _FAIL
    assert_spc_id "SPC ID" "my object" "$OPT" || _FAIL
    assert_spc_id "SPC ID" "My Object" "$OPT" || _FAIL
    assert_spc_id "SPC ID" "my.Object" "$OPT" && _FAIL
  )

  ( _IT "should assert for invalid extended-id+spaces+ic"

    assert_ext_ic_id_spc "IC ID SPC" "My Object" "$OPT" || _FAIL
    assert_ext_ic_id_spc "IC ID SPC" "My-Object" "$OPT" || _FAIL
    assert_ext_ic_id_spc "IC ID SPC" "My- Object" "$OPT" || _FAIL
  )

  ( _IT "should assert for invalid simple domain name"

    assert_dn "DN" "domain" "$OPT" || _FAIL
    assert_dn "DN" "domai@n" "$OPT" && _FAIL
    assert_dn "DN" "domain?" "$OPT" && _FAIL
    assert_dn "DN" "domain99" "$OPT" || _FAIL
    assert_dn "DN" "my_domain" "$OPT" || _FAIL
    assert_dn "DN" "my-domain" "$OPT" || _FAIL
    assert_dn "DN" "mydomain.example.com" "$OPT" && _FAIL
    assert_dn "DN" "myDomain" "$OPT" && _FAIL
    assert_dn "DN" "MyDomain" "$OPT" && _FAIL
    assert_dn "DN" "my domain" "$OPT" && _FAIL
    assert_dn "DN" "my.Domain" "$OPT" && _FAIL
  )
  
  ( _IT "should assert for fully invalid qualified domain name"

    assert_fdn "FDN" "domain" "$OPT" && _FAIL
    assert_fdn "FDN" "d@omain" "$OPT" && _FAIL
    assert_fdn "FDN" "domain?" "$OPT" && _FAIL
    assert_fdn "FDN" "domain99" "$OPT" && _FAIL
    assert_fdn "FDN" "my_domain" "$OPT" && _FAIL
    assert_fdn "FDN" "my-domain" "$OPT" && _FAIL
    assert_fdn "FDN" "mydomain.example.com" "$OPT" || _FAIL
    assert_fdn "FDN" "my-d_omain.example.com" "$OPT" || _FAIL
    assert_fdn "FDN" "myDomain.example.com" "$OPT" && _FAIL
    assert_fdn "FDN" "myDomain.example.com" "$OPT" && _FAIL
    assert_fdn "FDN" "MyDomain.example.com" "$OPT" && _FAIL
    assert_fdn "FDN" "my domain.example.com" "$OPT" && _FAIL
  )
  
  ( _IT "should assert for invalid url"

    assert_url "URL" "domain" "$OPT" && _FAIL
    assert_url "URL" "http://example.com" "$OPT" || _FAIL
    assert_url "URL" "http://example.com?q=1#f" "$OPT" || _FAIL
  )
  
  
  ( _IT "should assert for invalid email"

    assert_email "MAIL" "domain" "$OPT" && _FAIL
    assert_email "MAIL" "domain@example.com" "$OPT" || _FAIL
    assert_email "MAIL" "asb.s@example.com" "$OPT" || _FAIL
    assert_email "MAIL" "asb.s@an.example.com" "$OPT" || _FAIL
    assert_email "MAIL" ".s@example.com" "$OPT" && _FAIL
  )
  
  ( _IT "should assert for invalid ip"

    assert_ip "IP" "192.168.0.1" "$OPT" || _FAIL
    assert_ip "IP" "" "$OPT" && _FAIL
    assert_ip "IP" "...." "$OPT" && _FAIL
    assert_ip "IP" ".168.1.0" "$OPT" && _FAIL
    assert_ip "IP" "192.168..0" "$OPT" && _FAIL
    assert_ip "IP" "192.168.0." "$OPT" && _FAIL
    assert_ip "IP" "192.168.0" "$OPT" && _FAIL
    assert_ip "IP" "192.168.0.a1" "$OPT" && _FAIL
    assert_ip "IP" "192.168a.0.1" "$OPT" && _FAIL
  )
  
  ( _IT "should assert for invalid email"

    assert_ver "VER" "0.0.1" "$OPT" || _FAIL
    assert_ver "VER" "0.0.1-SNAPSHOT" "$OPT" || _FAIL
    assert_ver "VER" "0.0.1-SNAPSHOT-2" "$OPT" || _FAIL
    assert_ver "VER" "0.1-SNAPSHOT" "$OPT" || _FAIL
    assert_ver "VER" "1-SNAPSHOT" "$OPT" || _FAIL
    assert_ver "VER" "0.0.1+SNAPSHOT" "$OPT" && _FAIL
    assert_ver "VER" "0.0.1:2" "$OPT" && _FAIL
    assert_ver "VER" "0.0.1_3" "$OPT" && _FAIL
    assert_ver "VER" "v0.0.1" "$OPT" || _FAIL
  )

  ( _IT "should assert for invalid giga-typed numbers"

    assert_giga "VER" "10G" "$OPT" || _FAIL
    assert_giga "VER" "10GG" "$OPT" && _FAIL
    assert_giga "VER" "10" "$OPT" && _FAIL
  )
  
  # Bundle SEMVER
  # .. accepted bundle semver
  ( _IT "should assert for invalid semver"

    assert_semver "SEMVER" "0.0.1" "$OPT" || _FAIL
    assert_semver "SEMVER" "0.0.1-SNAPSHOT" "$OPT" || _FAIL
    assert_semver "SEMVER" "v0.0.1" "$OPT" || _FAIL
    assert_semver "SEMVER" "v0.0.1-SNAPSHOT" "$OPT" || _FAIL
    assert_semver "SEMVER" "v0.0.10" "$OPT" || _FAIL
    assert_semver "SEMVER" "v10.10.10" "$OPT" || _FAIL
    # .. ver but not bundle semver
    assert_semver "SEMVER" "1" "$OPT" && _FAIL
    assert_semver "SEMVER" "0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "0.0.0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "v1" "$OPT" && _FAIL
    assert_semver "SEMVER" "v0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "v0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "v0.0.0.1" "$OPT" && _FAIL
    # .. corrupted bundle semver
    assert_semver "SEMVER" "v.0.0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "x0.0.1" "$OPT" && _FAIL
    assert_semver "SEMVER" "0.0.1-" "$OPT" && _FAIL
  )
}

#TEST:integration,lib,map
test_map_functions() {

  ( _IT "should properly handle KV maps"

    ENTANDO_ENT_HOME="$PWD/.entando"
    # shellcheck disable=SC2034
    CFG_FILE="$ENTANDO_ENT_HOME/cfg"
    mkdir "$ENTANDO_ENT_HOME"

    map-clear REMOTES
    map-save REMOTES
    map-count REMOTES N
    _ASSERT N = 0
    map-set REMOTES "test" "a-test"
    map-set REMOTES "test2" "another test"
    map-set REMOTES "test-2" "and another test"
    map-count REMOTES N
    _ASSERT N = 3
    map-save REMOTES
    map-clear REMOTES
    reload_cfg
    map-count REMOTES N
    _ASSERT N = 3
    map-get REMOTES V "test"
    _ASSERT V = "a-test"
    map-get REMOTES V "test2"
    _ASSERT V = "another test"
    map-get REMOTES V "test-2"
    _ASSERT V = "and another test"
  )
}
