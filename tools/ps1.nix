{ pkgs, ...}@args: let
  colorstool = import ./colors.nix args;

  create_ps1_element = with colorstool; {
    style ? null,
    color ? null,
    text ? "",
    reset ? true,
    ...
  }: "\\[" + (if reset then colorstool.reset else "")
  + (if builtins.isNull style then "" else style)
  + (if builtins.isNull color then "" else ansi color)
  + "\\]${text}";
in {
  mkPs1 = defs: (builtins.foldl' (acc: {nosep ? false, ...}@el:
    acc + (create_ps1_element el) + (if nosep then "" else " ")
  ) "" defs) + "\\[${colorstool.reset}\\]";

  mkGitPs1 = { style ? null, color ? null, left ? "[", right ? "]" }: {
    inherit style color;
    nosep = true;
    text = "\\`__git_ps1 '${left}%s${right} '\\`";
  };

  import_git_ps1 = let
    rev = "0e5d9ef395467619b621540a7fdefbfc8062f2ac";
    gitprompt = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/git/git/${rev}/contrib/completion/git-prompt.sh";
      sha256 = "0rq8mm2kh09lg4ld84d7wxa3zhwi2k1q0v6c4a2cm5dilxy1cgj5";
    };
  in "source ${gitprompt}";
}
