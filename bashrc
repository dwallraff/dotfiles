#-- Dave Wallraff

export EDITOR="vim"
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/sbin:/usr/sbin:/usr/local/sbin

######
# Old school stuff
######

# Every 'cd', is also a 'pushd'
function cd {
     oldir=`pwd`
     builtin cd "$@" || return $?
     newdir=`pwd`
     builtin cd "$oldir"
     pushd "$newdir" > /dev/null
}

######
# Git stuff
#####

# Find out git branch
function parse_git_branch {
    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "("${ref#refs/heads/}")"
}


######
# Aliases
#####

alias more="less"
alias ls="ls --color"

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
