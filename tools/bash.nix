pkgs: let
  lib = pkgs.lib;

  ps1tool = import ./ps1.nix pkgs;

  base_scripts = name: let
    name_sanitized = builtins.replaceStrings [" " "/" ] ["_" "_"] name;
    fname = "/tmp/${name_sanitized}_shell_addpkgs";
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

        nix build nixpkgs/22.05#$package
        package_path=$(readlink ./result)
        rm ./result
        echo "export PATH=\$PATH:$package_path/bin" >> ~/.profile
        export PATH="$PATH:$package_path/bin"
      fi
    '';
  };

in rec {
  default_shell_config = {
    bin = "${pkgs.bashInteractive}/bin/bash";
    config_file = "$HOME/.bashrc";
    ps1 = null;
    scripts = {};
    bashInitExtra = "";
    packages = [];
  };

  mkBashrc = { name, packages, shell, extra, ...}: with shell; let
    all_scripts = builtins.concatStringsSep "\n\n" (
      pkgs.lib.attrsets.mapAttrsToList generate_script (scripts // (base_scripts name))
    );

    add_path = if (builtins.length packages) > 0 then
      "export PATH=$PATH:" + (lib.strings.makeBinPath packages)
    else "";

  in pkgs.writeTextFile {
    name = "custom_${name}_bashrc";
    text = ''
    '' + all_scripts + "\n" + (if builtins.isNull ps1 then "" else ''
      ${ps1tool.import_git_ps1}
      export PS1="${ps1}"
    '') + ''
      ${add_path}
      cd $HOME

      ${bashInitExtra}
      ${extra.bashrc}
    '';
  };

  generate_script = name: text: ''
    # Auto generated ${name} script
    function ${name}() {
      ${text}
    }
  '';
}
