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
      value = let
        act = shelltool.mkShell (import f pkgs);
      in builtins.deepSeq act act;
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
      shixbin = pkgs.writeShellScriptBin "shix" (builtins.readFile ./.shix.sh);
    in {
      config.environment.systemPackages = [ shixbin pkgs.git ];
    };
  });
}
