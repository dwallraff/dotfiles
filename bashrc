#! /usr/bin/env bash

### Global shellcheck disables
# shellcheck disable=2181
# shellcheck disable=2155
# shellcheck disable=1090


#-- Dave Wallraff

# First things first, I'm the realest...

## Set some vars
export EDITOR="vim"
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin:~/.local/bin

## Add some functions
if [ -f "$HOME"/.bash_functions ]; then
    source "$HOME"/.bash_functions
fi

# Find out git branch for prompt
function parse_git_branch {

    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "(${ref#refs/heads/})"
}

# Prompts rule everything around me, PREAM, set the vars, $$ y'all
function prompt {
    local RESET='\[\e[0m\]'
    local blue='\[\e[36m\]'
    local red='\[\e[31m\]'
    local gold='\[\e[33m\]'
    export PS1="\n\`if [ \$? = 0 ]; then echo ${blue}; else echo ${red}; fi\`\u@\h\n ${blue}\w ${gold}\$(parse_git_branch)${blue} > ${RESET}"
}


# Set some aliases
alias more="less"
alias ls="ls -G"
alias grep='grep --color=always'
alias less='less -R'
alias tmuxre='tmux new -ADs default'
alias calibre_connect='sudo sshfs -o allow_other,reconnect,auto_cache dwallraff@library.davewallraff.com:/home/dwallraff/library library'
alias op_login='eval "$(op signin my.1password.com dave.wallraff@gmail.com)"'
alias calibre_upgrade='wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin'

# Spelling is hard
alias histroy="history"
alias ptyhon=python
alias pyhton=ptyhon
alias sl=ls
alias alisa="alias"
alias vi=vim
alias auso=sudo
alias sudp=sudo

# Set vi as line editor
set -o vi

# crotini fix for docker
if [ -f /var/run/docker.sock ]; then
	sudo chmod 666 /var/run/docker.sock
fi

# If on a mac, set up ssh to use gpg-agent
if [[ $(uname -s) == "Darwin" ]]; then
	export GPG_TTY=$(tty)
	gpg-connect-agent updatestartuptty /bye
	unset SSH_AGENT_PID
	export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
fi

sudo chmod 666 /var/run/docker.sock
prompt
