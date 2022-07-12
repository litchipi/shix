pkgs:
let
  # Name of the shell
  name = "ShixExample";

  # Some utilities we will use 
  colorstool = import ../tools/colors.nix pkgs;
  tmuxtool = import ../tools/tmux.nix pkgs;
  ps1tool = import ../tools/ps1.nix pkgs;

  # The color palette that will be used for later configs
  colors = [
    {r=255; g=0; b=0;}      # 0 #FF0000
    {r=255; g=255; b=0;}    # 1 #FFFF00
    {r=0; g=255; b=0;}      # 2 #00FF00
    {r=0; g=255; b=255;}    # 3 #00FFFF
    {r=0; g=0; b=255;}      # 4 #0000FF
    {r=255; g=0; b=255;}    # 5 #FF00FF
    {r=0; g=128; b=128;}    # 6 #008080
    {r=128; g=0; b=0;}      # 7 #800000
    {r=128; g=0; b=128;}    # 8 #800080
  ];
  get_col = builtins.elemAt colors;

  # Create the tmux configuration from this:
  tmux_config = tmuxtool.generate_config {
    inherit colors name;

    # Overwrite the theme of some elements of the global tmux configuration
    tmux_theme_overwrite = vars: {
      "window-status-current-format" = tmuxtool.tmuxfmts [
        { txt = "$ "; bg = "default"; fg = get_col 3; add="nobold,noitalics"; }
        { txt = "#W"; fg = get_col 0; add="bold"; }
        { txt = " $"; fg = get_col 3; add="nobold"; }
      ];
      "window-status-bell-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
      "window-status-activity-style" = tmuxtool.tmuxstyle { fg = colorstool.basic.white; };
    };

    # Overwrite some variables that are set in the tmux config (see util code)
    tmux_vars_overwrite = {
      status.left = {
        length = 100;
        left = "#I:#P";                     # Left part of the left status bar
        mid = "#(date +%d/%m/%Y)";          # Mid part of the left status bar
        right = tmuxtool.statusbar.int_ip;  # Right part of the left status bar

        # Colors to be set in foreground and background of each part
        colors = let get_col = builtins.elemAt colors; in [
          (get_col 0) (colorstool.basic.black)  # bg fg
          (get_col 2) (colorstool.basic.black)
          (colorstool.basic.gray 35) (get_col 3)
        ];
      };

      status.right = {
        length= 40;
        left = "#(whoami)";
        colors = let get_col = builtins.elemAt colors; in [
          (colorstool.basic.gray 35) (get_col 3)
          (get_col 2) (colorstool.basic.black)
          (get_col 0) (colorstool.basic.black)
        ];
      };
    };
  };
in {
  inherit name;

  # Custom aliases / scripts that are set for this shell
  scripts = with colorstool; {
    cow = "cowsay \"$@\"";
  
    readnotes = ''
      touch $HOME/data/notes
      tail +1f $HOME/data/notes
    '';

    note = ''
      echo -e "$@\n" >> $HOME/data/notes
      echo -e "${style.bold}${ansi (get_col 0)}Saved${reset}"
    '';
  };

  # The custom PS1 to be used
  ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=get_col 0; text="${name}"; }
    { style=style.italic; color=get_col 1; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = get_col 2; left = "*"; right = "*"; })
    { style=style.bold; color=get_col 3; text=":-)"; }
  ];

  # Some code to execute each time a new shell is created (in tmux for example)
  bashInitExtra = ''
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

  # The code that will be executed when starting the shell
  shellCommand = tmuxtool.generate_command { inherit name tmux_config;};

  # Where to place the directories for
  new_home = "/tmp/my_new_temporary_home";    # The home directory (can be temporary)
  data_dir = "/tmp/some_persistent_storage";  # The data directory (should be persistent)

  # Create symlinks by directly linking the source to the destination
  symLinks.direct = {
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
  symLinks.dirs_inside = {
    # Destination   Source
    "other/var" = "/var/";
  };

  # Add packages to the shell
  packages = with pkgs; [
    neo-cowsay
  ];
}
