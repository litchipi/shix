pkgs:
let
  lib = pkgs.lib;
  colorstool = import ./colors.nix pkgs;
in with colorstool; rec {
  
  col = c: if c == "default" then c else "#${tohex c}";
  
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

  statusbar = {
    disk_usage = " #(df -l|grep -e \"/$\"|awk -F ' ' '{print $5}')";
    connected = "#(if ping -c 1 1.1.1.1 2>/dev/null 1>/dev/null; then echo ''; else echo ''; fi)";
    int_ip= "#(ip -4 -o a|awk '$2!=\"lo\"{print $4}'|cut -d '/' -f 1)";
    iface = "#(ip -4 -o a|awk '$2!=\"lo\"{print $2}')";
  };

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

  generate_config = {
    name, colors ? [],
    tmux_vars_overwrite ? {},
    tmux_theme_overwrite ? vars: {},
    tmux_configs_files ? [],
  }: let 
    
    get_palette = builtins.elemAt colors;

    generate_theme = theme: builtins.concatStringsSep "\n" (
      lib.attrsets.mapAttrsToList (name: cnt:
      "set -g ${name} \"${builtins.toString cnt}\""
      )
      theme) + "\n";

    tmux_vars = {
      status = {
        interval = "10";
        justify = "centre";
      };
      status.left = {
        length = "40";
        left = "#H";
        mid = "#(whoami)";
        right = "#S";
        colors = [
          (get_palette 0) basic.white
          (get_palette 2) (get_palette 5)
          (basic.gray 40) (get_palette 4)
        ];
      };
      status.right = {
        length = "150";
        right = "%D";
        mid = "%H:%M";
        left = "${statusbar.connected} ${statusbar.disk_usage}";
        colors = [
          (basic.gray 40) (get_palette 4)
          (get_palette 2) (get_palette 5)
          (get_palette 0) basic.white
        ];
      };
    };
    
    tmux_theme = vars: let
      get_col = col: builtins.elemAt col;
    in {
      "pane-border-style" = tmuxstyle { fg = get_palette 3; bg = "default"; };
      "pane-active-border-style" = tmuxstyle { fg = get_palette 0; bg = "default"; add = "bold";};
      "message-style" = tmuxstyle { fg = get_palette 1; };

      "mode-style" = tmuxstyle { bg = get_palette 2; fg = basic.black; };

      "status-style" = tmuxstyle { bg = "default"; };
      "status-left" = with vars.status; sidebar { char = ""; left = true;} [
        { bg = get_col left.colors 0; fg = get_col left.colors 1; txt = left.left; add="bold";}
        { bg = get_col left.colors 2; fg = get_col left.colors 3; txt = left.mid;}
        { bg = get_col left.colors 4; fg = get_col left.colors 5; txt = left.right; add="nobold";}
      ];
      "status-right" = with vars.status; sidebar {char = ""; left=false;} [
        { bg = get_col right.colors 0; fg = get_col right.colors 1; txt = right.left; add="nobold";}
        { bg = get_col right.colors 2; fg = get_col right.colors 3; txt = right.mid; add="bold";}
        { bg = get_col right.colors 4; fg = get_col right.colors 5; txt = right.right; }
      ];

      "status-interval" = vars.status.interval;
      "status-justify" = vars.status.justify;
      "status-left-length" = vars.status.left.length;
      "status-right-length" = vars.status.right.length;

      "window-status-current-format" = tmuxfmts [
        { txt = " "; bg="default"; fg = get_palette 0; add="nobold,noitalics"; }
        { txt = "#W"; add = "bold"; }
        { txt = " "; add="nobold"; }
      ];

      "window-status-format" = tmuxfmt {
        txt = "  #W  ";
      };

      "window-status-style" = tmuxstyle {
        bg="default";
        fg = get_palette 7;
        add="nobold,italics";
      };
      "window-status-activity-style" = tmuxstyle { fg = get_palette 2; add = "bold,noitalics"; };
      "window-status-bell-style" = tmuxstyle { fg = get_palette 2; add = "reverse,bold,noitalics"; };
    };

    tmux_theme_file = let
      vars = lib.attrsets.recursiveUpdate tmux_vars tmux_vars_overwrite;
    in pkgs.writeTextFile {
      name = "tmux_${name}_theme.conf";
      text = generate_theme (lib.attrsets.recursiveUpdate (tmux_theme vars) (tmux_theme_overwrite vars));
    };
  in pkgs.concatTextFile {
    name = "tmux_${name}.conf";
    files = [
      tmux_theme_file
    ] ++ tmux_configs_files;
  };

  # Generate a tmux session isolated from the global system one, with the custom configuration
  generate_command = { name, tmux_config }: "tmux -L \"${name}\" -f \"${tmux_config}\"";
  quit_command = name: "tmux -L \"${name}\" kill-server";
}
