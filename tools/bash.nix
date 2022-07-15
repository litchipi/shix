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
  mkBashrc = {
    name,
    shellCommand ? null,
    scripts ? {},
    noautocompletion ? [],
    bashInitExtra ? "",
    ps1 ? null,
    packages ? [],
  ...}: let 
    all_scripts = builtins.concatStringsSep "\n\n" (
      pkgs.lib.attrsets.mapAttrsToList generate_script (scripts // (base_scripts name))
    );

    extra_path = if (builtins.length packages) > 0 then
      "export PATH=$PATH:" + (lib.strings.makeBinPath packages)
    else "";

    # TODO  Add custom auto-completion for specific scripts
    noautocomplet = builtins.concatStringsSep "\n" (builtins.map (p:
      "" # TODO FIXME   Remove totally auto-completion for some commands
      #"complete -r ${p}"
    ) noautocompletion);

  in pkgs.writeTextFile {
    name = "custom_${name}_bashrc";
    text = ''
    '' + all_scripts + "\n" + (if builtins.isNull ps1 then "" else ''
      ${noautocomplet}

      ${extra_path}
      ${ps1tool.import_git_ps1}
      export PS1="${ps1}"
      cd $HOME
    '') + "\n" + bashInitExtra;
  };

  generate_script = name: text: ''
    # Auto generated ${name} script
    function ${name}() {
      ${text}
    }
  '';
}
