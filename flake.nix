{
  description = "Nix-powered tailored shells sandboxed using bubblewrap";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import inputs.nixpkgs {
      inherit system;
    };
    pkgs_unstable = import inputs.nixpkgs-unstable {
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

    tools_args = {
      inherit pkgs pkgs_unstable;
      nixos_version = "23.05";
      nixpkgs_rev = "c7a18f89ef1dc423f57f3de9bd5d9355550a5d15"; # For runtime package add
      lib = pkgs.lib;
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

    all_shells = find_all_files ./shells;

    shelltool = import ./tools/generate_shell.nix tools_args;
    bashtool = import ./tools/bash.nix tools_args;
    tmuxtool = import ./tools/tmux.nix tools_args;
    victool = import ./tools/vic.nix tools_args;
    shellArgs = {
      inherit pkgs pkgs_unstable lib system inputs bashtool tmuxtool;
      colorstool = import ./tools/colors.nix tools_args;
      ps1tool = import ./tools/ps1.nix tools_args;
    };

    mkShell = file: let
      data = import file shellArgs;
      tmux_data = tmuxtool.build data;
      bash_data = bashtool.build tmux_data data;
      start_script = shelltool.mkShell bash_data tmux_data data;
      vic_cfg = victool.mkConfig data;
      vic_config_file = pkgs.writeText "vic-${data.name}-config.json" (builtins.toJSON vic_cfg);
      is_release = true;
    in pkgs.writeShellScript "${data.name}-shell" ''
      cd ./vic
      CONTAINER_UID=$(id -u)
      CONTAINER_GID=$(id -g)
      export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:${pkgs.libseccomp.dev}/lib/pkgconfig"
      cargo build ${lib.strings.optionalString is_release "--release"}
      echo "config file: ${vic_config_file}"

      sudo -E ./target/${if is_release then "release" else "debug"}/vic \
        --debug \
        --config-file ${vic_config_file} \
        --script ${start_script} \
        --uid "$CONTAINER_UID" \
        --gid "$CONTAINER_GID"
    '';

    shixbin = import ./shix_script.nix { inherit pkgs lib; };

    vic_script = import ./vic/script.nix { inherit pkgs lib; };
  in {
    packages.default = shixbin {
      remoteRepoUrl = "REMOTE_REPO_URL";
      pushAfterEditing = true;
      pullBeforeEditing = true;
      baseDir = "$HOME/BASE_DIR";
      shellEditCommand = "SHELL_EDIT";
    };
    apps = (builtins.listToAttrs (builtins.map (f: {
      name = name_from_fname f;
      value = { type = "app"; program = "${mkShell f}"; };
    }) all_shells)) // {
      vic = { type = "app"; program = "${vic_script}"; };
    };

    overlays.default = self: super: {
      lib = super.lib // {
        shix = { inherit mkShell; };
      };
    };

    nixosModules.default = { lib, config, ...}: {
      options.shix = {
        remoteRepoUrl = lib.mkOption {
          type = lib.types.str;
          description = "Remote repository where the shells are stored";
          default = "git@github.com:litchipi/shix.git";
        };

        pushAfterEditing = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Push to remote repository after each shell edition";
        };

        pullBeforeEditing = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Pull from remote repository before each shell edition";
        };

        baseDir = lib.mkOption {
          type = lib.types.str;
          description = "Base dir where to store shells";
          default = "$HOME/.local/share/shix";
        };

        shellEditCommand = lib.mkOption {
          type = lib.types.str;
          default = "$EDITOR";
          description = "Command to use to open and edit a shell";
        };
      };
      config.environment.systemPackages = [ (shixbin config.shix) ];
    };

    devShells.default = pkgs.mkShell {
      PKG_CONFIG_PATH="${pkgs.libseccomp.dev}/lib/pkgconfig";
    };
  });
}
