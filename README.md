# dotlaser
#### Zap your configs!

## Installing

dotlaser can be installed in many way. If you are using git to manage your dotfiles, you can install the script as a submodule or subtree.
Other version control systems are supported as well via the manual installation method. 

### Subtree

Subtree installation adds this module to your git repository in its entirety. When cloning your dotfiles repo to a new computer, you will not have to initialize the dotlaser module. This is the preferred installation method. When bootstrapping, select the "link" method to enjoy the most effortless dotlaser experience. 

###### Example
<code>cd &lt;your dotfiles directory&gt;</code>  
<code>git subtree add --prefix dotlaser/ https://github.com/PatrickNByrne/dotlaser master --squash</code>  
<code>./dotlaser/dotlaser.sh -b .</code>

### Submodule

Submodule installation adds dotlaser to your git repository as a link. When cloning your dotfiles repo to a new system, you will have to initialize this module before it can be used (unless you use the "hard" bootstrapping option). 

###### Example
<code>cd &lt;your dotfiles directory&gt;</code>  
<code>git submodule add https://github.com/PatrickNByrne/dotlaser ./dotlaser</code>  
<code>./dotlaser/dotlaser.sh -b .</code>

### Manually

Manual installation will clone the dotfiles repository to any location you choose. You can place this repo directly into your VCS directory for tracking, or bootstrap in "hard" mode and delete the repository altogether. 

###### Example
<code>git clone https://github.com/PatrickNByrne/dotlaser</code>  
<code>./dotlaser/dotlaser.sh -b .</code>  

## Bootstrapping

Bootstrapping prepares your dotfiles directory for use with dotlaser. The two default configuration files are created and the user is prompted to select an installation method. The installation methods are discussed below. 

### Hard
Hard mode copies the dotlaser script into your target dotfiles directory.

### Link
Link mode creates a symbolic link to the dotlaser script, in your dotfiles directory.

### Manual
When you select manual mode, only the configuration files are created in your dotfiles directory. You must then move or link the script to an appropriate location. 

## Configuration

All script configurations are contained in the user's dotlaserrc file. By default, dotlaser looks for this file in the users home directory <code> ~/.dotlaserrc</code> or the directory that it was launched from. 

All files managed by dotlaser are stored in the users dotfiles directory and configured in <code>dotlaser.files</code>.

## Usage

Using dotlaser consists of adding and removing files from your VCS and then linking them to their appropriate locations.

### Add a file/folder

When you add a file/folder to dotlaser, the target is copied to your dotfiles folder and added to your file list.

###### Example
<code>dotlaser.sh -a ~/.vimrc</code>  

### Remove a file/folder

When you remove a file/folder, the target is deleted from your dotfiles folder and removed from your file list.

###### Example
<code>dotlaser.sh -r ~/.vimrc</code>  

### Install dotfiles

When installing, the target location and the target file/folder are read from your file list. Then a symbolic link is created in the target location that refers to the file/folder in your dotfiles directory. 

###### Example
<code>dotlaser.sh -i</code>  

### Uninstall dotfiles

Uninstalling will remove all linked files from their installed locations.

###### Example
<code>dotlaser.sh --uninstall</code>  

