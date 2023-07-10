{ lib, ...}: let
  mount_same_path = path: flags: {
    name = path;
    value = { dst = path; flags = flags; };
  };

  default_mounts = (builtins.listToAttrs (
    (builtins.map (p: mount_same_path p [ "read_only" ]) [
      "/nix/store"
      "/nix/var/nix"
      "/run"
      "/run/wrappers"
      "/usr"
      "/bin"
      "/etc"
      "/dev"
    ])
  )) // {    
    "/proc" = { dst = "/proc"; flags = []; mount_type = "proc"; };
    "/sys" = { dst = "/sys"; flags = []; mount_type = "sysfs"; };
  };

  default_symlinks = {
  };

  default_symlink_dir_content = {
  };

  default_copies = {
  };

  fs_init = {
    "/tmp" = { type = "directory"; perm = 777; };
    "/var" = { type = "directory"; perm = 755; };
  };


  notNull = l: builtins.filter ({src, data}: !builtins.isNull data) (
    lib.attrsets.mapAttrsToList (src: data: { inherit src data; }) l
  );

in {
  mkConfig = {
    name,
    username,
    root_mount_point ? "/tmp/shix/${name}/",
    mounts ? {},
    symlinks ? {},
    symlink_dir_content ? {},
    copies ? {},
  ... }: let
    addmounts = lib.attrsets.recursiveUpdate default_mounts mounts;
    addsymlinks = lib.attrsets.recursiveUpdate default_symlinks symlinks;
    addsymlink_dir_content = lib.attrsets.recursiveUpdate default_symlink_dir_content symlink_dir_content;
    addcopies = lib.attrsets.recursiveUpdate default_copies copies;
  in {
    inherit username root_mount_point;
    hostname = "${name}-shix";
    addpaths = (builtins.map ({src, data}: {
      inherit src;
      inherit (data) dst;
      type.mount.flags = data.flags;
    }) (notNull addmounts))

    ++ (builtins.map ({src, data}: {
      inherit src;
      inherit (data) dst;
      type = "symlink";
    }) (notNull addsymlinks))
    
    ++ (builtins.map ({src, data}: {
      inherit src;
      inherit (data) dst;
      type.symlink_dir_content.exceptions = data.exceptions;
    }) (notNull addsymlink_dir_content))

    ++ (builtins.map ({src, data}: {
      inherit src;
      inherit (data) dst;
      type = "copy";
    }) (notNull addcopies));
    inherit fs_init;
  };
}