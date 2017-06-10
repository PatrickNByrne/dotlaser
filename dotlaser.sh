#!/bin/bash
# ------------------------------------------------------------------
# Author: Patrick Byrne
# Title: dotlaser
# Description:
#       Manage your dotfiles precisely and effortlessly
# ------------------------------------------------------------------
#    Todo:
#        Fix update function
#        On remove - check if installed and prune
#        Make sure this works in zsh and osx - (sed -i)
# ------------------------------------------------------------------

version=0.1.4

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

      -h Print this message
      -v Print the current dotlaser version
      -c Specify a config file
      -b Bootstrap your dotfiles directory
      -a Add a file or directory to your dotfiles
      -r Remove a file or directory from your dotfiles
      -i Install all managed dotfiles
      -u Update dotlaser
      -l List all managed dotfiles and their status

      --help same as -h
      --version same as -v
      --config same as -c
      --bootstrap same as -b
      --add same as -a
      --remove same as -r
      --install same as -i
      --update same as -u
      --list same as -l
      --uninstall Uninstall all managed dotfiles
STOP
}

dotlaser_abspath()
{
    [[ -z "$1" ]] && echo "Error: Null Path" && exit 1
    if [[ "$task" = "install" ]] || [[ "$task" = "list" ]]; then
        if [[ "$1" = '$HOME'* ]]; then
            echo "$1" | sed "s@\$HOME@$HOME@"
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
        echo "$1" | sed "s@$HOME@\$HOME@"
    else
        echo "$1"
    fi
}

