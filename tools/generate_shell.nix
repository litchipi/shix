{pkgs, lib, ...}: # let
  # TODO  Add secrets management system
  # secretstool = import ../tools/secrets.nix args;
#in {
{  
  mkShell = { shell_bin, ...}: tmux: {
    name,
    colors,
    
    packages ? [],
    libraries ? {},
    shellCommand ? null,
    initScript ? "",
    exitScript ? "",
  ...}:
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

    shell_cmd = if (builtins.isNull shellCommand) then shell_bin else shellCommand;
    shell_exec = if tmux.enable
      then tmux.start_command shell_cmd
      else shell_cmd;

    shell_activate = pkgs.writeScript "${name}_shell_activate.sh" (''
      set -e

      # Remove annoying messages from Ubuntu
      touch $HOME/.sudo_as_admin_successful

      cat /host/etc/bashrc /host/home/$USER/.bashrc \
        | sed "s/PS1=/: #PS1=/g" \
        | grep -v -e "source.*git-prompt.*" \
        > $HOME/.bashrc
      
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
