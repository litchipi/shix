{ lib, ...}: let
  dst_home = "\"/home/$USER\"";
  dir_binds = name: add: lib.attrsets.recursiveUpdate {
    # DST to SRC
    read-only = {
      "/nix" = "/nix";
      "/run" = "/run";
      "/usr" = "/usr";
      "/bin" = "/bin";
      "/sys" = "/sys";
      "/lib64" = "/lib64";

      # Minimum config to get a (globally) working shell
      "/etc/nix" = "/etc/nix";
      "/etc/static" = "/etc/static";
      "/etc/resolv.conf" = "/etc/resolv.conf";
      "/etc/ssl" = "/etc/ssl";
      "/etc/locale.conf" = "/etc/locale.conf";
      "/etc/passwd" = "/etc/passwd";
      "/etc/group" = "/etc/group";
      "/etc/profile" = "/etc/profile";
    };

    # Read + Write
    bind = {
      "/host" = "\"/\"";
      "${dst_home}/.ssh" = "$HOME/.ssh";
      "${dst_home}/.config/git" = "$HOME/.config/git";
    };
    symlinks = {};
  } add;
in
{
  get_args = {
    bash_data,
  ... }: {
    name,
    homeDir,
    binds ? {},
    env_vars ? {},
    create_dirs ? [],
    add_args ? [],
    term ? "\"$TERM\"",
  ... }: let
    all_binds = dir_binds name binds;
  in [
    "--cap-add ALL"
    "--die-with-parent"
    "--clearenv"
    "--new-session"
    "--unshare-all"
    "--share-net"
    "--proc /proc"
    "--dev /dev"
    "--tmpfs /tmp"
    "--bind ${homeDir} ${dst_home}"
  ]
  ++ (lib.attrsets.mapAttrsToList (dst: src: "--ro-bind ${src} \"${dst}\"") all_binds.read-only)
  ++ (lib.attrsets.mapAttrsToList (dst: src: "--bind ${src} \"${dst}\"") all_binds.bind)
  ++ (lib.attrsets.mapAttrsToList (dst: src: "--symlink ${src} \"${dst}\"") all_binds.symlinks)
  ++ [
    "--ro-bind ${bash_data.bashrc} /etc/bashrc"
    "--setenv TERM ${term}"
    "--setenv SHELL \"${bash_data.shell_bin}\""
    "--setenv PATH /run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
    "--setenv HOME ${dst_home}"
  ]
  ++ (lib.attrsets.mapAttrsToList (name: value: "--setenv ${name} \"${value}\"") env_vars)
  ++ (builtins.map (d: "--dir ${d}") create_dirs)
  ++ add_args;
}