dotlaser_loadconfig()
{
    # Set the default config file if not specified
    if [[ -z $dotlaser_config ]]; then
        dotlaser_config="$(dotlaser_abspath $(dirname "$0")/dotlaserrc)"
    fi
    # Verify config file is sane and source it
    if [[ ! -f $dotlaser_config ]]; then
        echo "Error: Unable to read config file: $dotlaser_config"
        exit 1
    else
        echo "Reading config file: $dotlaser_config"
        source "$dotlaser_config"
    fi
    # Skip path verification if bootstrapping 
    [[ "$task" = "bootstrap" ]] && return 
    # Verify paths in config file are sane
    if [[ ! -e "$dotfiles_dir" ]]; then
        echo "$dotfiles_dir does not exist. Please check your config"
        exit 1
    elif [[ ! -e "$dotfiles_config" ]]; then
        echo "$dotfiles_config does not exist. Please check your config"
        exit 1
    fi
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
	[[ -e "$dotfiles_backup_dir/old/$(basename "$1")" ]] && rm -R "$dotfiles_backup_dir/old/$(basename "$1")"
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
    touch "$1/dotlaser.files"
    # Check if config file already exists
    if [[ -f "$1/dotlaserrc" ]]; then
        # Verify removal
        printf "You're about to overwrite %s\n" "$1/dotlaserrc"
        read -p "Is this correct? [y/N]: " user_choice
        user_choice="${user_choice:0:1}"
        [[ ! ${user_choice,,} = "y" ]] && exit
    fi
    # Copy and update our cfg file
    cp "$dotlaser_dir/dotlaserrc" "$1"
    sed -i "s@dotfiles_dir=.*@dotfiles_dir=\"$(dotlaser_relpath "$1")\"@g" "$1/dotlaserrc"
    printf "How would you like to install? [1 - Hard Copy, 2 - Link, 3 - Manually]\n"
    read -p "Please select install option [1,2,3]: " user_choice
    case "$user_choice" in
        1)
            echo "Installing in hard copy mode"
            # Copy the dotlaser script to our dotfiles dir
            cp "$dotlaser_path" "$1"
            ;;
        2)
            echo "Installing in link mode"
            # Check if target is in user's HOME
	    if [[ "$(dotlaser_abspath "$dotlaser_path")" = *"$(dotlaser_abspath "$HOME")"* ]]; then
                userhome="$(dotlaser_abspath "$HOME")"
		rellink="$(echo $(dotlaser_abspath "$1") | sed -e "s@$userhome@@" -e 's@[^/]@@g' -e 's@/@../@g')"
                reltarget="$(echo $(dotlaser_abspath "$dotlaser_path") | sed "s@$userhome/@@")"
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
    git --version 2>&1 >/dev/null
    [[ "$?" -ne "0" ]] && echo "Error: git not found" && exit 1
    # Process the update type config variable
    case "$dotlaser_updatetype" in
        hard)
            echo "Starting hard update"
            # Check if a git directory is specified and set default
            [[ -z "$dotlaser_gitdir" ]] && dotlaser_gitdir="/tmp/dotlaser"
            # Check the git dir and create it if required
            if [[ ! -d "$dotlaser_gitdir" ]]; then
                mkdir -p "$dotlaser_gitdir"
            fi
            # Get into the git dir and update/clone
            (
            cd "$dotlaser_gitdir"
            if [[ -e "$dotlaser_gitdir/.git" ]]; then
                # Check for changes in dotlaser repo dir
                git ls-files -o | grep >/dev/null . && echo "Warning: There are uncommited files in $dotlaser_gitdir"
                git diff --quiet
                if [[ "$?" -ne "0" ]]; then
                    echo "Error: Changes detected in $dotlaser_path"
                    exit 1
                fi
                git fetch -p
                git checkout --force "origin/master"
            else
                git clone --depth=1 "$dotlaser_repo" .
            fi
            # Get new script version
            dotlaser_version="$(grep "^version=" "$dotlaser_gitdir/dotlaser.sh" | sed 's/^version=//')"
            # Verify overwrite
            printf "You're about to update dotlaser from version %s to %s\n" "$version" "$dotlaser_version" 
            printf "Overwriting %s with %s\n" "$dotlaser_path" "$dotlaser_gitdir/dotlaser.sh"
            read -p "Is this correct? [y/N]: " user_choice
            user_choice="${user_choice:0:1}"
            [[ ! ${user_choice,,} = "y" ]] && exit 0
            cp "$dotlaser_gitdir/dotlaser.sh" "$dotlaser_path"
            )
            ;;
        subtree)
            [[ -z "$dotlaser_gitdir" ]] && echo "Error: Can't find git dir" && exit 1
            (
            cd "$dotfiles_dir"
            # Check for changes in dotlaser repo dir
            git ls-files -o | grep >/dev/null . && echo "Warning: There are uncommited files in $dotlaser_gitdir"
            git diff --quiet
            if [[ "$?" -ne "0" ]]; then
                echo "Error: Changes detected in $dotlaser_path"
                exit 1
            fi
            git subtree pull --prefix="$dotlaser_gitdir" --squash $dotlaser_repo master
            dotlaser_version="$(grep "^version=" "$dotlaser_gitdir/dotlaser.sh" | sed 's/^version=//')"
            printf "Updated from version %s to %s\n" "$version" "$dotlaser_version"
            )
            echo "Don't forget to commit your changes!"
            ;;
        submod)
            [[ -z "$dotlaser_gitdir" ]] && echo "Error: Can't find git dir" && exit 1
            (
            cd "$dotlaser_dir"
            # Check for changes in dotlaser repo dir
            git ls-files -o | grep >/dev/null . && echo "Warning: There are uncommited files in $dotlaser_gitdir"
            git diff --quiet
            if [[ "$?" -ne "0" ]]; then
                echo "Error: Changes detected in $dotlaser_path"
                exit 1
            fi
            git checkout -f master
            git pull --squash
            dotlaser_version="$(grep "^version=" "$dotlaser_gitdir/dotlaser.sh" | sed 's/^version=//')"
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
        target_basename="$(echo "$target_basename" | sed 's/^.//')"
    fi
    # Create relative paths
    target_relpath="$(dotlaser_relpath "$1")"
    dotfile_relpath="$(dotlaser_relpath "$dotfiles_dir/$target_basename")"
    # Copy the target file to dotfiles location
    cp -a "$1" "$dotfiles_dir/$target_basename"
    # Add the target file to dotlaser file list
    echo "$target_relpath:$dotfile_relpath:$dotlaser_filetype" >> "$dotfiles_config"
}

