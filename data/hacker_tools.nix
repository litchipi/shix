{ pkgs, lib, tools_dir, ... }: {
    dst."${tools_dir}/custom".src = pkgs.fetchFromGitHub {
      owner = "litchipi";
      repo = "pentest_tools";
      rev = "29e951aa145f1ffa043e4e184963e7474e17312f";
      sha256 = "sha256-BVZxMO9VU2PVmZum9jMdmjzMXT5AwoXzkKaH8I+9/+Q=";
    };

    dst."${tools_dir}/lse.sh".src = let
      source = pkgs.fetchFromGitHub {
        owner = "diego-treitos";
        repo = "linux-smart-enumeration";
        rev = "06836ae365a707916dd8d6e355ba37c7f81e9bce";
        sha256 = "sha256-IRQAM1jid4zv+qJgFvtLmM/ctOLJrovo0LtIN3PI0eg=";
      };
    in "${source}/lse.sh";

    dst."${tools_dir}/pspy".src = let
      version = "1.2.1";
    in pkgs.fetchurl {
      url = "https://github.com/DominicBreuker/pspy/releases/download/v${version}/pspy64";
      sha256 = "sha256-yT8ppcwTR725DhShJCTmRpyM/qmiC4ALwkl1XwBDo7s=";
    };

    dst."${tools_dir}/fart".src = pkgs.fetchFromGitHub {
      owner = "litchipi";
      repo = "fart";
      rev = "fc62a9d21454e0b211a7d92ada8ca5ab2eb91e5e";
      sha256 = lib.fakeSha256;
    };

    dst."${tools_dir}/smtp_user_enum.py".src = pkgs.fetchFromGitHub {
      owner = "cytopia";
      repo = "smtp-user-enum";
      rev = "758d60268733b00d9b18d510ede3dabd1fab3294";
      sha256 = lib.fakeSha256;
    };
}
