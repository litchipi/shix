#!/bin/sh

# Installs the `shix` function in the bashrc

if ! nix --version 1>/dev/null 2>/dev/null; then
    echo "Nix is not installed on your system"
    echo "Please install flake-enabled nix"
    exit 1;
fi

if [ -z "$EDITOR" ]; then
    EDITOR="vim"
fi

if [ ! -d $HOME/.shix/.git ]; then
    git clone $PWD $HOME/.shix
fi

echo "Modify shells of the system in $HOME/.shix repository"

if ! grep "shix()" ~/.bashrc 2>/dev/null 1>/dev/null; then
    echo "function shix() {(
        set -e
        if [ ! -z \${SHIX_SHELL+x} ]; then
            echo 'Already in a shix shell, cannot nest them'
            return
        fi
        export SHIX_SHELL=1
        nix run \$HOME/.shix#\$1
    )}
    " >> ~/.bashrc
fi

if ! grep "shixedit()" ~/.bashrc 2>/dev/null 1>/dev/null; then
    echo "function shixedit() {(
        set -e

        NAME=\"\$1\"
        if [ ! -z \${SHIX_SHELL+x} ]; then
            echo 'You are in a shix shell, cannot edit a shell inside it'
            return
        fi

        if [ -z \"\$NAME\" ]; then
            echo 'Usage:'
            echo '\tshixedit <name>'
            return
        fi

        pushd \$HOME/.shix/
        FNAME=\$HOME/.shix/shells/\$NAME.nix
        if [ ! -f \$FNAME ]; then
            cp \$HOME/.shix/shells/example.nix \$FNAME
            sed -i \"s/ShixExample/\$NAME/g\" \$FNAME
        fi

        $EDITOR \$FNAME
        git add .
        git commit -m \"Edited \$NAME shell\"
        popd
    )}
    " >> ~/.bashrc
fi

. $HOME/.bashrc

echo "Usage:"
echo "\tshix <name>:      Spawns the shell <name>"
echo "\tshixedit <name>:  Edit the shell <name> in $EDITOR, creates if it doesn't exist"
