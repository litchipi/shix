{ lib, ...}: let
  mount_same_path = path: flags: {
    name = path;
    value = { dst = path; flags = flags; };
  };

  default_mounts = { src = (builtins.listToAttrs (
      (builtins.map (p: mount_same_path p [ "read_only" ]) [
        "/nix/store"
        "/nix/var/nix"
        "/run"
        "/run/wrappers"
        "/usr"
        "/bin"
        "/dev"
        "/lib64"
      ])
    )) // {    
      "/proc" = { dst = "/proc"; flags = []; mount_type = "proc"; };
      "/sys" = { dst = "/sys"; flags = []; mount_type = "sysfs"; };
    };
  };

  default_symlinks = {
  };

  default_symlink_dir_content = {
    src."/etc" = { dst = "/etc"; exceptions = [
        "/etc/bashrc"
        "/etc/profile"
      ];
    };
  };

  default_copies = {
  };

  fs_init = {
    "/tmp" = { type = "directory"; perm = 777; };
    "/var" = { type = "directory"; perm = 755; };
  };


  prep_addpath = l: lib.lists.flatten (lib.attrsets.mapAttrsToList (target: datal:
      if target == "src"
      then lib.attrsets.mapAttrsToList (src: data: lib.attrsets.recursiveUpdate {
          inherit src;
        } data) datal
      else if target == "dst"
      then lib.attrsets.mapAttrsToList (dst: data: lib.attrsets.recursiveUpdate {
          inherit dst;
        } data) datal
      else builtins.throw "Add path has to have either src or dst attribute set"
    ) l);

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
    inherit username root_mount_point fs_init;
    hostname = "${name}-shix";

    addpaths = (builtins.map ({src, dst, flags ? [], mount_type ? "auto"}: {
      inherit src dst;
      type.mount = {
        inherit flags mount_type;
      };
    }) (prep_addpath addmounts))

    ++ (builtins.map ({src, dst}: {
      inherit src dst;
      type = "symlink";
    }) (prep_addpath addsymlinks))
    
    ++ (builtins.map ({src, dst, exceptions ? []}: {
      inherit src dst;
      type.symlink_dir_content.exceptions = exceptions;
    }) (prep_addpath addsymlink_dir_content))

    ++ (builtins.map ({src, dst}: {
      inherit src dst;
      type = "copy";
    }) (prep_addpath addcopies));
  };
}