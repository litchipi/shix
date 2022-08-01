pkgs: let
  bashtool = import ../tools/bash.nix pkgs;
  tmuxtool = import ../tools/tmux.nix pkgs;
  colorstool = import ../tools/colors.nix pkgs;
  lib = pkgs.lib;

  default_dirs_config = name: {
    symLinks = {};
    homeLinks = [ ".config" ".cache" ];
    paths = {
      home = "/tmp/${name}_home";
      data = null;
    };
    clean_before = false;
  };

in {
  mkShell = {
    name,
    packages ? [],
    shellCommand ? null,
    initScript ? "", exitScript ? "",

    shell ? {}, tmux ? {}, dirs ? {},
    colors ? colorstool.default_colors,
  ...}@cfg_raw:
  let
    checklist = {
      name_is_safe_string = (lib.strings.escapeShellArg name) == ("'" + name + "'");
      name_without_whitespace = ! lib.strings.hasInfix " " name;
    };

    configcheck = builtins.foldl' (state: check: {
      ok = state.ok && check.value;
      list = state.list ++ (if check.value
        then []
        else [check.name]
      );
    }) { ok = true; list = []; }
    (lib.attrsets.mapAttrsToList (name: value: {inherit name value; }) (builtins.deepSeq checklist checklist));

    shellconf = lib.attrsets.recursiveUpdate bashtool.default_shell_config shell;
    tmuxconf = lib.attrsets.recursiveUpdate tmuxtool.default_tmux_config tmux;
    dirsconf = lib.attrsets.recursiveUpdate (default_dirs_config name) dirs;
    cfg = (cfg_raw // { shell = shellconf; tmux = tmuxconf; dirs = dirsconf; });
    shellCommand = if (builtins.isNull shellCommand) then shell.bin else shellCommand;

    shell_exec = if tmux.enable
      then let
        tmux_config_gen = tmuxtool.generate_config cfg;
      in tmuxtool.generate_command { inherit name; tmux_config = tmux_config_gen; exec = shellCommand; }
      else shellCommand;

    custom_bashrc = bashtool.mkBashrc cfg;
    links_all = { direct = {}; dirs_inside = {}; } // dirsconf.symLinks;

    links_direct = builtins.concatStringsSep "\n" (lib.attrsets.mapAttrsToList (path: src:
    ''

      # Creating link "${path}"
      rm -f ${dirsconf.paths.home}/${path}
      mkdir -p $(dirname ${dirsconf.paths.home}/${path})
      ln -s ${src} ${dirsconf.paths.home}/${path}

    ''
    ) links_all.direct);

    links_dirs_inside = builtins.concatStringsSep "\n\n" (lib.attrsets.mapAttrsToList (path: src:
    ''
      # Generating a link for each directory inside "${src}"
      for d in $(ls -d ${src}/*); do
        NAME=$(basename $d)
        mkdir -p ${dirsconf.paths.home}/${path}
        rm -f ${dirsconf.paths.home}/${path}/$NAME
        ln -s $d ${dirsconf.paths.home}/${path}/$NAME
      done
    ''
    ) links_all.dirs_inside);

    shell_activate = with dirsconf; pkgs.writeScript "${name}_shell_activate.sh" (''
      set -e
    ''

    # If want a clean workspace before starting, remove everything
    + (if clean_before then ''
      rm -rf ${paths.home}
    '' else "")
    + ''
      mkdir -p ${paths.home}
      rm -f ${paths.home}/data ${paths.home}/${builtins.concatStringsSep " ${paths.home}/" homeLinks}
    ''

    # Link paths.data in the home directory
    + (if (builtins.isNull paths.data) then "" else ''
      mkdir -p ${paths.data}
      ln -s ${paths.data} ${paths.home}/data
    '')

    # Link dotfiles inside home directory
    + (builtins.concatStringsSep "\n" (builtins.map (path:
      "ln -s $HOME/${path} ${paths.home}/${path}"
    ) homeLinks)) + ''

      ${links_direct}
      ${links_dirs_inside}

      # Remove annoying messages from Ubuntu
      touch ${paths.home}/.sudo_as_admin_successful

      cp $HOME/.bashrc ${paths.home}/.bashrc
      cat ${custom_bashrc} >> ${paths.home}/.bashrc

      export SHELL="${shellconf.bin}"
      export OLDHOME="$HOME"
      export HOME="${paths.home}"

      # Remove any external source if they cannot be reached from inside the HOME
      for src in $(grep -E "^\s?+source" $HOME/.bashrc | awk -F ' ' '{print $2}'); do
        if [ "$src" = "~/.profile" ]; then
          sed -i "s+source $src+: # source $src+g" $HOME/.bashrc
        # xargs is here to expand any "~" or "$HOME" that could cause trouble
        elif [ ! -f $(echo "$src" | xargs -i sh -c 'echo {}') ]; then
          sed -i "s+source $src+: # source $src+g" $HOME/.bashrc
        fi
      done

      # Same with the "." bash operator
      DOTTED=$(grep -E "^\s?+\." $HOME/.bashrc | awk -F ' ' '{print $2}')
      for src in $DOTTED; do
        if [ "$src" = "~/.profile" ]; then
          sed -i "s+\. $src+: # \. $src+g" $HOME/.bashrc
        elif [ ! -f $(echo "$src" | xargs -i sh -c 'echo {}') ]; then
          sed -i "s+\. $src+: # \. $src+g" $HOME/.bashrc
        fi
      done

      ${initScript}

    '' + (if tmux.enable then ''
      echo "source ~/.bashrc" > ~/.profile
      quit() {
        ${tmuxtool.quit_command name}
      }

    '' else "") + shell_exec + ''

      ${exitScript}
      exit 0;
    '');
  in {
    type = if (builtins.deepSeq configcheck configcheck.ok)
      then "app"
      else builtins.throw "Failed checks: ${builtins.concatStringsSep ", " configcheck.list}";
    program = pkgs.lib.debug.traceValSeq "${shell_activate}";
  };
}
