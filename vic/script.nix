{ pkgs, ... }: let
  mount_same_path = paths: flags: builtins.map(p: {
    src = p;
    dst = p;
    type.mount.flags = flags;
  }) paths;
  
  vic_config = {
    username = "john";
    hostname = "test-vic";
    home_dir = "./hometest";
    addpaths = (mount_same_path [
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
  config_file = pkgs.writeText "vic-config.json" (builtins.toJSON vic_config);

  startup_script = pkgs.writeShellScript "vic-start-script" ''
    export PATH="/run/wrappers/bin:/run/current-system/sw/bin"
    export TERM="xterm-256color"
    export PS1="\u \w $ "
    export USER=${vic_config.username}
    export HOME="/home/$USER"
    cd $HOME
    echo "8.8.8.8 isengard.local" | sudo tee -a /etc/hosts
    ping -c 1 isengard.local
    tail -n 5 /etc/hosts
    ${pkgs.bashInteractive}/bin/bash -i
  '';

in pkgs.writeShellScript "vic-start" ''
  set -e
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:${pkgs.libseccomp.dev}/lib/pkgconfig"
  mkdir -p ${vic_config.home_dir}
  cargo build
  echo "config file: ${config_file}"
  sudo ./target/debug/vic \
    --debug \
    --config-file ${config_file} \
    --script ${startup_script} \
    --uid "$(cat /etc/passwd | grep '${vic_config.username}' | cut -d ':' -f 3)" \
    --gid "$(cat /etc/passwd | grep '${vic_config.username}' | cut -d ':' -f 4)"
''
