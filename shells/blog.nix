{ pkgs, pkgs_unstable, colorstool, tmuxtool, ps1tool, inputs, system, ...}: let
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
    rust = {
      language-server = {
        command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        timeout = 60;
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
  name = "blog";
  username = "john";
  root_mount_point = "/home/john/work/perso/blog/.root";
  export_display_env = true;

  mounts.src."/home/john/work/perso/blog/ecoweb".dst = "/home/john/ecoweb";
  mounts.src."/home/john/work/perso/blog/litchipi.github.io".dst = "/home/john/github_blog";
  symlink_dir_content.src."/home/john/.config/helix" = {
    dst = "/home/john/.config/helix";
    exceptions = [ "languages.toml" ];
  };
  copies.dst."/home/john/.config/helix/languages.toml".src = helix_languages;

  colors = with colorstool; {
    primary = fromhex "#96ceb4";
    secondary = fromhex "#ffeead";
    tertiary = fromhex "#ff6f69";
    highlight = fromhex "#FFB81E";
    active = fromhex "#cbe88c";
    inactive = fromhex "#8f977b";
  };

  packages = with pkgs; [
    clang
    (rust_pkgs.rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" ];
    })
  ];

  env_vars = {
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    CMAKE="${pkgs.cmake}/bin/cmake";
  };

  shell.pkgconfig_libs = [ pkgs.glibc.dev ];

  shell.scripts = with colorstool; {
  };

  shell.ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=colors.primary; text="󰌪 "; }
    { style=style.italic; color=colors.secondary; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = colors.tertiary; left = ""; right = ""; })
    { style=style.bold; color=colors.primary; text=" "; }
  ];

  # Some code executed each time we fire up the shell environment
  initScript = ''
  '';

  # Some code we execute before quitting the shell environment
  exitScript = ''
  '';

  # Spawning a custom tmux when creating the shell
  tmux = {
    enable = true;
    configs_files = [
      ../data/tmux.conf
    ];
    theme_overwrite = vars: {
      "window-status-current-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=colors.highlight; add="nobold,noitalics"; }
        { txt = "#W"; fg=colors.primary; add="bold"; }
        { txt = " "; fg=colors.highlight; add="nobold"; }
      ];
      "window-status-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=colors.secondary; add="nobold,noitalics"; }
        { txt = "#W"; fg=colors.secondary; add="nobold"; }
        { txt = " "; fg=colors.secondary; add="nobold"; }
      ];
      "window-status-bell-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
      "window-status-activity-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
    };
  };
}
