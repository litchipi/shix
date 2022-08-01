#!/bin/sh

# Installs the `shix` script

mkdir -p ~/.local/bin/
echo "#!/bin/bash" > ~/.local/bin/shix
cat ./.shix.sh >> ~/.local/bin/shix
