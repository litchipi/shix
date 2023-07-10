{ lib, ...}: let
  mount_same_path = path: flags: {
    name = path;
    value = { dst = path; flags = flags; };
  };

  default_mounts = (builtins.listToAttrs (builtins.map (p: mount_same_path p [ "read_only" ]) [
    "/nix/store"
    "/run"
    "/run/wrappers"
    "/proc"
    "/dev"
    "/sys"
    "/usr"
    "/bin"
    "/etc"
  ]));

  default_symlinks = {
    
  };

  default_symlink_dir_content = {
  };

in {
  mkConfig = {
    name,
    username,
    homeDir,
    mounts ? {},
    symlinks ? {},
    symlink_dir_content ? {},
  ... }: let
    addmounts = lib.attrsets.recursiveUpdate default_mounts mounts;
    addsymlinks = lib.attrsets.recursiveUpdate default_symlinks symlinks;
    addsymlink_dir_content = lib.attrsets.recursiveUpdate default_symlink_dir_content symlink_dir_content;
  in {
    inherit username;
    hostname = "${name}-shix";
    home_dir = homeDir;
    addpaths = (lib.attrsets.mapAttrsToList (src: data: {
      inherit src;
      inherit (data) dst;
      type.mount.flags = data.flags;
    }) addmounts) ++ (lib.attrsets.mapAttrsToList (src: data: {
      
    }) addsymlinks) ++ (lib.attrsets.mapAttrsToList (src: data: {
    }) addsymlink_dir_content);
  };
}