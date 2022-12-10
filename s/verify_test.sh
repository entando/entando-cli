#!/bin/bash

_require "$PROJECT_DIR/s/verify.sh"

#TEST:unit,lib,verify
_verify.test.verify-expression.numeric() {
  ( _IT "should pass in case of true numeric comparison"
  
    V=5
    (_verify.verify-expression "" V eq 5) || _FAIL "eq"
    (_verify.verify-expression "" V ne 9) || _FAIL "ne"
    (_verify.verify-expression "" V gt 4) || _FAIL "gt"
    (_verify.verify-expression "" V ge 5) || _FAIL "ge"
    (_verify.verify-expression "" V lt 6) || _FAIL "lt"
    (_verify.verify-expression "" V le 6) || _FAIL "le"
    exit 0
  )

  ( _IT "should fatal in case of false numeric comparison" SILENCE-ERRORS
  
    V=5
    (_verify.verify-expression "" V eq 9 2>/dev/null;exit 0) && _FAIL "eq"
    (_verify.verify-expression "" V ne 5 2>/dev/null;exit 0) && _FAIL "ne"
    (_verify.verify-expression "" V gt 5 2>/dev/null;exit 0) && _FAIL "gt"
    (_verify.verify-expression "" V ge 6 2>/dev/null;exit 0) && _FAIL "ge"
    (_verify.verify-expression "" V lt 5 2>/dev/null;exit 0) && _FAIL "lt"
    (_verify.verify-expression "" V le 4 2>/dev/null;exit 0) && _FAIL "le"
  )
}

#TEST:unit,lib,verify
_verify.test.verify-expression.string() {
  
  ( _IT "should pass in case of true string comparison"
  
    # shellcheck disable=SC2034
    V="SOME TEST STRING"
    (_verify.verify-expression "" V = "SOME TEST STRING")        || _FAIL "="
    (_verify.verify-expression "" V != "SOME OTHER TEST STRING") || _FAIL "!="
    (_verify.verify-expression "" V =~ "SOME .* STRING")         || _FAIL "=~"
    (_verify.verify-expression "" V !=~ "SOME OTHER .* STRING")  || _FAIL "!=~"
    (_verify.verify-expression "" V starts-with "SOME")          || _FAIL "starts-with"
    (_verify.verify-expression "" V ends-with "STRING")          || _FAIL "ends-with"
    (_verify.verify-expression "" V contains "TEST")             || _FAIL "contains"
  )

    ( _IT "should fatal in case of false string comparison" SILENCE-ERRORS
  
    # shellcheck disable=SC2034
    V="SOME TEST STRING"
    (_verify.verify-expression "" V = "SOME OTHER TEST STRING" 2>/dev/null;exit 0)  && _FAIL "="
    (_verify.verify-expression "" V != "SOME TEST STRING" 2>/dev/null;exit 0)       && _FAIL "!="
    (_verify.verify-expression "" V =~ "SOME OTHER  .* STRING" 2>/dev/null;exit 0)  && _FAIL "=~"
    (_verify.verify-expression "" V !=~ "SOME .* STRING" 2>/dev/null;exit 0)        && _FAIL "!=~"
    (_verify.verify-expression "" V starts-with "TEST" 2>/dev/null;exit 0)          && _FAIL "starts-with"
    (_verify.verify-expression "" V ends-with "TEST" 2>/dev/null;exit 0)            && _FAIL "ends-with"
    (_verify.verify-expression "" V contains "OTHER" 2>/dev/null;exit 0)            && _FAIL "contains"
  )
}
