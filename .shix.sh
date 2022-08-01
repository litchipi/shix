set -e

SHIX_SRC="https://github.com/litchipi/shix"
SHIXDIR="$HOME/.shix"
FORBIDDEN_NAMES="edit remote"
GITSHIXREMOTENAME="shixremote"

check_deps() {
    if ! nix --version 1>/dev/null 2>/dev/null; then
        echo "Nix is not installed on your system"
        echo "Please install flake-enabled nix"
        exit 1;
    fi

    if ! git --version 1>/dev/null 2>/dev/null; then
        echo "Git is not installed on your system"
        exit 1;
    fi
}

add_shixremote() {
    if [ $# -eq 1 ]; then
        remote=$1
    else
        read -p "Enter the URL to push changes to: " remote
    fi
    git remote add "$GITSHIXREMOTENAME" "$remote"
    git fetch "$GITSHIXREMOTENAME"
}

check_init() {
    if [ ! -d $SHIXDIR/.git ]; then
        echo "Shix is not initialized on your system, setting it up ..."
        read -p "Do you wish to import an existing remote repository ? [Y/n]" answer
        case $answer in
            "y"|"Y"|"yes")
                read -p "Enter the URL: " remote
                git clone "$remote" $SHIXDIR
                pushd $SHIXDIR
                add_shixremote "$remote"
                popd
                ;;
            *)
                echo "Setting up a blank repository"
                git clone "$SHIX_SRC" $SHIXDIR
                ;;
        esac
    fi

    pushd $SHIXDIR

    if ! git remote|grep "$GITSHIXREMOTENAME" 1>/dev/null 2>/dev/null; then
        echo "Do you wish to save your shix shells in a remote repository ? [Y/n]"
        read answer
        case $answer in
            "y"|"Y"|"yes")
                add_shixremote
                ;;
            *)
                ;;
        esac
    fi

    popd
}

check_not_in_shell() {
    if [ ! -z ${SHIX_SHELL+x} ]; then
        echo 'Already in a shix shell, cannot nest them'
        return
    fi

    export SHIX_SHELL=1
}

save_remoteshix() {
    if git remote|grep "$GITSHIXREMOTENAME" 1>/dev/null 2>/dev/null; then
        git push "$GITSHIXREMOTENAME" $NAME
    fi
}

load_remoteshix() {
    if git remote|grep "$GITSHIXREMOTENAME" 1>/dev/null 2>/dev/null; then
        git pull "$GITSHIXREMOTENAME" $NAME
    fi
}

shixedit() {
    if [ $# -ne 1 ]; then
        echo "Usage: shix edit <name>"
        exit 1;
    fi
    NAME="$1"
    
    pushd $SHIXDIR
    load_remoteshix
    git checkout $NAME

    FNAME=$SHIXDIR/shells/$NAME.nix
    if [ ! -f $FNAME ]; then
        read -p "Do you wish to create a new shix \"$NAME\" ? [y/N] " -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp $SHIXDIR/.example.nix $FNAME
            sed -i "s/ShixExample/$NAME/g" $FNAME
        else
            exit 0;
        fi
    fi

    $EDITOR $FNAME
    git add .
    git commit -m "Edited $NAME shell"
    save_remoteshix
    popd
}

shixremote() {
    if [ $# -ne 2 ]; then
        echo "Usage: shix remote <url> <name>"
        exit 1;
    fi

    nix run $1#$2
}

shixstart() {
    if [ $# -ne 1 ]; then
        echo "Usage: shix <name>"
        exit 1;
    fi

    if [ ! -f $SHIXDIR/shells/$1 ]; then
        echo "Shell $1 doesn't exist"
        echo "Use \"shix edit $1\" to create it"
        exit 1;
    fi

    nix run $SHIXDIR#$1
}

if [ $# -eq 0 ]; then
    echo "Please provide arguments, examples:"
    echo -e "\tshix <name>: Starts the shell <name>"
    echo -e "\tshix edit <name>: Edit the shell <name>"
    echo -e "\tshix remote <url> <name>: Start the shell <name> located in the remote git at <url>"
fi

case $1 in
    "edit")
        shift 1;
        check_deps
        check_not_in_shell
        check_init
        shixedit $@
        ;;
    "remote")
        shift 1;
        check_deps
        check_not_in_shell
        shixremote $@
        ;;
    *)
        check_deps
        check_not_in_shell
        check_init
        shixstart $@
        ;;
esac