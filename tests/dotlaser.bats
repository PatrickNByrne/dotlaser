#!/usr/bin/env bats

# -------------------------------------------------------------------
# Author: Patrick Byrne
# Copyright: Patrick Byrne 2017
# License: Apache 2.0
# Title: dotlaser.bats
# Description:
#       Automated unit testing for dotlaser.sh
# -------------------------------------------------------------------
#
# --- Global Setup --------------------------------------------------

# Add dotlaser to the path
dotlaser_dir="$(dirname "$BATS_TEST_DIRNAME")"
export PATH="$PATH:$dotlaser_dir"

# --- Special Functions----------------------------------------------

# Setup workspace
setup() {
  test_dir="/tmp/dotlaser_test_dir.$$"
  mkdir "$test_dir"
  mkdir "${test_dir}/dotfiles"
  mkdir "${test_dir}/dotfiles_backup"
  mkdir "${test_dir}/.testdir"
  touch "${test_dir}/test1"
  touch "${test_dir}/.test2"
  touch "${test_dir}/.testdir/test3"
}

# Cleanup workspace
teardown() {
  [[ -d "$test_dir" ]] && rm -rf "$test_dir"
}

# --- Helper Functions----------------------------------------------

# Setup the temporary environment and add items to config/dotfiles dir
bootstrap_and_add() {
  # Bootstrap the test directory
  run bash -c "echo 3 | dotlaser.sh -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  # Set the backup directory
  sed -i "s@\$HOME@$test_dir@" "${test_dir}/dotfiles/dotlaserrc"
  # Add a file
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc -a ${test_dir}/test1
  [ "$status" -eq 0 ]
  # Add a hidden file
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc -a ${test_dir}/.test2
  [ "$status" -eq 0 ]
  # Add a nested file
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.testdir/test3 
  [ "$status" -eq 0 ]
  # Add a folder
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.testdir 
  [ "$status" -eq 0 ]
}

# --- Tests ---------------------------------------------------------

@test "Test - Basic usage, version, or missing task" {
  # Test that usage is printed if arguments are missing
  run dotlaser.sh
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "  Usage: dotlaser.sh [OPTIONS]" ]
  # Test that usage is printed if -h is passed
  run dotlaser.sh -h
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "  Usage: dotlaser.sh [OPTIONS]" ]
  # Test that version is printed if -v is passed
  run dotlaser.sh -v
  [ "$status" -eq 0 ]
  [[ "${lines[5]}" =~ "Version:" ]]
  # Test that usage is printed if --help is passed
  run dotlaser.sh --help
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "  Usage: dotlaser.sh [OPTIONS]" ]
  # Test that version is printed if --version is passed
  run dotlaser.sh --version
  [ "$status" -eq 0 ]
  [[ "${lines[5]}" =~ "Version:" ]]
}

@test "Test - Invalid config or bootstrap directory" {
  # Test invoking dotlaser with an invalid configuration file
  run dotlaser.sh -l -c "${BATS_TEST_DIRNAME}/dotlaserrc.test.fake"
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" =~ "Error: Unable to read config file:" ]]
  # Test invoking dotlaser with an valid configuration file but a bad target
  run dotlaser.sh -l -c "${BATS_TEST_DIRNAME}/dotlaserrc.test"
  [ "$status" -eq 1 ]
  [[ "${lines[1]}" =~ "not a valid directory" ]]
  # Test boostrapping a non-existent directory
  run dotlaser.sh -b "${test_dir}/dotfiles.fake"
  [ "$status" -eq 1 ]
  [[ "${lines[2]}" =~ "Please specify a valid file or directory" ]]
}

@test "Test - Configuration loading and sanity checks" {
  # Setup basic environment
  touch ${test_dir}/dotfiles/dotlaser.files
  cp "${BATS_TEST_DIRNAME}/dotlaserrc.test" "${test_dir}/dotfiles/dotlaserrc"
  sed -i "s@dotlaser_test_dir.@dotlaser_test_dir.$$@" \
    "${test_dir}/dotfiles/dotlaserrc"
  # Test that config flag functions as expected
  run dotlaser.sh -c "${test_dir}/dotfiles/dotlaserrc" -l
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ "Reading config file: ${test_dir}/dotfiles/dotlaserrc" ]]
  # Test that update fails if not configured
  run dotlaser.sh -c "${test_dir}/dotfiles/dotlaserrc" -u
  [ "$status" -eq 1 ]
  [[ "${lines[2]}" =~ "Error: No dotlaser_gitdir set in config file" ]]
}

