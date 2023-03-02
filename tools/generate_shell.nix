{pkgs, ...}@args: let
  bashtool = import ../tools/bash.nix args;
  tmuxtool = import ../tools/tmux.nix args;
  colorstool = import ../tools/colors.nix args;
  lib = pkgs.lib;

  default_dirs_config = name: {
    symLinks = {};
    homeLinks = [ ".config" ".cache" ".local/share/nvim/site/autoload" ".gitconfig" ".git-credentials"];
    paths = {
      home = "/tmp/${name}_home";
      data = null;
    };
    clean_before = false;
  };

  default_extra_config = {
    bashrc = "";
    init_script = "";
    exit_script = "";
  };

in {
  mkShell = {
    name,
    packages ? [],
    libraries ? {},
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

    complete_conf = {
      shell = lib.attrsets.recursiveUpdate bashtool.default_shell_config shell;
      tmux = lib.attrsets.recursiveUpdate tmuxtool.default_tmux_config tmux;
      dirs = lib.attrsets.recursiveUpdate (default_dirs_config name) dirs;
      colors = lib.attrsets.recursiveUpdate (colorstool.default_colors) colors;
    };

    cfg = lib.attrsets.recursiveUpdate cfg_raw {
      inherit (complete_conf) shell tmux dirs;
      inherit colors;
      extra = lib.attrsets.recursiveUpdate default_extra_config (
        if cfg.tmux.enable then tmuxtool.extra cfg
        else {}
      );
    };

    shell_cmd = if (builtins.isNull shellCommand) then cfg.shell.bin else shellCommand;
    shell_exec = if cfg.tmux.enable
      then let
        tmux_config_gen = tmuxtool.generate_config cfg;
      in tmuxtool.generate_command {
        inherit name;
        tmux_config = tmux_config_gen;
        tmuxp_session = cfg.tmux.tmuxp_session;
        exec = shell_cmd;
      }
      else shell_cmd;

    custom_bashrc = bashtool.mkBashrc cfg;
    links_all = lib.attrsets.recursiveUpdate { direct = {}; dirs_inside = {}; } cfg.dirs.symLinks;

    links_direct = builtins.concatStringsSep "\n" (lib.attrsets.mapAttrsToList (path: src:
    ''

      # Creating link "${path}"
      rm -f ${cfg.dirs.paths.home}/${path}
      mkdir -p $(dirname ${cfg.dirs.paths.home}/${path})
      ln -s ${src} ${cfg.dirs.paths.home}/${path}

    ''
    ) links_all.direct);

    links_dirs_inside = builtins.concatStringsSep "\n\n" (lib.attrsets.mapAttrsToList (path: src:
    ''
      # Generating a link for each directory inside "${src}"
      for d in $(ls -d ${src}/*); do
        NAME=$(basename $d)
        mkdir -p ${cfg.dirs.paths.home}/${path}
        rm -f ${cfg.dirs.paths.home}/${path}/$NAME
        ln -s $d ${cfg.dirs.paths.home}/${path}/$NAME
      done
    ''
    ) links_all.dirs_inside);

    shell_activate = with cfg.dirs; pkgs.writeScript "${name}_shell_activate.sh" (''
      set -e
    ''

    # If want a clean workspace before starting, remove everything
    + (if clean_before then ''
      rm -rf ${cfg.dirs.paths.home}
    '' else "")
    + ''
      mkdir -p ${cfg.dirs.paths.home}
      rm -f ${cfg.dirs.paths.home}/data ${cfg.dirs.paths.home}/${builtins.concatStringsSep " ${cfg.dirs.paths.home}/" homeLinks}
    ''

    # Link paths.data in the home directory
    + (if (builtins.isNull cfg.dirs.paths.data) then "" else ''
      mkdir -p ${cfg.dirs.paths.data}
      ln -s ${cfg.dirs.paths.data} ${cfg.dirs.paths.home}/data
    '')

    # Link dotfiles inside home directory
    + (builtins.concatStringsSep "\n" (builtins.map (path: ''
      if [[ -e "$HOME/${path}" ]]; then
        mkdir -p $(dirname ${cfg.dirs.paths.home}/${path})
        ln -s $HOME/${path} ${cfg.dirs.paths.home}/${path}
      fi
    '') homeLinks)) + ''

      ${links_direct}
      ${links_dirs_inside}

      # Remove annoying messages from Ubuntu
      touch ${cfg.dirs.paths.home}/.sudo_as_admin_successful

      rm -f ${cfg.dirs.paths.home}/.bashrc && touch ${cfg.dirs.paths.home}/.bashrc
      cat $HOME/.bashrc >> ${cfg.dirs.paths.home}/.bashrc
      cat ${custom_bashrc} >> ${cfg.dirs.paths.home}/.bashrc

      export SHELL="${cfg.shell.bin}"
      export OLDHOME="$HOME"
      export HOME="${cfg.dirs.paths.home}"

      # Remove any external "source" if they cannot be reached from inside the new HOME
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
      ${cfg.extra.init_script}

      ${shell_exec}

      ${exitScript}
      ${cfg.extra.exit_script}
      exit 0;
    '');
  in (if (builtins.deepSeq configcheck configcheck.ok)
    then shell_activate
    else builtins.throw "Failed checks: ${builtins.concatStringsSep ", " configcheck.list}"
  );
}
