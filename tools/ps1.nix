pkgs: let
  colorstool = import ./colors.nix pkgs;
  
  create_ps1_element = with colorstool; {
    style ? null,
    color ? null,
    text ? "",
  }: "\\[${style}${ansi color}\\]${text}";
in {
  mkPs1 = defs: builtins.concatStringsSep " " (builtins.map create_ps1_element defs) + "\\[${colorstool.reset}\\] ";

  mkGitPs1 = { style ? null, color ? null, left ? "[", right ? "]" }: {
    inherit style color;
    text = "${left}GITPS1TODO${right}";
  };

  import_git_ps1 = "";
}