@test "Test - Bootstrap in hard mode" {
  # Test copy mode bootstrap
  run bash -c "echo 1 | dotlaser.sh -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  [[ "${lines[3]}" =~ "Installing in hard copy mode" ]]
  [[ -f "${test_dir}/dotfiles/dotlaser.sh" ]]
}

@test "Test - Bootstrap in link mode" {
  # Test linked bootstrap
  run bash -c "echo 2 | dotlaser.sh -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  [[ "${lines[3]}" =~ "Installing in link mode" ]]
  [[ -L "${test_dir}/dotfiles/dotlaser.sh" ]]
}

@test "Test - Bootstrap in manual mode" {
  # Test manual bootstrap
  run bash -c "echo 3 | dotlaser.sh -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  [[ "${lines[3]}" =~ "manual installation" ]]
}

@test "Test - Add items to dotfiles directory" {
  # Bootstrap the test directory
  run bash -c "echo 3 | dotlaser.sh -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  # Add a file and test it
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc -a ${test_dir}/test1
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Adding ${test_dir}/test1" ]]
  [[ -f "${test_dir}/dotfiles/test1" ]]
  # Add a hidden file and test it
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc -a ${test_dir}/.test2
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Adding ${test_dir}/.test2" ]]
  [[ -f "${test_dir}/dotfiles/test2" ]]
  # Add a nested file and test it
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.testdir/test3 
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Adding ${test_dir}/.testdir/test3" ]]
  [[ -f "${test_dir}/dotfiles/test3" ]]
  # Add a folder and test it
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.testdir 
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Adding ${test_dir}/.testdir" ]]
  [[ -d "${test_dir}/dotfiles/testdir" ]]
  [[ -f "${test_dir}/dotfiles/testdir/test3" ]]
}

@test "Test - Listing items in the dotfiles directory" {
  bootstrap_and_add
  # List items and test
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc -l
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Target_______________________" ]]
  [[ "${lines[2]}" =~ "test1" ]]
  [[ "${lines[3]}" =~ ".test2" ]]
  [[ "${lines[4]}" =~ ".testdir/test3" ]]
  [[ "${lines[5]}" =~ ".testdir" ]]
}

@test "Test - Remove items from dotfiles directory" {
  bootstrap_and_add
  # Remove a file and test it
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -r ${test_dir}/test1"
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Removing ${test_dir}/test1" ]]
  [[ ! -f "${test_dir}/dotfiles/test1" ]]
  # Remove a hidden file and test it
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -r ${test_dir}/.test2"
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Removing ${test_dir}/.test2" ]]
  [[ ! -f "${test_dir}/dotfiles/test2" ]]
  # Remove a nested file and test it
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -r ${test_dir}/.testdir/test3"
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Removing ${test_dir}/.testdir/test3" ]]
  [[ ! -f "${test_dir}/dotfiles/test3" ]]
  # Remove a folder and test it
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -r ${test_dir}/.testdir"
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Removing ${test_dir}/.testdir" ]]
  [[ ! -d "${test_dir}/dotfiles/testdir" ]]
  [[ ! -f "${test_dir}/dotfiles/testdir/test3" ]]
  # Test that backups get created
  [[ -f "${test_dir}/dotfiles_backup/test1" ]]
  [[ -f "${test_dir}/dotfiles_backup/test2" ]]
  [[ -f "${test_dir}/dotfiles_backup/test3" ]]
  [[ -f "${test_dir}/dotfiles_backup/testdir/test3" ]]
}

@test "Test - Install individual items from dotfiles directory" {
  bootstrap_and_add
  # Install target file and test
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i ${test_dir}/test1"
  [ "$status" -eq 0 ]
  [[ "${lines[2]}" =~ "Installing ${test_dir}/test1" ]]
  [[ -L "${test_dir}/test1" ]]
  # Install target hidden file and test
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i ${test_dir}/.test2"
  [ "$status" -eq 0 ]
  [[ "${lines[2]}" =~ "Installing ${test_dir}/.test2" ]]
  [[ -L "${test_dir}/.test2" ]]
  # Install target nested file and test
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i ${test_dir}/.testdir/test3"
  [ "$status" -eq 0 ]
  [[ "${lines[2]}" =~ "Installing ${test_dir}/.testdir/test3" ]]
  [[ -L "${test_dir}/.testdir/test3" ]]
  # Install target folder and test
  run bash -c "echo y | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i ${test_dir}/.testdir"
  [ "$status" -eq 0 ]
  [[ "${lines[2]}" =~ "Installing ${test_dir}/.testdir" ]]
  [[ -L "${test_dir}/.testdir" ]]
  # Test that backups get created
  [[ -f "${test_dir}/dotfiles_backup/test1" ]]
  [[ -f "${test_dir}/dotfiles_backup/.test2" ]]
  [[ -f "${test_dir}/dotfiles_backup/test3" ]]
  [[ -f "${test_dir}/dotfiles_backup/.testdir/test3" ]]
}

