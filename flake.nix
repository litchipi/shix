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
    mkApp = exec: args: let
    in {
      type = "app";
      program = if args == [] then "${exec}" else let
        exec_with_args = pkgs.writeShellScript "mkAppWithArgs" ''
          ${exec} ${builtins.concatStringsSep " " args} $@
        '';
      in "${exec_with_args}";
    };

    # Gets the base name of a file without the extension, from a path
    name_from_fname = fname :
      pkgs.lib.removeSuffix ".nix"
        (pkgs.lib.lists.last
          (pkgs.lib.strings.splitString "/"
            (builtins.toString fname)
        )
      );

    shelltool = import ./tools/generate_shell.nix pkgs;
    shellArgs = {
      inherit pkgs;
      colorstool = import ./tools/colors.nix pkgs;
      tmuxtool = import ./tools/tmux.nix pkgs;
      ps1tool = import ./tools/ps1.nix pkgs;
    };

    mapShellScript = mapfct: override: f: mapfct (shelltool.mkShell
      (lib.attrsets.recursiveUpdate (import f shellArgs) override)
    );
    genShellApp = mapShellScript (shell: mkApp "${shell}" []);
    genShellNV = f: {
      name = name_from_fname f;
      value = genShellApp {} f;
    };

    find_all_files = dir: lib.lists.flatten (
      (builtins.map find_all_files (list_elements dir "directory"))
      ++ (list_elements dir "regular")
    );

    list_elements = dir: type: builtins.map (f: dir + "/${f}") (
      lib.attrNames (
        lib.filterAttrs
          (_: entryType: entryType == type)
          (builtins.readDir  dir)
        )
      );
    
    shixbin = pkgs.writeShellScriptBin "shix" (builtins.readFile ./shix.sh);
  in {
    apps = builtins.listToAttrs (builtins.map genShellNV (find_all_files ./shells)) // {
      shix = mkApp "${shixbin}/bin/shix" [];

      compose = let
        try_load = env: if (builtins.getEnv env) != ""
          then builtins.getEnv env
          else builtins.throw "Envionment variable ${env} must be set for a composition";
        cfgA = import (try_load "SHIXCOMP_A") shellArgs;
        cfgB = import (try_load "SHIXCOMP_B") shellArgs;
        shell = shelltool.mkShell (lib.recursiveUpdate cfgA cfgB);
      in mkApp "${shell}" [];
    };

    overlays.default = self: super: {
      lib = super.lib // {
        shix = {
          mkShix = genShellApp;
          mkShixMerge = mkApp "${shixbin}/bin/shix" [ "compose" ];
          mkShixCompose = base: mkApp "${shixbin}/bin/shix" ["compose" "${builtins.toPath base}"];
        };
      };
    };

    nixosModules.default = {
      config.environment.systemPackages = [ shixbin pkgs.git ];
    };
  });
}
