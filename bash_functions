#! /usr/bin/env bash

# Check for requirements
function check_command {

    if [ ! "$(command -v "$1")" ]; then
        echo "command $1 was not found"
        return 1
    fi
}

function hw {

#   exec 3<<<"test"
    echo "test" >&3

}

function hw2 {
    cat <&3
}

hw3(){
    cat <&3
}

# Log into 1Password CLI
function op_login {
    
    # Check if op is installed
    if ! (check_command op); then
        echo "The op cli is not installed. Aborting..."
        return 1
    fi

    # Check if op is logged in already
    if (op list items > /dev/null 2>&1); then
        echo "op is already logged in"
        return 0
    fi
    
    echo "Logging into op"
    # Check if op is logged in
    if ! (op list users > /dev/null 2>&1); then
    # if not, log in or die trying
        if ! eval "$(op signin my.1password.com dave.wallraff@gmail.com)"; then
            echo "op login failed. Aborting..."
            return 1
        fi
    fi
}


# Create a slug from a string
# https://gist.github.com/oneohthree/f528c7ae1e701ad990e6
function slugify {

    echo "$1" | iconv -t ascii//TRANSLIT | sed -E s/[^a-zA-Z0-9]+/-/g | sed -E s/^-+\|-+$//g | tr '[:upper:]' '[:lower:]'
}


# Create an encrypted tarball
function enc_tar {

    # Get some names and stuff
    BASE=$(basename "$1")
    TARBALL=$(slugify "$BASE")

    # Log in to op
    if ! op_login; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Dump op tar password from op into fd:3
    # https://unix.stackexchange.com/questions/29111/safe-way-to-pass-password-for-1-programs-in-bash#answer-29186
    echo "Getting op encrypted tarball password. This can take a hot minute....."
    if ! (exec 3<<<"$(op get item encrypted_tar_password --fields password)"); then
        echo "Unable to dump op encrypted tarball password to fd:3. Aborting..."
        return 1
    fi

    # Use that password to encrypt the tarball
    echo "Tar'ing up '$1'" 
    if ! (tar hcz "$1" | gpg --batch --cipher-algo AES256 --passphrase-fd 3 --symmetric --output "$TARBALL".tar.gz.enc > /dev/null); then
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
    if ! op_login; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Dump op tar password from op into fd:3
    # https://unix.stackexchange.com/questions/29111/safe-way-to-pass-password-for-1-programs-in-bash#answer-29186
    echo "Getting op encrypted tarball password. This can take a hot minute....."
    if ! (exec 3<<<"$(op get item encrypted_tar_password --fields password)"); then
        echo "Unable to dump op encrypted tarball password to fd:3. Aborting..."
        return 1
    fi


    # Use that password to decrypt the tarball
    cd "$SHORT" || die
    echo "Untar'ing '$1'" 
    if ! (gpg --no-verbose --quiet --batch --cipher-algo AES256 --passphrase-fd 3 --decrypt "$1" | tar xz); then
        echo "Decrypting an encrypted tarball failed. Aborting..."
        return 1
    fi

    cd .. || die
}


