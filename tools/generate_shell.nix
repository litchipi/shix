{pkgs, lib, ...}: # let
  # TODO  Add secrets management system
  # secretstool = import ../tools/secrets.nix args;
#in {
{  
  mkShell = { shell_bin, bashrc, ...}: tmux: {
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
      #!${pkgs.bashInteractive}/bin/bash
      set -e

      # Temporary variables set for the initialization script, will be overwritten by bashrc
      export PATH="/run/wrappers/bin:/run/current-system/sw/bin"
      export HOME="/home/${username}"
      export TERM="xterm-256color"

      # Remove annoying messages from Ubuntu
      touch $HOME/.sudo_as_admin_successful

      rm -f $HOME/.bashrc $HOME/.host_bashrc
      cat /host/etc/profile | grep 'set-environment' >> $HOME/.host_bashrc
      cat /host/etc/bashrc \
        | sed 's/PS1=/: #PS1=/g' \
        | sed 's+. /etc/profile+: #. /etc/profile+g' \
        >> $HOME/.host_bashrc

      cat << EOF > $HOME/.bashrc
      if [ -n "\$__SANDBOXED_ETC_BASHRC_SOURCED" ]; then return; fi
      __SANDBOXED_ETC_BASHRC_SOURCED=1
      source $HOME/.host_bashrc
      EOF
      cat ${bashrc} >> $HOME/.bashrc
      
      ${initScript}
      set +e
      ${shell_exec}
      ${exitScript}
      exit 0;
    '');
  in (if (builtins.deepSeq configcheck configcheck.ok)
    then builtins.trace "Activation script: ${shell_activate}" shell_activate
    else builtins.throw "Failed checks: ${builtins.concatStringsSep ", " configcheck.list}"
  );
}
