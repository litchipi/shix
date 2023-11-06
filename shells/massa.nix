{ pkgs, colorstool, tmuxtool, ps1tool, inputs, system, ...}: let
  # old_pkgs = import inputs.nixpkgs-old {
  #   inherit system;
  # };
  rust_pkgs = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [ inputs.rust-overlay.overlays.default ];
  };
  lib = pkgs.lib;

  tomlEscapeKey = val:
    if builtins.isString val && builtins.match "[A-Za-z0-9_-]+" val != null
      then val
      else builtins.toJSON val;
  tomlEscapeValue = builtins.toJSON;
  tomlValue = v:
    if builtins.isList v
      then "[${builtins.concatStringsSep ", " (builtins.map tomlValue v)}]"
    else if builtins.isAttrs v
      then "{${builtins.concatStringsSep ", " (lib.attrsets.mapAttrsToList tomlKV v)}}"
    else tomlEscapeValue v;
  tomlKV = k: v: "${tomlEscapeKey k} = ${tomlValue v}";

  # languages_config = pkgs.lib.attrsets.mapAttrsToList (name: value: { inherit name; } // value) {
  languages_config = {
    nix.language-server.command = "${pkgs.nil}/bin/nil";
    python.language-server.command = "${pkgs.python310Packages.python-lsp-server}/bin/pylsp";
    go = {
      language-server = {
        command = "${pkgs.gopls}/bin/gopls";
        timeout = 60;
      };
    };
    rust = {
      language-server = {
        command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        timeout = 20;
      };
      config = {
        cachePriming.enable = false;
        cargo.features = "all";
        inlayHints = {
          closingBraceHints = true;
          closureReturnTypeHints.enable = "skip_trivial";
          parameterHints.enable = false;
          typeHints.enable = true;
          inlayHints.maxLength = 10;
        };
      };
    };
  };
  helix_languages = pkgs.writeText "helix-languages.toml" (
    builtins.concatStringsSep "\n\n" (pkgs.lib.attrsets.mapAttrsToList (name: val: let
      body = builtins.concatStringsSep "\n" (pkgs.lib.attrsets.mapAttrsToList tomlKV val);
    in ''
      [[language]]
      name = "${name}"
      ${body}
    '') languages_config)
  );
in rec {
  name = "massa";
  username = "john";
  root_mount_point = "/home/john/work/.massa_shix_root/";
  export_display_env = true;

  mounts.src."/home/john/work/massa".dst = "/home/john/workspace";
  symlink_dir_content.src."/home/john/.config/helix" = {
    dst = "/home/john/.config/helix";
    exceptions = [ "languages.toml" ];
  };
  copies.dst."/home/john/.config/helix/languages.toml" = {
    src = helix_languages;
    replace_existing = true;
  };

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
      pyyaml
      base58
    ]))

    # TODO  Switch to rust 1.72.0 soon
    (rust_pkgs.rust-bin."1.72.1".default.override {
      extensions = [ "rust-src" "llvm-tools-preview" ];
    })
    cargo-llvm-cov

    nodejs_20
    # nodejs-19_x
    nodePackages_latest.npm

    grpc-tools
    sshpass
    mold

    go
    go-task
    gci
    golangci-lint
    go-swagger
    gotools

    nodePackages_latest.ts-node
  ];

  env_vars = {
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    CMAKE="${pkgs.cmake}/bin/cmake";
    CGO_LDFLAGS="-L ${pkgs.zlib}/lib";
    PROTOC_INCLUDE="${pkgs.protobuf}/include";
  };

  shell.pkgconfig_libs = [
    pkgs.glibc.dev
    pkgs.gtk3.dev
    pkgs.webkitgtk.dev
    pkgs.glib.dev
    pkgs.pango.dev
    pkgs.harfbuzz.dev
    pkgs.cairo.dev
    pkgs.gdk-pixbuf.dev
    # old_pkgs.atk.dev
    pkgs.libsoup.dev
    pkgs.at-spi2-atk.dev
    pkgs.zlib.dev
  ];

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

    test_coverage = ''
      python3 ${../data/massa/llvm-cov.py} $@
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
