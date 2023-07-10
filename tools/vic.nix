{ lib, ...}: let
  mount_same_path = path: flags: {
    name = path;
    value = { dst = path; flags = flags; };
  };

  default_mounts = builtins.listToAttrs (p: mount_same_path p [ "read_only" ]) [
    "/nix/store"
    "/run"
    "/run/wrappers"
    "/proc"
    "/dev"
    "/sys"
    "/usr"
    "/bin"
    "/etc"
  ];

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
    mounts = lib.attrsets.recursiveUpdate default_mounts mounts;
    symlinks = lib.attrsets.recursiveUpdate default_symlinks symlinks;
    symlink_dir_content = lib.attrsets.recursiveUpdate default_symlink_dir_content symlink_dir_content;
  in {
    inherit username;
    hostname = "${name}-shix";
    home_dir = homeDir;
    addpaths = (lib.attrsets.mapAttrsToList (src: data: {
      inherit src;
      inherit (data) = 
      dst = da;
      
    }
      data // { inherit src; type.mount.flags = data.flags }
    ) mounts) ++ (
      
    );
    (mount_same_path [
      "/nix/store"
      "/run"
      "/run/wrappers"
      "/proc"
      "/dev"
      "/sys"
      "/usr"
      "/bin"
    ] [ "read_only" ]) ++ [
      {
        src = "/etc";
        dst = "/etc";
        type.symlink_dir_content.exceptions = [
          "/etc/hosts"          
        ];
      }
      {
        src = "/etc/hosts";
        dst = "/etc/hosts";
        type = "copy";
      }
    ];
  };
}