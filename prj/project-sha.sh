#!/bin/bash

sha256sum < <(
  find macro -type f -exec sha256sum {} \;
  find lib -type f -exec sha256sum {} \;
)
