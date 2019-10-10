#! /usr/bin/env bash
#-- Dave Wallraff

# First things first, I'm the realest...

## Set some vars
export EDITOR="vim"
export GOPATH=$HOME/code/go
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin:~/.local/bin:/usr/local/go/bin:$GOPATH/bin
TODAY=$(date "+%Y%m%d") && export TODAY

## Write some functions

# Check for requirements
function check_command {

    if [ ! "$(command -v "$1")" ];
    then
        echo "command $1 was not found"
        return 1
    fi
}


# Log into 1Password CLI
function op_login {
    
    # Check if op is installed
    check_command op
    if [ "$?" -ne 0 ]; then
        echo "The op cli is not installed. Aborting..."
        return 1
    fi
    
    echo "Logging into op"
    # Check if op is logged in
    op list users > /dev/null 2>&1
    
    # if not, log in or die trying
    if [ $? -ne 0 ]; then
        eval "$(op signin my.1password.com dave.wallraff@gmail.com)"
        if [ $? -ne 0 ]; then
            echo "op login failed. Aborting..."
            return 1
        fi
    fi
}


# Create a slug from a string
# https://gist.github.com/oneohthree/f528c7ae1e701ad990e6
function slugify {

    echo "$1" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr '[:upper:]' '[:lower:]'
}


# Create an encrypted tarball
function enc_tar {

    # Get some names and stuff
    BASE=$(basename "$1")
    TARBALL=$(slugify "$BASE")
    
    # Log in to op
    op_login
    if [ $? -ne 0 ]; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Dump op tar password from op into fd:3
    # https://unix.stackexchange.com/questions/29111/safe-way-to-pass-password-for-1-programs-in-bash#answer-29186
    echo "Getting op encrypted tarball password. This can take a hot minute....."
    exec 3<<<"$(op get item encrypted_tar_password | jq -r '.details.fields[] | select(.name=="password") | .value')"
    if [ $? -ne 0 ]; then
        echo "Unable to dump op encrypted tarball password to fd:3. Aborting..."
        return 1
    fi

    # Use that password to encrypt the tarball
    echo "Tar'ing up '$1'" 
    tar hcz "$1" | gpg --batch --cipher-algo AES256 --passphrase-fd 3 --symmetric --output "$TARBALL".tar.gz.enc > /dev/null
    if [ $? -ne 0 ]; then
        echo "Creating an encrypted tarball failed. Aborting..."
        return 1
    fi
}


# Decrypt an encrypted tarball
function dec_tar {

    # Strip the extensions so we know dir to put this into
    SHORT=$(basename "$1" .tar.gz.enc)
    mkdir -p "$SHORT"
    mv "$1" "$SHORT"/. || die
    
    # Log in to op
    op_login
    if [ $? -ne 0 ]; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Dump op tar password from op into fd:3
    # https://unix.stackexchange.com/questions/29111/safe-way-to-pass-password-for-1-programs-in-bash#answer-29186
    echo "Getting op encrypted tarball password. This can take a hot minute....."
    exec 3<<<"$(op get item encrypted_tar_password | jq -r '.details.fields[] | select(.name=="password") | .value')"
    if [ $? -ne 0 ]; then
        echo "Unable to dump op encrypted tarball password to fd:3. Aborting..."
        return 1
    fi


    # Use that password to decrypt the tarball
    cd "$SHORT" || die
    echo "Untar'ing '$1'" 
    gpg --no-verbose --quiet --batch --cipher-algo AES256 --passphrase-fd 3 --decrypt "$1" | tar xz
    if [ $? -ne 0 ]; then
        echo "Decrypting an encrypted tarball failed. Aborting..."
        return 1
    fi

    cd .. || die
}


