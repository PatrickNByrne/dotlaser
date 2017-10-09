# dotlaser

#### Function Tests

This directory contains a basic test suite that verifies dotlaser's functional integrity.

## Installing

### Prerequisites

Bash Automated Testing System - [Bats](https://github.com/sstephenson/bats)

## Usage

Run dotlaser.bats from the tests directory

###### Example

```
$ ./dotlaser.bats   
 ✓ Test - Basic usage, version, or missing task  
 ✓ Test - Invalid config or bootstrap directory  
 ✓ Test - Configuration loading and sanity checks  
 ✓ Test - Bootstrap in hard mode  
 ✓ Test - Bootstrap in link mode  
 ✓ Test - Bootstrap in manual mode  
 ✓ Test - Add items to dotfiles directory  
 ✓ Test - Listing items in the dotfiles directory  
 ✓ Test - Remove items from dotfiles directory  
 ✓ Test - Install individual items from dotfiles directory  
 ✓ Test - Install all items from dotfiles directory  
 ✓ Test - Uninstall all items from dotfiles directory  
 ✓ Test - Install dotlaser and update in hard mode  
 ✓ Test - Install dotlaser and update in subtree mode  
 ✓ Test - Install dotlaser and update in submodule mode  
 ✓ Test - Set profile and test adds, removes, and installs  
  
16 tests, 0 failures  
```
