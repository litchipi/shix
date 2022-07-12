{
  description = "Collection of usefull nix shells";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/22.05";
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import inputs.nixpkgs {
      inherit system;
    };
    lib = pkgs.lib;

    # Gets the base name of a file without the extension, from a path
    name_from_fname = fname :
      pkgs.lib.removeSuffix ".nix"
        (pkgs.lib.lists.last
          (pkgs.lib.strings.splitString "/"
            (builtins.toString fname)
        )
        );

    shelltool = import ./tools/generate_shell.nix pkgs;

    genShell = f: {
      name = name_from_fname f;
      value = shelltool.mkShell (import f pkgs);
    };

    find_all_files = dir: lib.lists.flatten (
      (builtins.map find_all_files (list_elements dir "directory"))
      ++ (list_elements dir "regular")
    );

    list_elements = dir: type: map (f: dir + "/${f}") (
      lib.attrNames (
        lib.filterAttrs
          (_: entryType: entryType == type)
          (builtins.readDir  dir)
        )
      );
  in {
    apps = builtins.listToAttrs (builtins.map genShell (find_all_files ./shells));
    nixosModules.default = let 
      shixsrc = ./.;
      shixbin = pkgs.writeShellScriptBin "shix" ''
        set -e

        if [ ! -z ''${SHIX_SHELL+x} ]; then
            echo 'Already in a shix shell, cannot nest them'
            return
        fi
        export SHIX_SHELL=1
        
        if [ ! -d $HOME/.shix/.git ]; then
          git clone ${shixsrc} $HOME/.shix
        fi
        
        nix run $HOME/.shix#$1
      '';

      shixeditbin = pkgs.writeShellScriptBin "shixedit" ''
        set -e

        if [ -z "$EDITOR" ]; then
            EDITOR="vim"
        fi
  
        if [ ! -d $HOME/.shix/.git ]; then
          git clone ${shixsrc} $HOME/.shix
        fi

        NAME="$1"
        if [ ! -z ''${SHIX_SHELL+x} ]; then
            echo 'You are in a shix shell, cannot edit a shell inside it'
            exit 1;
        fi

        if [ -z "$NAME" ]; then
            echo "Usage:"
            echo "\tshixedit <name>"
            exit 1;
        fi

        pushd $HOME/.shix/
        FNAME=$HOME/.shix/shells/$NAME.nix
        if [ ! -f $FNAME ]; then
            cp $HOME/.shix/shells/example.nix $FNAME
            sed -i "s/ShixExample/$NAME/g" $FNAME
        fi

        $EDITOR $FNAME
        git add .
        git commit -m "Edited $NAME shell"
        popd
      '';
    in {
      config.environment.systemPackages = [
        shixbin shixeditbin
      ];
    };
  });
}
