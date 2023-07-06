{ lib, pkgs, ... }@args:
let
  colorstool = import ./colors.nix args;

  col = c: if c == "default" then c else "#${colorstool.tohex c}";

  statusbar = {
    disk_usage = " #(df -l $HOME|awk 'NR==2 {print $5}')";
    connected = "#(if ping -c 1 1.1.1.1 2>/dev/null 1>/dev/null; then echo '󰖟'; else echo ''; fi)";
    int_ip= "#(ip -4 -o a|awk '$2!=\"lo\"{print $4}'|cut -d '/' -f 1)";
    iface = "#(ip -4 -o a|awk '$2!=\"lo\"{print $2}')";
    dir_totsize = dirpath: "#(du -hs ${dirpath} 2>/dev/null|awk '{print $1}')";
    mem_usage = opts: key: let
      cmd = "free ${opts}|grep \"${key}\"";
    in "#(${cmd}|awk '{print $3}')/#(${cmd}|awk '{print $2}')";
  };

  tmuxstyle = {fg ? null, bg ? null, add ? null, ...}: builtins.concatStringsSep ","
    ((if (builtins.isNull fg) then [] else [ "fg=${col fg}" ]) ++
    (if (builtins.isNull bg) then [] else [ "bg=${col bg}" ]) ++
    (if (builtins.isNull add) then [] else [ add ]));

  tmuxfmts = cnt: builtins.concatStringsSep "" (builtins.map tmuxfmt cnt);

  tmuxfmt = { txt, ...}@fmt: let
    all_styles = tmuxstyle fmt;
    style = if all_styles == "" then "" else "#[${all_styles}]";
  in
    style + txt;

  sidebar = {char, left}: content_list: let
    sepchar = col0: col1: if !left
      then "#[fg=${col col0},bg=${col col1}]${char}"
      else "#[fg=${col col1},bg=${col col0}]${char}";
    first = builtins.elemAt content_list 0;
    last = lib.lists.last content_list;
    res = builtins.foldl' (state: cnt: {
        inherit (cnt) bg;
        sep = true;
        acc = state.acc +
          (if state.sep
          then sepchar cnt.bg state.bg else "")
          + tmuxfmt (cnt // { txt = " " + cnt.txt + " "; });
      }) {
        bg = null;
        acc = if !left then sepchar first.bg "default" else "";
        sep = false;
      } content_list;
    in
      res.acc + (if left then sepchar "default" last.bg else "");

  generate_config = tmux: { name, colors, ... }: with tmux; with colorstool; let
    generate_theme = theme: builtins.concatStringsSep "\n" (
      lib.attrsets.mapAttrsToList (name: cnt:
      "set -g ${name} \"${builtins.toString cnt}\""
      )
      theme) + "\n";

    tmux_vars = {
      status = rec {
        interval = "10";
        justify = "centre";
        left = {
          length = "40";
          left = "#H";
          mid = "#(whoami)";
          right = "#S";
          colors = {
            left = { bg=colors.primary; fg=colorstool.text_contrast colors.primary; };
            mid = { bg=colors.secondary; fg=colorstool.text_contrast colors.secondary; };
            right = { bg = basic.gray 40; fg = colors.tertiary; };
          };
        };
        right = {
          length = "150";
          right = "%D";
          mid = "%H:%M";
          left = "${statusbar.connected} ${statusbar.disk_usage}";
          colors = {
            left = left.colors.right;
            mid = left.colors.mid;
            right = left.colors.left;
          };
        };
      };
    };

    tmux_theme = vars: {
      "pane-border-style" = tmuxstyle { fg = colors.inactive; bg = "default"; };
      "pane-active-border-style" = tmuxstyle { fg = colors.active; bg = "default"; add = "bold";};
      "message-style" = tmuxstyle { fg = colors.highlight; };

      "mode-style" = tmuxstyle { bg = colors.secondary; fg = basic.black; };

      "status-style" = tmuxstyle { bg = "default"; };
      "status-left" = with vars.status; sidebar { char = ""; left = true;} [
        { inherit (left.colors.left) bg fg; txt = left.left; add="bold";}
        { inherit (left.colors.mid) bg fg; txt = left.mid;}
        { inherit (left.colors.right) bg fg; txt = left.right; add="nobold";}
      ];
      "status-right" = with vars.status; sidebar {char = ""; left=false;} [
        { inherit (right.colors.left) bg fg; txt = right.left; add="nobold";}
        { inherit (right.colors.mid) bg fg; txt = right.mid; add="bold";}
        { inherit (right.colors.right) bg fg; txt = right.right; }
      ];

      "status-interval" = vars.status.interval;
      "status-justify" = vars.status.justify;
      "status-left-length" = vars.status.left.length;
      "status-right-length" = vars.status.right.length;

      "window-status-current-format" = tmuxfmts [
        { txt = " "; bg="default"; fg = colors.highlight; add="nobold,noitalics"; }
        { txt = "#W"; add = "bold"; }
        { txt = " "; add="nobold"; }
      ];

      "window-status-format" = tmuxfmt {
        txt = "  #W  ";
      };

      "window-status-style" = tmuxstyle {
        bg="default";
        fg = colors.inactive;
        add="nobold,italics";
      };
      "window-status-activity-style" = tmuxstyle { fg = colors.active; add = "bold,noitalics"; };
      "window-status-bell-style" = tmuxstyle { fg = colors.highlight; add = "reverse,bold,noitalics"; };
    };

    tmux_theme_file = let
      vars = lib.attrsets.recursiveUpdate tmux_vars vars_overwrite;
    in pkgs.writeTextFile {
      name = "tmux_${name}_theme.conf";
      text = generate_theme
        (lib.attrsets.recursiveUpdate (tmux_theme vars) (theme_overwrite vars));
    };
    tmux_other_configs = pkgs.writeTextFile {
      name = "tmux_${name}_configs.conf";
      text = ''
        set -g default-command "${pkgs.bashInteractive}/bin/bash -i"
        set -g default-terminal "tmux-256color"
        set -ga terminal-overrides ",*256col*:Tc"
        set -g @plugin 'nhdaly/tmux-better-mouse-mode'

      '' + config_extra;
    };
  in pkgs.concatTextFile {
    name = "tmux_${name}.conf";
    files = (if notheme then [] else [tmux_theme_file]) ++ [
      tmux_other_configs
    ] ++ configs_files;
  };

  # TODO   Do something with the "cmd" param
  # TODO   Generate tmuxp session from nix config instead of file
  generate_command = { name, tmux_config, config_file, cmd, ... }: let
    tmux_bin = "${tmux_config.tmux_package}/bin/tmux";
    tmuxp_bin = "${tmux_config.tmuxp_package}/bin/tmuxp";
  in if builtins.isNull tmux_config.tmuxp_session
    then "${tmux_bin} -L \"${name}\" -u -f \"${config_file}\""
    else "${tmuxp_bin} load -L \"${name}\" -f \"${config_file}\" -y -s \"${name}\" -2 ${tmux_config.tmuxp_session}";

  default_tmux_config = {
    enable = false;
    notheme = false;
    vars_overwrite = {};
    theme_overwrite = vars: {};
    configs_files = [];
    config_extra = "";
    exec = "${pkgs.bashInteractive}/bin/bash -i";
    tmuxp_session = null;
    tmux_package = pkgs.tmux;
    tmuxp_package = pkgs.tmuxp;
  };
in {
  build = { name, tmux ? {}, ...}@cfg: let
    tmux_config = lib.attrsets.recursiveUpdate default_tmux_config tmux;
    tmux_bin = "${tmux_config.tmux_package}/bin/tmux";
  in {
    inherit (tmux_config) enable;

    start_command = cmd: generate_command {
      inherit name cmd tmux_config;
      config_file = generate_config tmux_config cfg;
    };

    add_bashrc = ''
      quit() {
        ${tmux_bin} -L "${name}" kill-server;
      }
    '';
  };

  inherit statusbar tmuxstyle tmuxfmts;
}
