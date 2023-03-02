{ lib, pkgs, ... }@args: {
  mkSecrets = secrets: builtins.concatStringsSep "\n" (
    builtins.map ({ src, dest, perm ? "600", owner ? "$(whoami)", pwd_hint ? null, ...}: ''
      echo "Decrypting ${dest} file ..."
    '' + (
      if builtins.isNull pwd_hint then "" else ''
        echo "Password Hint: ${pwd_hint}"
      '') + ''
      ${pkgs.gnupg}/bin/gpg --output ${dest} --decrypt ${src}
      chmod ${perm} ${dest}
      chown ${owner} ${dest}
    '') secrets
  );

  rmSecrets = secrets: builtins.concatStringsSep "\n" (
    builtins.map ({ dest, ...}: ''
      if [ -f ${dest} ]; then
        ${pkgs.srm}/bin/srm ${dest}
      else
        echo "Secret ${dest} not found, cannot clear from storage ..."
      fi
    '') secrets
  );
}