dotlaser_remove()
{
    target="$(dotlaser_relpath "$target")"
    # Read in the config file entry for target 
    IFS=':' read -r target dotfiles_target dotlaser_filetype <<<"$(grep -m 1 "$target:" "$dotfiles_config")"
    # Check if the file was found in the config
    if [[ -z $dotfiles_target ]]; then
        echo "Error: File not found in config"
        exit 1
    fi
    dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
    # Verify removal
    printf "You're about to remove %s from your dotfiles directory\n" "$dotfiles_target"
    read -p "Is this correct? [y/N]: " user_choice
    user_choice="${user_choice:0:1}"
    [[ ! ${user_choice,,} = "y" ]] && exit 0
    # Remove file from config
    sed -i "\,^$target:.*$,d" "$dotfiles_config"
    # Bail if the target doesn't exist
    [[ ! -e "$dotfiles_target" ]] && return
    # Verify removal target is in the dotfiles directory
    if [[ "$(echo "$dotfiles_target" | grep "^$dotfiles_dir")" = "$dotfiles_target" ]]; then
        # Backup the files
        dotlaser_backup "$dotfiles_target"
        # Delete them
        rm -r "$dotfiles_target"
    fi
}    
        
dotlaser_install()
{
    # Loop through the config file
    while IFS=':' read -r target dotfiles_target dotlaser_filetype <&9; do
        target="$(dotlaser_abspath "$target")"
        dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
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
                    read -p "Is this correct? [y/N]: " user_choice
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
    done 9< "$dotfiles_config"
}

dotlaser_uninstall()
{
    # Loop through the config file
    while IFS=':' read -r target dotfiles_target dotlaser_filetype <&9; do
        target="$(dotlaser_abspath "$target")"
        dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
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
    done 9< "$dotfiles_config"
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
    printf "%-30s | %-30s | %-20s\n" "Target" "File Type" "Status" | tr " " "_"
    while IFS=':' read -r target dotfiles_target dotlaser_filetype; do
        target="$(dotlaser_abspath "$target")"
        dotfiles_target="$(dotlaser_abspath "$dotfiles_target")"
        dotlaser_status "$target" "$dotfiles_target"
        printf "%-30s | %-30s | %-20s\n" "$target" "${dotlaser_filetype^}" "$dotlaser_status"
    done <"$dotfiles_config"
    echo
}

# --- Options processing -------------------------------------------

while [[ $# -gt 0 ]]; do
    param=$1
    value=$2
    case $param in
        -h | --help | help)
            usage
            exit
            ;;
        -v | --version | version)
            version
            exit
            ;;
        -c | --config)
            dotlaser_config="$(readlink -m "$value")"
            shift
            ;; 
        -b | --bootstrap | bootstrap)
            task="bootstrap"
            target="$(readlink -m "$value")"
            shift
            ;; 
        -a | --add | add)
            task="add"
            target="$(readlink -m "$value")"
            shift
            ;; 
        -r | --remove | remove)
            task="remove"
            target="$(readlink -m "$value")"
            shift
            ;; 
        -i | --install | install)
            task="install"
            ;; 
        -u | --update | update)
            task="update"
            ;; 
        -l | --list | list)
            task="list"
            ;; 
        --uninstall | uninstall)
            task="uninstall"
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

# Get paths for the calling script and default dir
dotlaser_path="$(dotlaser_abspath "${BASH_SOURCE[0]}")"
dotlaser_dir="$(dirname "$dotlaser_path")"

# Check if "task" is not set, print usage, and exit
[[ -z $task ]] && usage && exit 1

dotlaser_loadconfig

# Task Logic
case $task in
    bootstrap)
        echo "Bootstrapping $target"
        dotlaser_target $target
        dotlaser_bootstrap $target
        ;;
    add)
        echo "Adding $target"
        dotlaser_target $target
        dotlaser_add $target
        ;;
    remove)
        echo "Removing $target"
        dotlaser_target $target
        dotlaser_remove $target
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
        echo "Listing dotfiles"
        dotlaser_list
        ;;
    uninstall)
        echo "Uninstalling dotfiles"
        dotlaser_uninstall
        ;;
    esac

