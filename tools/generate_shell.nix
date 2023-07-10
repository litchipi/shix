{pkgs, lib, ...}: # let
  # TODO  Add secrets management system
  # secretstool = import ../tools/secrets.nix args;
#in {
{  
  mkShell = { shell_bin, ps1, ...}: tmux: {
    name,
    username,
    colors,
    
    packages ? [],
    libraries ? {},
    shellCommand ? null,
    initScript ? "",
    exitScript ? "",
    env_vars ? {},
  ...}:
  let
    base_env_vars = {
      HOME = "/home/${username}";
      PATH = builtins.concatStringsSep ":" ([
        "/run/wrappers/bin"
        "/run/current-system/sw/bin"
      ] ++ (builtins.map (p: "${p}/bin") packages));
      TERM = "xterm-256color";
      PS1 = ps1;
      USER = username;
    };
  
    setup_env_vars = builtins.concatStringsSep "\n" (
      lib.attrsets.mapAttrsToList (key: val:
        "export ${key}=\"${builtins.toString val}\""
      ) (lib.attrsets.recursiveUpdate base_env_vars env_vars));

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

    shell_cmd = if (builtins.isNull shellCommand) then shell_bin else shellCommand;
    shell_exec = if tmux.enable
      then tmux.start_command shell_cmd
      else shell_cmd;

    shell_activate = pkgs.writeScript "${name}_shell_activate.sh" (''
      #!${pkgs.bash}/bin/bash
      set -ex

      ${setup_env_vars}

      # Remove annoying messages from Ubuntu
      touch $HOME/.sudo_as_admin_successful

      cat /host/home/$USER/.bashrc \
        | sed "s/export PS1=/#export PS1=/g" \
        | grep -v -e "source.*git-prompt.*" \
        > $HOME/.bashrc
      echo "export PS1=\"${ps1}\"" >> $HOME/.bashrc
      cd $HOME
      
      ${initScript}
      ${shell_exec}
      ${exitScript}
      exit 0;
    '');
  in (if (builtins.deepSeq configcheck configcheck.ok)
    then shell_activate
    else builtins.throw "Failed checks: ${builtins.concatStringsSep ", " configcheck.list}"
  );
}