# Create an encrypted tarball and upload it to google drive
function gdrive_backup {

    # Check if rclone is installed
    check_command rclone
    if [ "$?" -ne 0 ]; then
        echo "The rclone cli is not installed. Aborting..."
        return 1
    fi
    
    # Get some names and stuff
    BASE=$(basename "$1")
    SLUG=$(slugify "$BASE")
    TARBALL_NAME="$TODAY"_"$SLUG"
    
    # Log in to op
    op_login
    if [ $? -ne 0 ]; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Dump op tar password from op into fd:3
    # https://unix.stackexchange.com/questions/29111/safe-way-to-pass-password-for-1-programs-in-bash#answer-29186
    echo "Getting op encrypted tarball password. This can take a hot minute....."
    exec 3<<<"$(op get item encrypted_tar_password | jq -r '.details.fields[] | select(.name=="password") | .value')"
    if [ $? -ne 0 ]; then
        echo "Unable to dump op encrypted tarball password to fd:3. Aborting..."
        return 1
    fi

    # Use that password to encrypt the tarball
    echo "Tar'ing up '$1'" 
    tar hcz "$1" | gpg --batch --cipher-algo AES256 --passphrase-fd 3 --symmetric --output "$TARBALL_NAME".tar.gz.enc > /dev/null
    if [ $? -ne 0 ]; then
        echo "Creating an encrypted tarball failed. Aborting..."
        return 1
    fi

    # Copy to gdrive
    echo "Copying to gdrive"
    rclone copy "$TARBALL_NAME".tar.gz.enc "gdrive:/archive/encrypted backups" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Copying to rclone failed"
    fi

    # Clean up
    echo "Cleaning up"
    rm "$TARBALL_NAME".tar.gz.enc
    if [ $? -ne 0 ]; then
        echo "Clean up failed"
    fi
}


# Upload file to 1Password
function add_to_op {

    # Check that we got a file, not a dir
    if [[ ! -f "$1" ]]; then
        echo "This only works with files. Please hang up and dial your extension again."
        return 1
    fi

    # Then set some vars
    BASE=$(basename "$1")
    SLUG=$(slugify "$BASE")
    OLD_DOC=""

    # Now that we're good, log into op
    op_login
    if [ $? -ne 0 ]; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Find anything currently there
    echo "Looking for older versions of $SLUG. This can take a hot minute....."
    # shellcheck disable=2016
    OLD_DOC=$(op list documents | jq -r '. as $in | keys[] | select($in[.].overview.title | contains("'"$SLUG"'")) | select($in[.].trashed=="N") as $res | $in[$res].uuid')
    
    # Let us know if it's a new doc
    if [ -n "$OLD_DOC" ]; then
        echo "Looks like we found an older version of $SLUG with an id of $OLD_DOC. We'll clean that up later."
    fi

    # Upload a new rclone to 1password
    echo "Creating new $SLUG doc"
    op create document "$1" --title="$SLUG" --vault="Personal" --tags="uploaded_by_cli" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Doc creation failed"
    fi

    # If there was an old doc, let's delete it
    if [ -n "$OLD_DOC" ]; then
        echo "Deleting the old one"
        op delete item "$OLD_DOC" > /dev/null
    fi
}


# Get info about my ip address
function ipinfo {

    if [ $# -eq 0 ]; then
        curl -s ip-api.com
    else
        curl -s ip-api.com/"$1"
    fi
}


# Get the weather
function weather {
    
    if [ $# -eq 0 ]; then
        LOC="$(curl -s ip-api.com/json | jq -r .country)"
        clear
        curl -s http://wttr.in/"$LOC"?FQ2
    else
        clear
        curl -s http://wttr.in/"$1"?FQ2
    fi
}


# Find out git branch for prompt
function parse_git_branch {

    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "(${ref#refs/heads/})"
}


# Set some aliases
alias more="less"
alias ls="ls --color"
alias grep='grep --color=always'
alias less='less -R'
alias tmuxre='tmux new -ADs default'
alias jumpbox="ssh jumpbox -t 'tmux new -ADs jumpbox'"
alias start_jumpbox="gcloud compute instances start jumpbox"
alias stop_jumpbox="gcloud compute instances stop jumpbox"

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

# Prompts rule everything around me, PREAM, set the vars, $$ y'all
function prompt {
    local RESET='\[\e[0m\]'
    local blue='\[\e[36m\]'
    local red='\[\e[31m\]'
    local gold='\[\e[33m\]'
    export PS1="\n\`if [ \$? = 0 ]; then echo ${blue}; else echo ${red}; fi\`\u@\h\n ${blue}\w ${gold}\$(parse_git_branch)${blue} > ${RESET}"
}

# Set up ssh to use gpg-agent
# shellcheck disable=2155
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye
unset SSH_AGENT_PID
# shellcheck disable=2155
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

prompt
