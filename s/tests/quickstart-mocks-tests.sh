#!/bin/bash

# shellcheck disable=SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 "$OPT" && pwd)"

test_multipass_mocks() {
  print_current_function_name "> " ".."
  (
    . "s/quickstart-mocks.sh"
    multipass info "test-vm" && FATAL "FAILED $LINENO"
    multipass launch --name "test-vm" --cpus "4" --mem "8G" --disk "20G"
    multipass info "test-vm" || FATAL "FAILED $LINENO"
  ) &>/dev/null
}

true