@test "Test - Install all items from dotfiles directory" {
  bootstrap_and_add
  # Install all files and test
  run bash -c "printf 'y\ny\ny\ny\n' | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i"
  [ "$status" -eq 0 ]
  [[ "${lines[1]}" =~ "Installing dotfiles" ]]
  [[ -L "${test_dir}/test1" ]]
  [[ -L "${test_dir}/.test2" ]]
  [[ -f "${test_dir}/.testdir/test3" ]]
  [[ -L "${test_dir}/.testdir" ]]
  # Test that backups get created
  [[ -f "${test_dir}/dotfiles_backup/test1" ]]
  [[ -f "${test_dir}/dotfiles_backup/.test2" ]]
  [[ -f "${test_dir}/dotfiles_backup/test3" ]]
  [[ -f "${test_dir}/dotfiles_backup/.testdir/test3" ]]
}

@test "Test - Uninstall all items from dotfiles directory" {
  bootstrap_and_add
  # Install all files
  run bash -c "printf 'y\ny\ny\ny\n' | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i"
  [ "$status" -eq 0 ]
  # Uninstall all the dotfiles and test the output status
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc --uninstall
  [ "$status" -eq 0 ]
  # Test the status messages
  [[ "${lines[1]}" =~ "Uninstalling dotfiles" ]]
  [[ "${lines[2]}" =~ "test1" ]]
  [[ "${lines[3]}" =~ ".test2" ]]
  [[ "${lines[4]}" =~ ".testdir/test3" ]]
  [[ "${lines[5]}" =~ ".testdir" ]]
  # Test the files were cleaned up
  [[ ! -f "${test_dir}/test1" ]]
  [[ ! -f "${test_dir}/.test2" ]]
  [[ ! -f "${test_dir}/.testdir/test3" ]]
  [[ ! -f "${test_dir}/.testdir" ]]
}

@test "Test - Install dotlaser and update in hard mode" {
  # Make the dotlaser git directory
  mkdir "${test_dir}/dotfiles/dotlaser"
  # Install dotlaser in hard mode
  ( cd "${test_dir}/dotfiles"
    git clone https://github.com/PatrickNByrne/dotlaser )
  # Bootstrap the test directory
  run bash -c "echo 3 | ${test_dir}/dotfiles/dotlaser/dotlaser.sh \
    -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  # Set the git dir and update type
  sed -i "s@gitdir=\"@gitdir=\"${test_dir}/dotfiles/dotlaser@" \
    "${test_dir}/dotfiles/dotlaserrc"
  sed -i "s@updatetype=\"@updatetype=\"hard@" \
    "${test_dir}/dotfiles/dotlaserrc"
  # Install the current version of the script
  cp "${dotlaser_dir}/dotlaser.sh" "${test_dir}/dotfiles/"
  # Update dotlaser and test
  run bash -c "echo y | ${test_dir}/dotfiles/dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -u"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "You're about to update dotlaser from version" ]]
}

