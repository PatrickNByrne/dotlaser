# dotlaser
[![GitHub issues](https://img.shields.io/github/issues/patricknbyrne/dotlaser.svg)](https://github.com/PatrickNByrne/dotlaser/issues)
[![license](https://img.shields.io/github/license/patricknbyrne/dotlaser.svg)](https://github.com/PatrickNByrne/dotlaser/blob/master/LICENSE)

A bash script to make managing your dotfiles effortless and precise.

### Key Features

* Dependency adverse - You shouldn't need a development environment to setup your dotfiles
* Automatic backups when installing or removing files - To err is human, having backups, divine
* Single target installation and profile support - Sometimes you DON'T need the kitchen sink...
* Supports multiple installation methods and version control systems - My way or your way, your choice
* Automatic updates - Banish bugs with ease
* Comprehensive test suite - All changes to the core code are thoroughly vetted

## Installing

Installing requires just two steps, cloning the repository, and bootstrapping the dotfiles folder. If you are using git to manage your dotfiles, you can install the script as a submodule or subtree. Other version control systems are supported as well via the manual installation method below. 

#### Subtree

Subtree installation adds this module to your git repository in its entirety. When cloning your dotfiles repo to a new computer, you will not have to initialize the dotlaser module. This is the preferred installation method. When bootstrapping, select the "link" method to enjoy the most effortless dotlaser experience. 

###### Example
```
cd <your dotfiles directory>  
git subtree add --prefix dotlaser/ https://github.com/PatrickNByrne/dotlaser master --squash  
./dotlaser/dotlaser.sh -b ./
```

#### Submodule

Submodule installation adds dotlaser to your git repository as a link. When cloning your dotfiles repo to a new system, you will have to initialize this module before it can be used (unless you use the "hard" bootstrapping option). 

###### Example
```
cd <your dotfiles directory>  
git submodule add https://github.com/PatrickNByrne/dotlaser ./dotlaser
./dotlaser/dotlaser.sh -b ./
```

#### Manual Installation

To install manually, clone the dotfiles repository to any location you choose. You can place this repo directly into your VCS directory for tracking, or bootstrap in "hard" mode and delete the repository altogether. 

###### Example
```
git clone https://github.com/PatrickNByrne/dotlaser 
./dotlaser/dotlaser.sh -b ./  
```

### Bootstrapping

Bootstrapping prepares your dotfiles directory for use with dotlaser. The default configuration files are created and the user is prompted to select an installation method. The installation methods are discussed below. 

#### Hard

Hard mode copies the dotlaser script into your target dotfiles directory.

#### Link

Link mode creates a symbolic link to the dotlaser script, in your dotfiles directory.

#### Manual

When you select manual mode, only the configuration files are created in your dotfiles directory. You must then move or link the script to an appropriate location. 

## Configuration

All script configurations are contained in the user's dotlaserrc file. By default, dotlaser looks for this file in the users home directory ` ~/.dotlaserrc` or the directory that it was launched from. 

All files managed by dotlaser are stored in the users dotfiles directory and configured in `dotlaser.files`.

## Usage

Using dotlaser consists of adding and removing files from your VCS and then linking them to their appropriate locations.

#### Add a file/folder

When you add a file/folder to dotlaser, the target is copied to your dotfiles folder and added to your default file list. You can also use the "-p" flag to specify a profile to add the file to instead of the default. 
NOTE: Hidden files/folders (filename starts with .) have their leading "." stripped prior to addition to the dotfiles directory"

###### Example
`dotlaser.sh -a ~/.vimrc`  

#### Remove a file/folder

When you remove a file/folder, the target is deleted from your dotfiles folder and removed from your file list.

###### Example
`dotlaser.sh -r ~/.vimrc`  

#### Install dotfiles

When installing, the target location is read from your file list and a symbolic link is created that refers to the file/folder in your dotfiles directory. By default, the installation flag with no arguments will install all default profile dotfiles. To install another profile, simply specify the profile with the "-p" flag. You can also install only a single file by passing the file name with the installation flag. 

###### Example
`dotlaser.sh -i`  

#### Updating

You can update dotlaser automatically in most cases. First you must configure your dotlaserrc to specify the `dotlaser_git_dir` and `dotlaser_updatetype`. The "dotlaser_git_dir" is the location that dotlaser is installed, or you would like to clone dotlaser into. The "dotlaser_updatetype" indicates the way dotlaser will update. Use subtree or submod if you've installed dotlaser as a subtree or submodule.

###### Example
`dotlaser.sh -u`

#### Uninstall dotfiles

Uninstalling will remove all linked files from their installed locations.

###### Example
`dotlaser.sh --uninstall`  


