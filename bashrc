#! /usr/bin/env bash
#-- Dave Wallraff

export EDITOR="vim"
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/sbin:/usr/sbin:/usr/local/sbin:~/.local/bin

######
# Old school stuff
######

# Log into 1Password CLI
function op_login {

######
# Backup stuffs
#####

# backup rclone config
function rclone_config_backup {

    # Always important
    TODAY=$(date "+%Y%m%d")

    # Check if op is logged in
    op list users > /dev/null 2 >& 1

    # if not, log in
    if [ $? -ne 0 ]; then
        eval "$(op signin my)"
    fi

    # Dump openssl tar password from op into fd:3
    exec 3<<<"$(op get item openssl_tar_password | jq -r '.details.password')"

    # Use that password to encrypt rclone with a date
    tar cz "$HOME"/.rclone.conf | openssl enc -e -aes-256-cbc -salt -md sha256 -pass fd:3 -out "$TODAY"_rclone_conf.tar.gz.enc || exit
    
    # Copy to gdrive
    rclone copy "$TODAY"_rclone_conf.tar.gz.enc gdrive:/archive/rclone_config || exit

    # Clean up
    rm "$TODAY"_rclone_conf.tar.gz.enc

    # Get the current rclone 1password doc id
    OLD_DOC=$(op list documents | jq -r '. as $in | keys[] | select($in[.].overview.title | contains("rclone.conf")) | select($in[.].trashed=="N") as $res | $in[$res].uuid')
    
    # Upload a new rclone to 1password
    op create document ~/.rclone.conf --title="rclone.conf" || exit

    # Delete the old one
    op delete item "$OLD_DOC"

}

# backup sublime gist config
function sublime_gist_config_backup {

    # Always important
    TODAY=$(date "+%Y%m%d")

    # Check if op is logged in
    op list users > /dev/null 2 >& 1

    # if not, log in
    if [ $? -ne 0 ]; then
        eval "$(op signin my)"
    fi

    # Dump openssl tar password from op into fd:3
    exec 3<<<"$(op get item openssl_tar_password | jq -r '.details.password')"

    # Use that password to encrypt rclone with a date
    tar cz "$HOME"/.config/sublime-text-3/Packages/User/Gist.sublime-settings | openssl enc -e -aes-256-cbc -salt -md sha256 -pass fd:3 -out "$TODAY"_sublime_gist_settings.tar.gz.enc || exit
    
    # Copy to gdrive
    rclone copy "$TODAY"_sublime_gist_settings.tar.gz.enc gdrive:/archive/sublime_gist_settings || exit

    # Clean up
    rm "$TODAY"_sublime_gist_settings.tar.gz.enc

    # Get the current rclone 1password doc id
    OLD_DOC=$(op list documents | jq -r '. as $in | keys[] | select($in[.].overview.title | contains("-title="Gist.sublime-settings")) | select($in[.].trashed=="N") as $res | $in[$res].uuid')
    
    # Upload a new rclone to 1password
    op create document ~/.config/sublime-text-3/Packages/User/Gist.sublime-settings --title="Gist.sublime-settings" || exit

    # Delete the old one
    op delete item "$OLD_DOC"

}


######
# Git stuff
#####

# Find out git branch
function parse_git_branch {
    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "(${ref#refs/heads/})"
}


######
# Aliases
#####

alias more="less"
alias ls="ls --color"
alias tmuxre='tmux attach-session -t default || tmux new-session -s default'

#Typos
alias histroy="history"
alias ptyhon=python
alias pyhton=ptyhon
alias sl=ls
alias alisa="alias"
alias vi=vim

#-- Set vi as line editor
set -o vi

#-- Color prompt
function prompt {
    local RESET='\[\e[0m\]'
    local blue='\[\e[36m\]'
    local red='\[\e[31m\]'
    local gold='\[\e[33m\]'
    export PS1="\n\`if [ \$? = 0 ]; then echo ${blue}; else echo ${red}; fi\`\u@\h\n ${blue}\w ${gold}\$(parse_git_branch)${blue} > ${RESET}"
}
prompt
