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
alias ls="ls -G"
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

    # Set SSH auth for yubikey
	yubikey_fix () {
        export GPG_TTY=$(tty)
        gpg-connect-agent updatestartuptty /bye
        unset SSH_AGENT_PID
        export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
        # gpgconf --kill all
    }

    # Some work aliases
    alias proxy-off='export HTTP_PROXY=; export HTTPS_PROXY=; export http_proxy=; export https_proxy=; export ALL_PROXY=; export all_proxy='
    alias proxy-on='export HTTP_PROXY=http://proxy.kohls.com:3128; export HTTPS_PROXY=http://proxy.kohls.com:3128; export http_proxy=http://proxy.kohls.com:3128; export https_proxy=http://proxy.kohls.com:3128; export ALL_PROXY=http://proxy.kohls.com:3128; export all_proxy=http://proxy.kohls.com:3128'
    alias vault_kvhome='export VAULT_ADDR=https://vault-us-central1-primary.kohls.com:8200; vault login -method=oidc -path=okta-oidc role=hcvdefault'
    alias vault_mosaic='ssh -fnNT -L localhost:8201:10.208.120.85:8201 jumpbox; export VAULT_ADDR=https://localhost:8201; vault login -method=ldap username=tkma46k'
	
    yubikey_fix

fi

# Chromebook/linux specific stuff
if [[ $(uname -s) == "Linux" ]]; then

    # Set permissions for docker
	if [ -f /var/run/docker.sock ]; then
	    sudo chmod 666 /var/run/docker.sock
    fi

    # Some chromebook aliases
    alias calibre_connect='sudo sshfs -o allow_other,reconnect,auto_cache dwallraff@library.davewallraff.com:/home/dwallraff/library library'
    alias calibre_upgrade='wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin'

	# golang stuff
	if [ -d "/usr/local/go/bin" ] ; then
		export PATH="$PATH:/usr/local/go/bin"
	fi

fi

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
}

prompt
