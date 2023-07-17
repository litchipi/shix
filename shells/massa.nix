{ pkgs, colorstool, tmuxtool, ps1tool, inputs, system, ...}: let
  rust_pkgs = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [ inputs.rust-overlay.overlays.default ];
  };
in rec {
  name = "massa";
  username = "john";

  mounts.src."/home/john/work/massa".dst = "/home/john/workspace";
  symlinks.src."/home/john/.config/helix".dst = "/home/john/.config/helix";

  colors = with colorstool; {
    primary = fromhex "#6978ff";
    secondary = fromhex "#a84b8c";
    tertiary = fromhex "#9398be";
    highlight = fromhex "#e74e4e";
    active = fromhex "#cbe88c";
    inactive = fromhex "#8f977b";
  };

  packages = with pkgs; [
    clang
    mdbook
    cmake
    gnumake
    (python310.withPackages (p: with p; [
      toml
      passlib
      varint
      cryptography
      paramiko
      boto3
      tkinter
    ]))

    (rust_pkgs.rust-bin.nightly."2023-07-01".default.override {
      extensions = [ "rust-src" ];
    })

    nodejs_20
    # nodejs-19_x
    nodePackages_latest.npm

    grpc-tools
    sshpass
  ];

  env_vars = {
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    CMAKE="${pkgs.cmake}/bin/cmake";
    PROTOC_INCLUDE="${pkgs.protobuf}/include";
  };

  shell.pkgconfig_libs = [ pkgs.glibc.dev ];

  shell.scripts = with colorstool; {
    readnotes = ''
      touch $HOME/.notes
      tail +1f $HOME/.notes
    '';

    note = ''
      echo -e "$@\n" >> $HOME/.notes
      echo -e "${style.bold}${ansi colors.primary}Saved${reset}"
    '';

    handbook = ''
      xdg-open http://localhost:8085
    '';

    update_sc_deps = let
      deps = [
        "massalabs/as-transformer"
        "massalabs/as-types"
        "massalabs/massa-as-sdk"
        "massalabs/massa-sc-compiler"
        "massalabs/massa-sc-deployer"
        "massalabs/massa-web3"
      ];
    in ''
      npm update @${builtins.concatStringsSep " @" deps}
    '';
  };

  shell.ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=colors.primary; text="🦀"; }
    { style=style.italic; color=colors.secondary; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = colors.tertiary; left = ""; right = ""; })
    { style=style.bold; color=colors.primary; text="▶"; }
  ];

  # Some code executed each time we fire up the shell environment
  initScript = ''
    if ! [ -d ~/core-handbook ]; then
      echo "Repo core-handbook doesn't exist, please clone it from github"
      echo "and place it in $(realpath $HOME)/core-handbook"
    else
      cd ~/core-handbook
      # git pull
      ${pkgs.mdbook}/bin/mdbook build
      cd ./book
      ${pkgs.python310}/bin/python3 -m http.server 8085 1>$HOME/.handbook_stdout 2>$HOME/.handbook_stderr &
    fi
  '';

  # Some code we execute before quitting the shell environment
  exitScript = ''
    test -z "$(jobs -p)" || kill $(jobs -p)
  '';

  # Spawning a custom tmux when creating the shell
  tmux = {
    enable = true;
    # tmuxp_session = ../data/tmux_session_massa.json;
    configs_files = [
      ../data/tmux.conf
    ];
    theme_overwrite = vars: {
      "window-status-current-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=colors.highlight; add="nobold,noitalics"; }
        { txt = "#W"; fg=colors.primary; add="bold"; }
        { txt = " "; fg=colors.highlight; add="nobold"; }
      ];
      "window-status-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=colors.secondary; add="nobold,noitalics"; }
        { txt = "#W"; fg=colors.secondary; add="nobold"; }
        { txt = " "; fg=colors.secondary; add="nobold"; }
      ];
      "window-status-bell-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
      "window-status-activity-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
    };
  };
}
