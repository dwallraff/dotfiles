#! /usr/bin/env bash

### Global shellcheck disables
# shellcheck disable=2181
# shellcheck disable=2155
# shellcheck disable=1090


#-- Dave Wallraff

# First things first, I'm the realest...

## Generic defaults
export EDITOR="vim"
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin:~/.local/bin:$PATH

# Set some aliases
alias more="less"
alias ls="ls --color=auto"
alias grep='grep --color=always'
alias less='less -R'
alias tmuxre='tmux new -ADs default'
alias op_login='eval "$(op signin my.1password.com dave.wallraff@gmail.com)"'

# Spelling is hard so here are some more aliases
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

######

## Specific things

# Mac specific stuff
if [[ $(uname -s) == "Darwin" ]]; then

    # Fix some path stuff for homebrew
    eval "$(/opt/homebrew/bin/brew shellenv)"
	export PATH=$PATH:/opt/homebrew/bin

    # Setup yubikey for ssh
    export GPG_TTY="$(tty)"
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

    # Some work aliases
    alias proxy-off='export HTTP_PROXY=; export HTTPS_PROXY=; export http_proxy=; export https_proxy=; export ALL_PROXY=; export all_proxy='
    alias proxy-on='export HTTP_PROXY=http://proxy.kohls.com:3128; export HTTPS_PROXY=http://proxy.kohls.com:3128; export http_proxy=http://proxy.kohls.com:3128; export https_proxy=http://proxy.kohls.com:3128; export ALL_PROXY=http://proxy.kohls.com:3128; export all_proxy=http://proxy.kohls.com:3128'

fi

# Chromebook/linux specific stuff
if [[ $(uname -s) == "Linux" ]]; then

    # Set permissions for docker
	if [ -f /var/run/docker.sock ]; then
	    sudo chmod 666 /var/run/docker.sock
    fi

    # Some chromebook aliases
    alias calibre_upgrade='wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin'
	
	# golang stuff
	if [ -d "/usr/local/go/bin" ] ; then
		export PATH="$PATH:/usr/local/go/bin"
	fi

fi

# Re-do gpg-agent.conf, re-set variables for yubikey ssh
function yubikey_fix () {

    if [[ $(uname -s) == "Darwin" ]]; then
        # Setup env vars for yubikey ssh
        export GPG_TTY="$(tty)"
        export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

        # Reset th conf file
        cp ~/code/dotfiles/gpg-agent.conf ~/.gnupg/gpg-agent.conf

        # Bounce the agent
        gpgconf --kill gpg-agent
        gpgconf --launch gpg-agent
    fi
}

yubikey_fix

#####

## Prompt stuff

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
    export PS1="\n\`if [ \$? = 0 ]; then echo ${blue}; else echo ${red}; fi\`\u@\h\n\D{%H:%M:%S} ${blue}\w ${gold}\$(parse_git_branch)${blue} > ${RESET}"
	export LS_COLORS="di=1;34:ln=1;35:so=1;0;1;41:pi=1;0;1;41:ex=1;32:bd=1;0;1;45:cd=1;0;1;45:su=1;31:sg=1;31:tw=1;36:ow=1;36"
}

prompt
