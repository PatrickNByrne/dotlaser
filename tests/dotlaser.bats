#!/usr/bin/env bats

# ------------------------------------------------------------------
# Author: Patrick Byrne
# Copyright: Patrick Byrne 2017
# License: Apache 2.0
# Title: dotlaser.bats
# Description:
#       Automated unit testing for dotlaser.sh
# ------------------------------------------------------------------

# Add dotlaser to the path
dotlaser_dir="$(dirname "$BATS_TEST_DIRNAME")"
export PATH="$PATH:$dotlaser_dir"

@test "Invoking dotlaser with no arguments prints an error" {
  run dotlaser.sh
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "  Usage: dotlaser.sh [OPTIONS]" ]
}

@test "Invoking dotlaser with -h prints help" {
  run dotlaser.sh -h
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "  Usage: dotlaser.sh [OPTIONS]" ]
}

@test "Invoking dotlaser with -v prints version" {
  run dotlaser.sh -v
  [ "$status" -eq 0 ]
  [[ "${lines[5]}" =~ "Version:" ]]
}

@test "Invoking dotlaser with -c changes the config file" {
  run dotlaser.sh -l -c "$BATS_TEST_DIRNAME/dotlaserrc.test"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "  Usage: dotlaser.sh [OPTIONS]" ]
}