@test "Test - Install dotlaser and update in subtree mode" {
  # Install dotlaser in subtree mode
  ( cd "${test_dir}/dotfiles"
    git init
    touch test
    git add .
    git commit -m "Initial commit"
    git subtree add --prefix dotlaser/ \
      https://github.com/PatrickNByrne/dotlaser master --squash )
  # Bootstrap the test directory
  run bash -c "echo 3 | ${test_dir}/dotfiles/dotlaser/dotlaser.sh \
    -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  # Set the git dir and update type
  sed -i "s@gitdir=\"@gitdir=\"${test_dir}/dotfiles/dotlaser@" \
    "${test_dir}/dotfiles/dotlaserrc"
  sed -i "s@updatetype=\"@updatetype=\"subtree@" \
    "${test_dir}/dotfiles/dotlaserrc"
  # Install the current version of the script
  cp "${dotlaser_dir}/dotlaser.sh" "${test_dir}/dotfiles/"
  # Update dotlaser and test
  run bash -c "echo y | ${test_dir}/dotfiles/dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -u"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Updated from version" ]]
}

@test "Test - Install dotlaser and update in submodule mode" {
  # Install dotlaser in submodule mode
  ( cd "${test_dir}/dotfiles"
    git init
    touch test
    git add .
    git commit -m "Initial commit"
    git submodule add https://github.com/PatrickNByrne/dotlaser ./dotlaser )
  # Bootstrap the test directory
  run bash -c "echo 3 | ${test_dir}/dotfiles/dotlaser/dotlaser.sh \
    -b ${test_dir}/dotfiles"
  [ "$status" -eq 0 ]
  # Set the git dir and update type
  sed -i "s@gitdir=\"@gitdir=\"${test_dir}/dotfiles/dotlaser@" \
    "${test_dir}/dotfiles/dotlaserrc"
  sed -i "s@updatetype=\"@updatetype=\"subtree@" \
    "${test_dir}/dotfiles/dotlaserrc"
  # Install the current version of the script
  cp "${dotlaser_dir}/dotlaser.sh" "${test_dir}/dotfiles/"
  # Update dotlaser and test
  run bash -c "echo y | ${test_dir}/dotfiles/dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -u"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Updated from version" ]]
}

@test "Test - Set profile and test adds, removes, and installs" {
  bootstrap_and_add
  # Add profile test files
  touch "${test_dir}/prof1"
  touch "${test_dir}/.prof2"
  mkdir "${test_dir}/.profdir"
  touch "${test_dir}/.profdir/prof3"
  # Add a profile test file
  run dotlaser.sh -p testprof -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/prof1
  [ "$status" -eq 0 ]
  # Add a profile test hidden file
  run dotlaser.sh -p testprof -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.prof2
  [ "$status" -eq 0 ]
  # Add a profile test nested file
  run dotlaser.sh -p testprof -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.profdir/prof3 
  [ "$status" -eq 0 ]
  # Add a profile test folder
  run dotlaser.sh -p testprof -c ${test_dir}/dotfiles/dotlaserrc \
    -a ${test_dir}/.profdir 
  [ "$status" -eq 0 ]
  # Test that we have the correct number of test profile items
  count_prof="$(dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc -l | \
    grep -ic "testprof")"
  [[ "$count_prof" = "4" ]]
  # Remove the profile test items from the target dirs
  # Add profile test files
  echo "y" | rm -f "${test_dir}/prof1"
  echo "y" | rm -f "${test_dir}/.prof2"
  echo "y" | rm -f "${test_dir}/.profdir/prof3"
  echo "y" | rmdir "${test_dir}/.profdir"
  # Install all default files
  run bash -c "printf 'y\ny\ny\ny\n' | dotlaser.sh \
    -c ${test_dir}/dotfiles/dotlaserrc -i"
  [ "$status" -eq 0 ]
  # Test that the profile test files were not installed
  [[ ! -f "${test_dir}/prof1" ]]
  [[ ! -f "${test_dir}/.prof2" ]]
  [[ ! -f "${test_dir}/.profdir/prof3" ]]
  [[ ! -f "${test_dir}/.profdir" ]]
  # Uninstall all the default files
  run dotlaser.sh -c ${test_dir}/dotfiles/dotlaserrc --uninstall
  [ "$status" -eq 0 ]
  # Install all profile test files
  run bash -c "printf 'y\ny\ny\ny\n' | dotlaser.sh -p testprof \
    -c ${test_dir}/dotfiles/dotlaserrc -i"
  [ "$status" -eq 0 ]
  # Test that the profile test files were installed
  [[ -L "${test_dir}/prof1" ]]
  [[ -L "${test_dir}/.prof2" ]]
  [[ -f "${test_dir}/.profdir/prof3" ]]
  [[ -L "${test_dir}/.profdir" ]]
  # Test that the default profile files were not installed
  [[ ! -f "${test_dir}/test1" ]]
  [[ ! -f "${test_dir}/.test2" ]]
  [[ ! -f "${test_dir}/.testdir/test3" ]]
  [[ ! -f "${test_dir}/.testdir" ]]
}
