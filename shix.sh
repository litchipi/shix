set -e

SHIX_SRC="https://github.com/litchipi/shix"
RAW_SHIX_SRC="https://raw.githubusercontent.com/litchipi/shix/main/shix.sh"
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
            "n"|"N"|"no")
                echo "Setting up a blank repository"
                git clone "$SHIX_SRC" $SHIXDIR
                pushd $SHIXDIR
                git checkout -f --track origin/main || git reset --hard origin/main
                ;;
            *)
                read -p "Enter the URL: " remote
                git clone "$remote" $SHIXDIR
                pushd $SHIXDIR
                git checkout -f --track origin/main || git reset --hard origin/main
                add_shixremote "$remote"
                ;;
        esac
        if ! git remote|grep "$GITSHIXREMOTENAME" 1>/dev/null 2>/dev/null; then
            echo "Do you wish to save your shix shells in a remote repository ? [Y/n]"
            read answer
            case $answer in
                "y"|"Y"|"yes")
                    ;;
                *)
                    add_shixremote
                    ;;
            esac
        fi
        popd
    fi
}

check_not_in_shell() {
    if [ ! -z ${SHIX_SHELL+x} ]; then
        echo 'Already in a shix shell, cannot nest them'
        exit 1;
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
        git pull "$GITSHIXREMOTENAME" $NAME 2>/dev/null || echo "Remote ref not found"
    fi
}

shixedit() {
    if [ $# -ne 1 ]; then
        echo "Usage: shix edit <name>"
        exit 1;
    fi
    NAME="$1"
    
    if [[ "$FORBIDDEN_NAMES" == *"$NAME"* ]]; then
        echo "This name cannot be set, please choose another one"
        exit 1;
    fi

    pushd $SHIXDIR
    load_remoteshix
    git checkout -B $NAME

    FNAME=$SHIXDIR/shells/$NAME.nix
    if [ ! -f $FNAME ]; then
        read -p "Do you wish to create a new shix \"$NAME\" ? [y/N] " -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p $(dirname $FNAME)
            cp $SHIXDIR/shells/example.nix $FNAME
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

shixcompose() {
    echo "$@"
    if [ $# -ne 2 ]; then
        echo "Usage: shix compose <config file> <other config url>"
        exit 1;
    fi

    export SHIXCOMP_A=$(realpath $1)
    export SHIXCOMP_B=$(realpath $2)
    nix run $SHIXDIR#compose --impure
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

    pushd $SHIXDIR

    if [[ "$1" != "example" ]]; then
        if ! git branch | grep $1 1>/dev/null 2>/dev/null; then
            echo "Shell $1 doesn't exist"
            echo "Use \"shix edit $1\" to create it"
            exit 1;
        fi

        git checkout $1
    fi

    if [ ! -f $SHIXDIR/shells/$1.nix ]; then
        echo "Shell $1 doesn't exist"
        echo "Use \"shix edit $1\" to create it"
        exit 1;
    fi

    nix run .#$1
    popd
}

install_shix() {
    echo -n "#!" > ~/.local/bin/shix
    which bash >> ~/.local/bin/shix
    echo "" >> ~/.local/bin/shix
    wget $RAW_SHIX_SRC -q -O - >> ~/.local/bin/shix
    chmod +x ~/.local/bin/shix
}

if [ $# -eq 0 ]; then
    echo "Please provide arguments, examples:"
    echo -e "\tshix init: Setup the directory if needed"
    echo -e "\tshix <name>: Starts the shell <name>"
    echo -e "\tshix edit <name>: Edit the shell <name>"
    echo -e "\tshix remote <url> <name>: Start the shell <name> located in the remote git at <url>"
    echo -e "\tshix compose <config> <path/url>: Merges the local config <config> with the remote one from <url> and starts the resulting shell"
    exit 1;
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
    "compose")
        shift 1;
        check_deps
        check_not_in_shell
        shixcompose $@
        ;;
    "init")
        shift 1;
        check_deps
        check_init
        ;;
    "install")
        shift 1;
        check_deps
        if ! install_shix; then
            echo "Installation failed"
        else
            echo "Installation succeeded"
        fi
        ;;
    *)
        check_deps
        check_not_in_shell
        check_init
        shixstart $@
        ;;
esac
