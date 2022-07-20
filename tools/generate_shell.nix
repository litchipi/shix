pkgs: let
  bashtool = import ../tools/bash.nix pkgs;
  lib = pkgs.lib;
in {
  mkShell = {
    name,
    shellbin ? "${pkgs.bashInteractive}/bin/bash",
    initScript ? "",
    exitScript ? "",
    spawnTmux ? false,
    shellCommand ? shellbin,
    symLinks ? {},
    homeLinks ? [ ".config" ".cache" ],
    new_home ? "/tmp/${name}_home",
    clean_before ? false,
    data_dir ? null,
    tmux_config ? null,
  ...}@cfg:
  let
    shell_exec = if spawnTmux
      then tmuxtool.generate_command name tmux_config
      else shellCommand;

    custom_bashrc = bashtool.mkBashrc cfg;
    links_all = { direct = {}; dirs_inside = {}; } // symLinks;

    links_direct = builtins.concatStringsSep "\n\n" (lib.attrsets.mapAttrsToList (path: src:
    ''
      # Creating link "${path}"
      rm -f ${new_home}/${path}
      mkdir -p $(dirname ${new_home}/${path})
      ln -s ${src} ${new_home}/${path}
    ''
    ) links_all.direct);

    links_dirs_inside = builtins.concatStringsSep "\n\n" (lib.attrsets.mapAttrsToList (path: src:
    ''
      # Generating a link for each directory inside "${src}"
      for d in $(ls -d ${src}/*); do
        NAME=$(basename $d)
        mkdir -p ${new_home}/${path}
        rm -f ${new_home}/${path}/$NAME
        ln -s $d ${new_home}/${path}/$NAME
      done
    ''
    ) links_all.dirs_inside);

    shell = pkgs.writeScript "${name}_shell_activate.sh" (''
      set -e
    ''

    # If want a clean workspace before starting, remove everything
    + (if clean_before then ''
      rm -rf ${new_home}
    '' else "")
    + ''
      mkdir -p ${new_home}
      rm -f ${new_home}/data ${new_home}/${builtins.concatStringsSep " ${new_home}/" homeLinks}
    ''

    # Link data_dir in the home directory
    + (if (builtins.isNull data_dir) then "" else ''
      mkdir -p ${data_dir}
      ln -s ${data_dir} ${new_home}/data
    '')

    # Link dotfiles inside home directory
    + (builtins.concatStringsSep "\n" (builtins.map (path:
      "ln -s $HOME/${path} ${new_home}/${path}"
    ) homeLinks)) + ''

      ${links_direct}
      ${links_dirs_inside}

      # Remove annoying messages from Ubuntu
      touch ${new_home}/.sudo_as_admin_successful

      cat $HOME/.bashrc ${custom_bashrc} > ${new_home}/.profile

      export SHELL="${shellbin}"
      export OLDHOME="$HOME"
      export HOME="${new_home}"

      # Remove any external source if they cannot be reached from inside the HOME
      for src in $(grep -E "^\s?+source" $HOME/.profile | awk -F ' ' '{print $2}'); do
        if [ "$src" = "~/.profile" ]; then
          sed -i "s+source $src+: # source $src+g" $HOME/.profile
        # xargs is here to expand any "~" or "$HOME" that could cause trouble
        elif [ ! -f $(echo "$src" | xargs -i sh -c 'echo {}') ]; then
          sed -i "s+source $src+: # source $src+g" $HOME/.profile
        fi
      done

      # Same with the "." bash operator
      DOTTED=$(grep -E "^\s?+\." $HOME/.profile | awk -F ' ' '{print $2}')
      for src in $DOTTED; do
        if [ "$src" = "~/.profile" ]; then
          sed -i "s+\. $src+: # \. $src+g" $HOME/.profile
        elif [ ! -f $(echo "$src" | xargs -i sh -c 'echo {}') ]; then
          sed -i "s+\. $src+: # \. $src+g" $HOME/.profile
        fi
      done

      ${initScript}

    '' + (if spawnTmux then ''
      function quit() {
        ${tmuxtool.quit_command name}
      }

    '' else "") + shell_exec + ''

      ${exitScript}
      exit 0;
    '');
  in {
    type = "app";
    program = pkgs.lib.debug.traceValSeq "${shell}";
  };
}
