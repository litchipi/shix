{ pkgs_unstable, pkgs, colorstool, tmuxtool, ps1tool, inputs, system, ...}: let
  rust_pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ inputs.rust-overlay.overlays.default ];
  };
in rec {
  name = "budman";
  homeDir = "/home/john/work/perso/finance/budman";

  colors = with colorstool; {
    primary = fromhex "#a84b8c";
    secondary = fromhex "#6978ff";
    tertiary = fromhex "#9398be";
    highlight = fromhex "#e74e4e";
    active = fromhex "#cbe88c";
    inactive = fromhex "#8f977b";
  };

  packages = with pkgs; [
    (python310.withPackages (p: with p; [
    ]))

    (rust_pkgs.rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" ];
    })
  ];

  env_vars = {
    LIBTORCH="${pkgs_unstable.libtorch-bin.dev}";
    LIBTORCH_INCLUDE="${pkgs_unstable.libtorch-bin.dev}";
    LIBTORCH_LIB="${pkgs_unstable.libtorch-bin.dev}";
  };

  # Custom aliases / scripts that are set for this shell
  shell.scripts = with colorstool; {
  };

  # The custom PS1 to be used
  shell.ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=colors.primary; text="󱀇"; }
    { style=style.italic; color=colors.secondary; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = colors.tertiary; left = ""; right = ""; })
    { style=style.bold; color=colors.highlight; text="|"; }
  ];

  # Spawning a custom tmux when creating the shell
  tmux = {
    enable = true;
    configs_files = [
      ../data/tmux.conf
    ];

    # Overwrite the theme of some elements of the global tmux configuration
    theme_overwrite = vars: {
      "window-status-current-format" = tmuxtool.tmuxfmts [
        { txt = "$ "; bg = "default"; fg=colors.highlight; add="nobold,noitalics"; }
        { txt = "#W"; fg=colors.primary; add="bold"; }
        { txt = " $"; fg=colors.highlight; add="nobold"; }
      ];
      "window-status-bell-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
      "window-status-activity-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
    };
  };
}
