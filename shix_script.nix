{ pkgs, lib, ... }:
{
  shellEditCommand,
  baseDir,
  remoteRepoUrl,
  pullBeforeEditing,
  pushAfterEditing,
... }: let
  forbidden_names = "edit remote init";

  pushToRemote = ''
    REPO=$(git remote -v|grep "fetch"|grep "${remoteRepoUrl}"|awk '{print $1}')
    if [ -z "$REPO" ]; then
      echo "Remote repository \"${remoteRepoUrl}\" not set up in repo ${baseDir}, skipping pushing to it..."
    else
      git push "$REPO"
    fi
  '';

  pullFromRemote = ''
    REPO=$(git remote -v|grep "fetch"|grep "${remoteRepoUrl}"|awk '{print $1}')
    if [ -z "$REPO" ]; then
      echo "Remote repository \"${remoteRepoUrl}\" not set up in repo ${baseDir}, skipping pulling from it..."
    else
      git pull "$REPO"
    fi
  '';

  shix_remote = ''
    if [ $# -ne 2 ]; then
        echo "Usage: shix remote <url> <name>"
        exit 1;
    fi

    nix run "$1"#"$2"
  '';

  shix_start = ''
    if [ $# -ne 1 ]; then
        echo "Usage: shix <name>"
        exit 1;
    fi

    pushd "${baseDir}"

    if [ ! -f "${baseDir}/shells/$1.nix" ]; then
      echo "Shell $1 doesn't exist"
      echo "Use \"shix edit $1\" to create it"
      exit 1;
    fi

    nix run .#"$1"
    popd
  '';

  shix_init = ''
    if [ $# -ne 0 ]; then
      echo "Usage: shix init"
      exit 1;
    fi

    echo "Cloning \"${remoteRepoUrl}\", if this repository doesn't exist yet, please fork the original project into this URL"
    git clone "${remoteRepoUrl}" "${baseDir}"
  '';
  
  shix_edit = ''
    if [ $# -ne 1 ]; then
      echo "Usage: shix edit <name>"
      exit 1;
    fi
    NAME="$1"
  
    if [[ "${forbidden_names}" == *"$NAME"* ]]; then
      echo "This name cannot be set, please choose another one"
      exit 1;
    fi

    pushd "${baseDir}"
    ${lib.strings.optionalString pullBeforeEditing pullFromRemote}

    FNAME="${baseDir}/shells/$NAME.nix"
    if [ ! -f "$FNAME" ]; then
      read -p "Do you wish to create a new shix \"$NAME\" ? [y/N] " -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$FNAME")"
        cp ${./shells/example.nix} "$FNAME"
        sed -i "s/ShixExample/$NAME/g" "$FNAME"
      else
        exit 0;
      fi
    fi

    "${shellEditCommand}" "$FNAME"

    git add "$FNAME"
    git commit -m "Edited $NAME shell"

    ${lib.strings.optionalString pushAfterEditing pushToRemote}
    popd
  '';
  
in pkgs.writeShellApplication {
  name = "shix";
  runtimeInputs = [ pkgs.git ];
  text = ''
    if ! [ -d "${baseDir}" ]; then
      echo "Shix directory \"${baseDir}\" not initialized";
      echo "Use 'shix init <repository url>' to initialize it"
      exit 1;
    fi

    if ! nix --version 1>/dev/null 2>/dev/null; then
        echo "Nix is not installed on your system"
        echo "Please install flake-enabled nix"
        exit 1;
    fi

    if [ $# -eq 0 ]; then
        echo "Please provide arguments, examples:"
        echo -e "\tshix init: Setup the directory if needed"
        echo -e "\tshix <name>: Starts the shell <name>"
        echo -e "\tshix edit <name>: Edit the shell <name> using \$EDITOR"
        exit 1;
    fi

    case $1 in
      "edit")
        shift 1;
        ${shix_edit}
        ;;
      "init")
        shift 1;
        ${shix_init}
        ;;
      "remote")
        shift 1;
        ${shix_remote}
        ;;
      *)
        ${shix_start}
        ;;
    esac
  '';
}
