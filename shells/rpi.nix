{ lib, inputs, system, pkgs, colorstool, tmuxtool, ps1tool, ...}: let
  rust_target = "aarch64-unknown-none-softfloat";
  rust_pkgs = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [ inputs.rust-overlay.overlays.default ];
  };
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
  name = "rpi";
  username = "john";

  root_mount_point = "/home/john/work/perso/embedded/";
  mounts.dst."/home/john/project".src = "/home/john/work/perso/embedded/jam_helper";
  symlink_dir_content.src."/home/john/.config/helix" = {
    dst = "/home/john/.config/helix";
    exceptions = [ "languages.toml" ];
  };
  copies.dst."/home/john/.config/helix/languages.toml".src = helix_languages;

  colors = with colorstool; {
    primary = fromhex "#C753A5";
    secondary = fromhex "#53A5C7";
    tertiary = fromhex "#A5C753";
    highlight = fromhex "#ECC6E1";
    active = fromhex "#FFFFFF";
    inactive = fromhex "#7C2863";
  };

  packages = with pkgs; [
    neo-cowsay
    (rust_pkgs.rust-bin.stable."1.72.0".default.override {
      extensions = [ "rust-src" ];
      targets = [ rust_target ];
    })
    coreboot-toolchain.aarch64
    libudev-zero
    qemu
    minicom
  ];

  shell.pkgconfig_libs = [ pkgs.libudev-zero ]; # Added to PKG_CONFIG_PATH

  env_vars = {
    CARGO_BUILD_TARGET = "aarch64-unknown-none-softfloat";
    CARGO_BUILD_aarch64_unknown_none_softfloat_LINKER = "aarch64-elf-ld";
    EXEMPLE_SHELL = "1";
  };

  # Custom aliases / scripts that are set for this shell
  shell.scripts = with colorstool; {
  };

  # The custom PS1 to be used
  shell.ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=colors.primary; text=""; }
    { style=style.italic; color=colors.secondary; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = colors.tertiary; left = "󱁆"; right = ""; })
    { style=style.bold; color=colors.highlight; text=" "; }
  ];

  shell.bashInitExtra = ''
  '';
  initScript = ''
  '';
  exitScript = ''
  '';

  tmux = {
    enable = true;
    configs_files = [
      ../data/tmux.conf
    ];

    theme_overwrite = vars: {
      "window-status-current-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=colors.highlight; add="nobold,noitalics"; }
        { txt = "#W"; fg=colors.primary; add="bold"; }
        { txt = " "; fg=colors.highlight; add="nobold"; }
      ];

      "window-status-bell-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
      "window-status-activity-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
    };
  };
}
