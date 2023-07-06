{ nixpkgs_rev, pkgs, lib, ...}@args: let
  ps1tool = import ./ps1.nix args;
  base_scripts = name: let
    fname = "$HOME/.added_packages";
  in {
    add_pkgs = ''
      if [ $# -ne 1 ]; then
        echo "add_pkgs: <package name>"
      else
        package=$1

        touch ${fname}
        if ! cat ${fname} | grep "$package" 1>/dev/null 2>/dev/null; then
          echo "$package" >> ${fname}
        fi

        mkdir -p $HOME/.local/bin
        nix build nixpkgs/${nixpkgs_rev}#$package && cp $(readlink ./result)/bin/* $HOME/.local/bin && rm ./result
      fi
    '';
  };
  
  default_shell_config = {
    bin = "${pkgs.bashInteractive}/bin/bash";
    bashInitExtra = "";
    scripts = {};
    pkgconfig_libs = [];
    ps1 = "\\u \\w $";
  };

in rec {
  build = add_bashrc: {
    name,
    shell ? {},
  ... }@cfg: let
    shell_config = lib.attrsets.recursiveUpdate default_shell_config shell;
  in {
    bashrc = mkBashrc add_bashrc cfg shell_config;
    shell_bin = shell_config.bin;
    ps1 = shell_config.ps1;
  };

  mkBashrc = add_bashrc: {
    name,
    packages ? [],
  ...}: cfg: let
    all_scripts = builtins.concatStringsSep "\n\n" (
      pkgs.lib.attrsets.mapAttrsToList generate_script (cfg.scripts // (base_scripts name))
    );

    add_path = "export PATH=" + (lib.strings.makeBinPath (packages ++
      (if (builtins.length cfg.pkgconfig_libs) > 0 then [pkgs.pkg-config] else [])
    )) + ":$HOME/.local/bin:$PATH";

    add_pkgconfig_libs = if (builtins.length cfg.pkgconfig_libs) > 0 then
      "export PKG_CONFIG_PATH=" + (builtins.concatStringsSep ":" (builtins.map (l:
        "${l.dev}/lib/pkgconfig"
      ) cfg.pkgconfig_libs)) + ":$PKG_CONFIG_PATH"
    else "";

  in pkgs.writeTextFile {
    name = "custom_${name}_bashrc";
    text = ''
      if [ -n "$__SANDBOXED_ETC_BASHRC_SOURCED" ]; then return; fi
      __SANDBOXED_ETC_BASHRC_SOURCED=1
      source /host/etc/profile
      source /host/etc/bashrc
    '' + all_scripts + "\n" + (if builtins.isNull cfg.ps1 then "" else ''
      ${ps1tool.import_git_ps1}
      export PS1="${cfg.ps1}"
    '') + ''

      ${add_path}
      ${add_pkgconfig_libs}
      cd $HOME

      ${add_bashrc}

      ${cfg.bashInitExtra}
    '';
  };

  generate_script = name: text: ''
    # Auto generated ${name} script
    function ${name}() {
      ${text}
    }
  '';
}
