pkgs:
let
  # Name of the shell
  name = "ShixExample";

  # Some utilities we will use 
  colorstool = import ../tools/colors.nix pkgs;
  tmuxtool = import ../tools/tmux.nix pkgs;
  ps1tool = import ../tools/ps1.nix pkgs;

in rec {
  inherit name;

  # The color palette that will be used for generated themes
  colors = {
    primary = {r=255; g=0; b=0;};
    secondary = {r=0; g=255; b=0;};
    tertiary = {r=0; g=0; b=255;};
    highlight = {r=0; g=255; b=255;};
    active = {r=255; g=255; b=0;};
    inactive = {r=128; g=128; b=0;};
  };

  # Where to place the directories for
  dirs.new_home = "/tmp/my_new_temporary_home";    # The home directory (can be temporary)
  dirs.data_dir = "/tmp/some_persistent_storage";  # The data directory (should be persistent)

  # Create symlinks by directly linking the source to the destination
  dirs.symLinks.direct = {
    # Destination   Source
    "other/tmp" = "/tmp/";

    awesome_nix = pkgs.fetchFromGitHub {
      owner = "nix-community";
      repo = "awesome-nix";
      rev = "5e09d94eba14282976bcb343a9392fe54d7a310c";
      sha256 = "sha256-y3CgwyC0A7X6SZRu8hogOrvcfYlwa+M9OuViYa/zRas=";
    };
  };

  # Create symlinks by linking every directory inside the source in the destination
  dirs.symLinks.dirs_inside = {
    # Destination   Source
    "other/var" = "/var/";
  };

  # Add packages to the shell
  packages = with pkgs; [
    neo-cowsay
  ];

  # Custom aliases / scripts that are set for this shell
  shell.scripts = with colorstool; {
    cow = "cowsay \"$@\"";
  
    readnotes = ''
      touch $HOME/data/notes
      tail +1f $HOME/data/notes
    '';

    note = ''
      echo -e "$@\n" >> $HOME/data/notes
      echo -e "${style.bold}${ansi colors.primary}Saved${reset}"
    '';
  };

  # The custom PS1 to be used
  shell.ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=colors.primary; text="${name}"; }
    { style=style.italic; color=colors.secondary; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = colors.tertiary; left = "*"; right = "*"; })
    { style=style.bold; color=colors.highlight; text=":-)"; }
  ];

  # Some code to execute each time a new shell is created (in tmux for example)
  shell.bashInitExtra = ''
    cow "Welcome !"
  '';

  # Some code executed each time we fire up the shell environment
  initScript = ''
    touch $HOME/somefile
  '';

  # Some code we execute before quitting the shell environment
  exitScript = ''
    rm -f $HOME/somefile
  '';

  # Spawning a custom tmux when creating the shell
  tmux = {
    enable = true;

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

    # Overwrite some variables that are set in the tmux config (see util code)
    vars_overwrite = {
      status.left = {
        length = 100;
        left = "#I:#P";                     # Left part of the left status bar
        mid = "#(date +%d/%m/%Y)";          # Mid part of the left status bar
        right = tmuxtool.statusbar.int_ip;  # Right part of the left status bar
      };
    };
  };
}
