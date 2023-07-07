{ pkgs, ... }: let
  startup_script = pkgs.writeShellScript "vic-start-script" ''
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin"
    ping -c 1 isengard.local
    echo "8.8.8.8 isengard.local" >> /etc/hosts
    ping -c 1 isengard.local
    cat /etc/hosts
    env
  '';

  vic_config = {
    hostname = "test-vic";
    mount_dir = "/tmp/vic-mount-test";
    addpaths = [
      {
        src = "/nix/store";
        dst = "/nix/store";
        type.mount.flags = [ "read_only" ];
      }
      {
        src = "/run";
        dst = "/run";
        type.mount.flags = [ "read_only" ];
      }
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

  config_file = pkgs.writeText "vic-config.json" (builtins.toJSON vic_config);
in pkgs.writeShellScript "vic-start" ''
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:${pkgs.libseccomp.dev}/lib/pkgconfig"
  mkdir -p ${vic_config.mount_dir}
  cargo build
  echo "config file: ${config_file}"
  sudo ./target/debug/vic --debug --config-file ${config_file} --script ${startup_script}
''
