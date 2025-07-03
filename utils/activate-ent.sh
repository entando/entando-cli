#!/usr/bin/env bash
set -eux
yes | ent check-env develop --lenient