# Create an encrypted tarball and upload it to google drive
function gdrive_upload {

    # Check if rclone is installed
    if ! (check_command rclone); then
        echo "The rclone cli is not installed. Aborting..."
        return 1
    fi
    
    # Get some names and stuff
    BASE=$(basename "$1")
    SLUG=$(slugify "$BASE")
    TODAY=$(date "+%Y%m%d")
    TARBALL_NAME="$TODAY"_"$SLUG"
    
    # Log in to op
    if ! op_login; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # Dump op tar password from op into fd:3
    # https://unix.stackexchange.com/questions/29111/safe-way-to-pass-password-for-1-programs-in-bash#answer-29186
    echo "Getting op encrypted tarball password. This can take a hot minute....."
    if ! (exec 3<<<"$(op get item encrypted_tar_password | jq -r '.details.fields[] | select(.name=="password") | .value')"); then
        echo "Unable to dump op encrypted tarball password to fd:3. Aborting..."
        return 1
    fi

    # Use that password to encrypt the tarball
    echo "Tar'ing up '$1'" 
    if ! (tar hcz "$1" | gpg --batch --cipher-algo AES256 --passphrase-fd 3 --symmetric --output "$TARBALL_NAME".tar.gz.enc > /dev/null); then
        echo "Creating an encrypted tarball failed. Aborting..."
        return 1
    fi

    # Copy to gdrive
    echo "Copying to gdrive"
    if ! (rclone copy "$TARBALL_NAME".tar.gz.enc "gdrive:/archive/encrypted backups" > /dev/null 2>&1); then
        echo "Copying to rclone failed"
    fi

    # Clean up
    echo "Cleaning up"
    if ! (rm "$TARBALL_NAME".tar.gz.enc); then
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
    if ! op_login; then
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
    if ! op create document "$1" --title="$SLUG" --vault="Personal" --tags="uploaded_by_cli" > /dev/null; then
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
function github_sso_token {

    op_login
    TEMP=$(op get item github_sso_token  | jq -r '.details.fields[] | select(.name=="password") | .value')
    echo '#!/usr/bin/env bash' > ~/.github_sso_token
    echo "echo $TEMP" >> ~/.github_sso_token
    chmod +x ~/.github_sso_token
    export GIT_ASKPASS=~/.github_sso_token
    
}

# Backup 1password
function 1password_backup {

    # set some vars
    TODAY=$(date "+%Y%m%d")
    BACKUPDIR="$TODAY"_1password_backup

    # Check if op is installed
    if ! (check_command op); then
        echo "The op cli is not installed. Aborting..."
        return 1
    fi

    # Check if op is logged in
    if ! op_login; then
        echo "op login failed. Aborting..."
        return 1
    fi

    # make a local temp dir
    mkdir -p ~/"$BACKUPDIR"/files || return 1

    # get all item's UUIDs
    echo "Getting item list..."
    if ! (op list items | jq -r '.[].uuid' > "$BACKUPDIR"/items_list); then
        echo "Failed to list items. Aborting..."
        return 1
    fi

    # Loop over list and save off all the metadata
    COUNTER=0
    TOTAL=$(wc -l < "$BACKUPDIR"/items_list)
    while read -r i; do
        (( COUNTER++ ))
        echo "Getting item #$COUNTER of $TOTAL..."
        op get item "$i" >> "$BACKUPDIR"/"$BACKUPDIR".json; echo >> "$BACKUPDIR"/"$BACKUPDIR".json
    done < "$BACKUPDIR"/items_list

    # Get all current (non-trashed) doc UUIDs and titles
    # shellcheck disable=2016
    echo "Getting doc list..."
    if ! (op list documents | jq -r '. as $in | keys[] | select($in[.].trashed=="N") as $res | [$in[$res].uuid, $in[$res].overview.title] | @json' > "$BACKUPDIR"/files/docs_list); then
        echo "Failed to list docs. Aborting..."
        return 1
    fi


    # Loop over list and save each one off
    TOTAL="$(wc -l < "$BACKUPDIR"/files/docs_list)"
    for ((i=1; i<="$TOTAL"; i++))
    do
        FILENAME=""
        UUID=""
        (( COUNT=i-1 ))
        UUID=$(jq -rs '.['"$COUNT"'][0]' < "$BACKUPDIR"/files/docs_list)
        FILENAME=$(op get item "$UUID" | jq -r '.details.documentAttributes.fileName')
        if [ -z "$FILENAME" ]; then
            FILENAME=$(jq -rs '.['"$COUNT"'][1]' < "$BACKUPDIR"/files/docs_list)
        fi
        echo "Getting doc $i of $TOTAL: $FILENAME ($UUID)..."
        op get document "$UUID" > "$BACKUPDIR"/files/"$FILENAME"
    done

    echo "Tar'ing up $BACKUPDIR and sending to gdrive" 
    if ! (gdrive_upload "$BACKUPDIR"); then
        echo "Failed to gdrive_upload $BACKUPDIR. Aborting..."
        return 1
    fi

    # Clean up
    cd ~ || return 1
    echo "Cleaning up"
    if ! rm -r "$BACKUPDIR" "$BACKUPDIR".tar.gz.enc; then
        echo "Clean up failed"
    fi

}