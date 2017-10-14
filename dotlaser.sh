#!/bin/bash
# ------------------------------------------------------------------
# Author: Patrick Byrne
# Copyright: Patrick Byrne 2017
# License: Apache 2.0
# Title: dotlaser
# Description:
#       Manage your dotfiles precisely and effortlessly
# ------------------------------------------------------------------
#  Todo:
#      Make sure this works in zsh and osx - (sed -i)
# ------------------------------------------------------------------

version=0.1.15

# --- Config Variables ---------------------------------------------

dotfiles_dir=""
dotfiles_backup_dir=""
dotfiles_config=""
dotlaser_gitdir=""
dotlaser_updatetype=""
dotlaser_repo=""

# --- Functions ----------------------------------------------------

version()	
{
  cat <<"STOP"
                   ____        __  __                        
                  / __ \____  / /_/ /   ____ _________  _____
                 / / / / __ \/ __/ /   / __ `/ ___/ _ \/ ___/
                / /_/ / /_/ / /_/ /___/ /_/ (__  )  __/ /    
               /_____/\____/\__/_____/\__,_/____/\___/_/     
STOP
  printf "\t\t\t\tVersion: %s\n" $version
}

usage() 
{
  cat <<"STOP"
  Usage: dotlaser.sh [OPTIONS]

  OPTIONS

    --help        -h              Print this message
    --version     -v              Print the current dotlaser version
    --config      -c <target>     Specify a config file
    --bootstrap   -b <target>     Bootstrap your dotfiles directory
    --add         -a <target>     Add a file or directory to your dotfiles
    --remove      -r <target>     Remove a file or directory from your dotfiles
    --install     -i (target)     Install all/target managed dotfile/s
    --update      -u              Update dotlaser
    --list        -l              List all managed dotfiles and their status
    --profile     -p <profile>    Specify a dotfiles profile. Used with -a & -i
    --uninstall                   Uninstall all managed dotfiles

STOP
}

dotlaser_abspath()
{
  [[ -z "$1" ]] && echo "Error: Null Path" && exit 1
  if [[ "$task" = "install" ]] || [[ "$task" = "list" ]]; then
    if [[ "$1" = "\$HOME"* ]]; then
      echo "${1/\$HOME/$HOME}"
      return
    else
      echo "$1"
      return
    fi
  fi
  (
  eval cd "$(dirname "$1")"
  echo "$PWD/$(basename "$1")"
  )
}

dotlaser_relpath()
{
  if (echo "$1" | grep -q "$HOME"); then
    echo "${1/$HOME/\$HOME}"
  else
    echo "$1"
  fi
}

dotlaser_loadconfig()
{
  # Set the default config file if not specified
  if [[ -z $dotlaser_config ]]; then
    if [[ -f "$(dotlaser_abspath "$HOME/.dotlaserrc")" ]]; then
      dotlaser_config="$(dotlaser_abspath "$HOME/.dotlaserrc")"
    else
      dotlaser_config="$(dotlaser_abspath "$(dirname "$0")/dotlaserrc")"
    fi
  fi
  # Verify config file is sane and source it
  if [[ ! -f "$dotlaser_config" ]]; then
    echo "Error: Unable to read config file: $dotlaser_config"
    exit 1
  else
    echo "Reading config file: $dotlaser_config"
    # shellcheck source=/dev/null
    source "$dotlaser_config"
  fi
  # Skip path verification if bootstrapping 
  [[ "$task" = "bootstrap" ]] && return 
  # Verify paths in config file are sane
  if [[ ! -d "$dotfiles_dir" ]]; then
    echo "$dotfiles_dir is not a valid directory. Please check your config"
    exit 1
  elif [[ ! -f "$dotfiles_config" ]]; then
    echo "$dotfiles_config does not exist. Please check your config"
    exit 1
  elif [[ ! -d "$dotfiles_backup_dir" ]]; then
    echo "$dotfiles_backup_dir does not exist. Please check your config"
    exit 1
  fi
  # Strip the comments and blank lines from the file list for reading
  sed -e '/^#.*/d' -e '/^$/d' "$dotfiles_config" > /tmp/dotlaser_file_list.$$
  dotfiles_list="/tmp/dotlaser_file_list.$$"
}

dotlaser_target()
{
  # Check to make sure our target is set and exists
  if [[ -z $1 ]] || [[ ! -e $1 ]]; then
    echo "Error: Please specify a valid file or directory"
    exit 1
  # Test if target is a symlink but not if we're removing
  elif [[ -h $1 ]] && [[ $task != "remove" ]]; then
    echo "Error: The specified target is a symbolic link"
    exit 1
  fi
}

dotlaser_backup()
{
  # Check the backup dir and create it if required
  if [[ ! -d "$dotfiles_backup_dir" ]]; then
    mkdir -p "$dotfiles_backup_dir"
  fi
  echo "Backing up $1 to $dotfiles_backup_dir"
  # Check if backup file exists
  backup_target="$dotfiles_backup_dir/$(basename "$1")"
  if [[ -e "$backup_target" ]]; then
    # Create an "old" folder in the backup dir
    if [[ ! -d "$dotfiles_backup_dir/old" ]]; then
      mkdir -p "$dotfiles_backup_dir/old"
    fi
    # Check if the file exists in old and remove
    if [[ -e "$dotfiles_backup_dir/old/$(basename "$1")" ]]; then
      rm -R "$dotfiles_backup_dir/old/$(basename "$1")"
    fi
    # Move the old backup into the old folder
    mv -f "$backup_target" "$dotfiles_backup_dir/old"
  fi
  if [[ "$2" = "move" ]]; then
    mv -f "$1" "$dotfiles_backup_dir/"
  else
    cp -a "$1" "$dotfiles_backup_dir/"
  fi
}

dotlaser_bootstrap()
{
  [[ ! -d $1 ]] && echo "Error: Target is not a directory" && exit 1
  # Create dotlaser file list
  cp -n "$dotlaser_dir/dotlaser.files" "$1"
  # Check if config file already exists
  if [[ -f "$1/dotlaserrc" ]]; then
    # Verify removal
    printf "You're about to overwrite %s\n" "$1/dotlaserrc"
    read -rp "Is this correct? [y/N]: " user_choice
    user_choice="${user_choice:0:1}"
    [[ ! ${user_choice,,} = "y" ]] && exit
  fi
  # Copy and update our cfg file
  cp -n "$dotlaser_dir/dotlaserrc" "$1"
  sed -i "s@dotfiles_dir=.*@dotfiles_dir=\"$(dotlaser_relpath "$1")\"@g" \
    "$1/dotlaserrc"
  printf "How would you like to install? [1 - Hard, 2 - Link, 3 - Manual]\n"
  read -rp "Please select install option [1,2,3]: " user_choice
  case "$user_choice" in
    1)
      echo "Installing in hard copy mode"
      # Copy the dotlaser script to our dotfiles dir
      cp "$dotlaser_path" "$1"
    ;;
    2)
      echo "Installing in link mode"
      user_home="$(dotlaser_abspath "$HOME")"
      dotlaser_path="$(dotlaser_abspath "$dotlaser_path")"
      # Check if dotlaser and bootstrap target are in user's HOME
      if [[ "$dotlaser_path" = *"$user_home"* ]] && \
        [[ "$target" = *"$user_home"* ]]; then
          # Get the number of steps back to $HOME and replace with ../
          rellink="$(dotlaser_abspath "$1" | \
            sed -e "s@$user_home@@" -e 's@[^/]@@g' -e 's@/@../@g')"
          # Strip the home dir from the dotlaser path to replace later
          reltarget="${dotlaser_path#$user_home}"
          ln -s "$rellink$reltarget" "$1"
      else
          ln -s "$dotlaser_path" "$1"
      fi
    ;;
    *)
      echo "Please refer to the README for manual installation assistance"
    ;;
  esac
}

dotlaser_update()
{
  # Check if git is installed
  command -v git >/dev/null || { echo "Error: git not found"; exit 1; }
  # Check if git dir is set and get a full path
  if [[ -n "$dotlaser_gitdir" ]]; then
    dotlaser_gitdir="$(dotlaser_abspath "$dotlaser_gitdir")"
  elif [[ "$dotlaser_updatetype" = "hard" && -z "$dotlaser_gitdir" ]]; then
    echo "Warning: No dotlaser_gitdir set in config file"
  else
    echo "Error: No dotlaser_gitdir set in config file"
    exit 1
  fi
  # Process the update type config variable
  case "$dotlaser_updatetype" in
    hard)
      echo "Starting hard update" 
      # Check if a git directory is specified and set default
      [[ -z "$dotlaser_gitdir" ]] && dotlaser_gitdir="/tmp/dotlaser.$$"
      echo "Cloning into $dotlaser_gitdir"
      # Check the git dir and create it if required
      if [[ ! -d "$dotlaser_gitdir" ]]; then
        mkdir -p "$dotlaser_gitdir"
      fi
      # Get into the git dir and update/clone
      (
      cd "$dotlaser_gitdir" || exit 1
      if [[ -e "$dotlaser_gitdir/.git" ]]; then
        # Check for changes in dotlaser repo dir
        git ls-files -o | grep >/dev/null . && \
          echo "Warning: There are uncommited files in $dotlaser_gitdir"
        git fetch -p || { echo "Error: Update fetch failed"; exit 1; }
        git checkout --force "origin/master" || \
        { echo "Error: Update checkout failed"; exit 1; }
      else
        git clone --depth=1 "$dotlaser_repo" . || \
        { echo "Error: Update clone failed"; exit 1; }
      fi
      # Get new script version
      dotlaser_version="$(grep "^ver.*=" "$dotlaser_gitdir/dotlaser.sh")"
      dotlaser_version="${dotlaser_version#version=}"
      # Verify overwrite
      printf "Updated from version %s to %s\n" \
        "$version" "$dotlaser_version" 
      )
      echo "Don't forget to commit your changes!"
    ;;
    subtree)
      (
      cd "$dotfiles_dir" || exit 1
      # Check for changes in dotlaser repo dir
      git ls-files -o | grep >/dev/null . && \
        echo "Warning: There are uncommited files in $dotlaser_gitdir"
      # Get the subtree prefix
      dotfiles_dir_prefix="$(dotlaser_abspath "$dotfiles_dir")/"
      subtree_prefix="${dotlaser_gitdir#$dotfiles_dir_prefix}"
      # Update or exit with an error message
      git subtree pull --prefix="$subtree_prefix" --squash \
        -m "Update Plugin" $dotlaser_repo master || \
        { echo "Error: Update failed"; exit 1; }
      # Get new script version
      dotlaser_version="$(grep "^ver.*=" "$dotlaser_gitdir/dotlaser.sh")"
      dotlaser_version="${dotlaser_version#version=}"
      printf "Updated from version %s to %s\n" "$version" "$dotlaser_version"
      )
      echo "Don't forget to commit your changes!"
    ;;
    submod)
      (
      cd "$dotlaser_gitdir" || exit 1
      # Check for changes in dotlaser repo dir
      git ls-files -o | grep >/dev/null . && \
        echo "Warning: There are uncommited files in $dotlaser_gitdir"
      git checkout -f master || \
        { echo "Error: Update checkout failed"; exit 1; }
      git pull --squash || { echo "Error: Update pull failed"; exit 1; }
      # Get new script version
      dotlaser_version="$(grep "^ver.*=" "$dotlaser_gitdir/dotlaser.sh")"
      dotlaser_version="${dotlaser_version#version=}"
      printf "Updated from version %s to %s\n" "$version" "$dotlaser_version"
      )
      echo "Don't forget to commit your changes!"
    ;;
    *)
      echo "Error: Unknown update type $dotlaser_updatetype"
      exit 1
    ;;
  esac
}

dotlaser_add()
{
  # Get the basefile name to append to the config
  target_basename="$(basename "$1")"
  # Get the file type to append to the config
  if [[ -f $1 ]]; then
    dotlaser_filetype="file"
  elif [[ -d $1 ]]; then
    dotlaser_filetype="dir"
  else
    dotlaser_filetype="unknown"
  fi
  # Strip leading dots from file names
  if [[ "${target_basename:0:1}" = "." ]]; then
    target_basename="${target_basename#.}"
  fi
  # Create relative paths
  target_relpath="$(dotlaser_relpath "$1")"
  dotfile_relpath="$(dotlaser_relpath "${dotfiles_dir}/${target_basename}")"
  # Copy the target file to dotfiles location
  cp -a "$1" "${dotfiles_dir}/${target_basename}"
  # Add the target file to dotlaser file list
  printf "%s:%s:%s:%s\n" "$target_relpath" "$dotfile_relpath" \
    "$dotlaser_filetype" "$dotlaser_profile" >> "$dotfiles_config"
}

dotlaser_remove()
{
  # Set target to a relative path for configuration search
  target="$(dotlaser_relpath "$target")" 
  # Read in the config file entry for target 
  IFS=':' read -r target dotfiles_target dotlaser_filetype \
    dotlaser_profile <<<"$(grep -m 1 "$target:" "$dotfiles_list")"
  # Check if the file was found in the config
  if [[ -z $dotfiles_target ]]; then
    echo "Error: File not found in config"
    exit 1
  fi
  # Get absolute file paths
  dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
  target="$(dotlaser_abspath "$target")"
  # Check if the file is installed and remove
  dotlaser_status "$target" "$dotfiles_target"
  if [[ "$dotlaser_status" = "Installed" ]]; then
    echo "Uninstalling $target"
    # This is a precaution - Check if target is a symlink
    if [[ -h "$target" ]]; then
      rm -r "$target"
    fi
  fi
  # Verify removal
  printf "You're about to remove %s from your dotfiles directory\n" \
    "$dotfiles_target"
  read -rp "Is this correct? [y/N]: " user_choice
  user_choice="${user_choice:0:1}"
  [[ ! ${user_choice,,} = "y" ]] && exit 0
  # Remove file from config
  sed -i "\,^$target:.*$,d" "$dotfiles_config"
  # Bail if the target doesn't exist
  [[ ! -e "$dotfiles_target" ]] && return
  # Verify removal target is in the dotfiles directory
  verifydir="$(echo "$dotfiles_target" | grep "^$dotfiles_dir")"
  if [[ "$verifydir" = "$dotfiles_target" ]]; then
    # Backup the files
    dotlaser_backup "$dotfiles_target"
    # Delete them
    rm -r "$dotfiles_target"
  fi
}    
        
dotlaser_install()
{
  # If a target is set, create a break point
  if [[ -n "$target" ]]; then
    loopstop="$(dotlaser_abspath "$target")"
  fi
  # Set a break point for the specified profile
  profilestop="$dotlaser_profile"
  # Loop through the config file
  while IFS=':' read -r target dotfiles_target \
    dotlaser_filetype dotlaser_profile <&9; do
      target="$(dotlaser_abspath "$target")"
      dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
      # Check if a target file was not specified and the profile matches
      # or if the specified file is found
      if [[ -z "$loopstop" && "$profilestop" = "$dotlaser_profile" ]] || \
        [[ "$loopstop" = "$target" ]] || \
        [[ "$loopstop" = "$dotfiles_target" ]]; then
          # Only match objects of the specified profile
          if [[ "$profilestop" = "$dotlaser_profile" ]]; then
            dotlaser_status "$target" "$dotfiles_target"       
            case "$dotlaser_status" in
              Installed)
                echo "$target is already installed"
              ;;
              Uninstalled)
                echo "Installing $target"
                # Check if the file exists
                if [[ -e "$target" ]]; then
                  # Verify removal
                  printf "You're about to overwrite %s\n" "$target"
                  read -rp "Is this correct? [y/N]: " user_choice
                  user_choice="${user_choice:0:1}"
                  [[ ! ${user_choice,,} = "y" ]] && continue
                  # Backup the existing file
                  dotlaser_backup "$target" "move"
                fi
                # Check if the parent dir exists and create it if not
                if [[ ! -d "$(dirname "$target")" ]]; then
                  mkdir -p "$(dirname "$target")"
                fi
                # Link the dotfiles target to the fs target removing whats there
                ln -sfn "$dotfiles_target" "$target"
              ;;
              Missing)
                echo "Error: Unable to locate $target in $dotfiles_dir"
                exit 1
              ;;
              *)
                echo "Error: Unable to determine status of $target"
                exit 1
              ;;
            esac
          fi  
      fi
  done 9< "$dotfiles_list"
}

dotlaser_uninstall()
{
  # If a target is set, create a break point
  if [[ -n "$target" ]]; then
    loopstop="$(dotlaser_abspath "$target")"
  fi
  # Loop through the config file
  while IFS=':' read -r target dotfiles_target \
    dotlaser_filetype dotlaser_profile <&9; do
      target="$(dotlaser_abspath "$target")"
      dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
      # Check for a loopstop or a match
      if [[ -z "$loopstop" ]] || [[ "$loopstop" = "$target" ]] || \
        [[ "$loopstop" = "$dotfiles_target" ]]; then
          dotlaser_status "$target" "$dotfiles_target"
          case "$dotlaser_status" in
            Installed)
              echo "Uninstalling $target"
              # This is a precaution - Check if target is a symlink
              if [[ -h "$target" ]]; then
                rm -r "$target"
              fi
            ;;
            Uninstalled)
              echo "$target is not installed"
            ;;
            Missing)
              echo "Error: Unable to locate $target in $dotfiles_dir"
              exit 1
            ;;
            *)
              echo "Error: Unable to determine status of $target"
              exit 1
            ;;
          esac
      fi
  done 9< "$dotfiles_list"
}

dotlaser_status()
{
  # Check if its a symlink
  if [[ "$(readlink "$1")" = "$(dotlaser_abspath "$2")" ]]; then
    dotlaser_status="Installed"
  elif [[ ! -e $2 ]]; then
    dotlaser_status="Missing"
  else
    dotlaser_status="Uninstalled"
  fi
}

dotlaser_list()
{
  echo
  printf "%-30s | %-15s | %-15s | %-15s\n" "Target" "File Type" "Profile" \
    "Status" | tr " " "_"
  while IFS=':' read -r target dotfiles_target \
    dotlaser_filetype dotlaser_profile; do
      target="$(dotlaser_abspath "$target")"
      dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
      dotlaser_status "$target" "$dotfiles_target"
      printf "%-30s | %-15s | %-15s | %-15s\n" "$target" \
        "${dotlaser_filetype^}" "$dotlaser_profile" "$dotlaser_status"
  done <"$dotfiles_list"
  echo
}

dotlaser_cleanup()
{
  # Remove the temporary dotfiles list
  if [[ -n "$dotfiles_list" ]]; then
    rm "$dotfiles_list"
  fi

  # Remove the hard update folder
  if [[ "$task" = "update" && "$dotlaser_gitdir" = "/tmp/dotlaser.$$" ]]; then
    echo "Removing temporary update folder"
    rm -rf /tmp/dotlaser.$$
  fi
}

# --- Options processing -------------------------------------------

while [[ $# -gt 0 ]]; do
  param=$1
  value=$2
  case $param in
    -h | --help)
      usage
      exit
    ;;
    -v | --version)
      version
      exit
    ;;
    -c | --config)
      dotlaser_config="$(readlink -m "$value")"
      shift
    ;; 
    -b | --bootstrap)
      task="bootstrap"
      target="$(readlink -m "$value")"
      shift
    ;; 
    -a | --add)
      task="add"
      target="$(readlink -m "$value")"
      shift
    ;; 
    -r | --remove)
      task="remove"
      target="$(readlink -m "$value")"
      shift
    ;; 
    -i | --install)
      task="install"
      # If install is followed by a non-option, set it as a target and shift
      if [[ ! ${value:0:1} = "-" ]]; then
        target="$(readlink -m "$value")"
        shift
      fi
    ;; 
    -u | --update)
      task="update"
    ;; 
    -l | --list)
      task="list"
    ;; 
    -p | --profile)
      dotlaser_profile="$value"
      shift
    ;; 
    --uninstall)
      task="uninstall"
      # If uninstall is followed by a non-option, set it as a target and shift
      if [[ ! ${value:0:1} = "-" ]]; then
        target="$(readlink -m "$value")"
        shift
      fi
    ;;
    *)
      echo "Error: unknown parameter \"$param\""
      usage
      exit 1
    ;;
  esac
  shift
done

# --- Body ---------------------------------------------------------

# Run the cleanup function regardless of exit type
trap 'dotlaser_cleanup' EXIT

# Get paths for the calling script and default dir
dotlaser_path="$(dotlaser_abspath "${BASH_SOURCE[0]}")"
dotlaser_dir="$(dirname "$dotlaser_path")"

# Check if "task" is not set, print usage, and exit
[[ -z $task ]] && usage && exit 1

dotlaser_loadconfig

# Set a default profile if one is not specified
[[ -z $dotlaser_profile ]] && dotlaser_profile="default"

# Task Logic
case $task in
  bootstrap)
    echo "Bootstrapping $target"
    dotlaser_target "$target"
    dotlaser_bootstrap "$target"
  ;;
  add)
    echo "Adding $target"
    dotlaser_target "$target"
    dotlaser_add "$target"
  ;;
  remove)
    echo "Removing $target"
    dotlaser_remove "$target"
  ;;
  install)
    echo "Installing dotfiles"
    dotlaser_install
  ;;
  update)
    echo "Updating dotlaser"
    dotlaser_update
  ;;
  list)
    dotlaser_list
  ;;
  uninstall)
    echo "Uninstalling dotfiles"
    dotlaser_uninstall
  ;;
esac

