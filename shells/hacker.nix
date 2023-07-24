{ pkgs, lib, colorstool, tmuxtool, ps1tool, ... }: let
  redcolor = colorstool.fromhex "#FF0000";
  greencolor = colorstool.fromhex "#00FF00";

  vm_dir = "$HOME/.vms";
in rec {
  # Name of the shell
  name = "hacker";
  username = "john";
  export_display_env = true;
  
  mounts.dst."/home/john".src = "/home/john/work/perso/pentest/workspace";
  symlinks = lib.attrsets.recursiveUpdate {
    src."/home/john/.config/helix".dst = "/home/john/.config/helix";
    dst."/home/john/.seclists".src = pkgs.fetchFromGitHub {
      owner = "danielmiessler";
      repo = "SecLists";
      rev = "master";
      sha256 = "sha256-yVxb5GaQDuCsyjIV+oZzNUEFoq6gMPeaIeQviwGdAgY=";
    };

    dst."/home/john/.payloads".src = pkgs.fetchFromGitHub {
      owner = "swisskyrepo";
      repo = "PayloadsAllTheThings";
      rev = "cd19bb94096a61ef22d0c9668bc29674fce53fa0";
      sha256 = "sha256-UR7KXLZzqrhVr0dd6cdiHPcae6jQeWpd79A+IR6XRQs=";
    };
  } (import ../data/hacker_tools.nix {
    inherit pkgs lib;
    tools_dir = "/home/john/tools";
  });

  symlink_dir_content.src."/etc".exceptions = [
    "/etc/hosts"
  ];
  copies.src."/etc/hosts".dst = "/etc/hosts";

  # The color palette that will be used for generated themes
  colors = with colorstool; {
    primary = fromhex "#7dcc30";
    secondary = fromhex "#ffdc72";
    tertiary = fromhex "#aade71";
    highlight = fromhex "#43c904";
    active = fromhex "#E7E7E7";
    inactive = fromhex "#878787";
  };

  # Add packages to the shell
  packages = with pkgs; [
    feroxbuster
    gobuster
    wfuzz
    nmap
    exploitdb
    inetutils
    cewl
    p7zip
    binwalk
    hashcat
    bruteforce-luks
    zip

    (python310.withPackages (p: with p; [
      requests
      pypykatz
    ]))

    openssl.bin
  ];

  env_vars = {
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    CMAKE="${pkgs.cmake}/bin/cmake";
    GLIBC_STATIC = "${pkgs.glibc.static}";
  };

  # Custom aliases / scripts that are set for this shell
  shell.scripts = with colorstool; {
    compile_static = ''
      gcc -static -L${pkgs.glibc.static}/lib $@
    '';
    importvm = ''
      if [ $# -ne 1 ]; then
        echo "Usage: importvm <name>"
        return 1;
      fi
      VBoxManage import "${vm_dir}/$1.ova" --vsys 0 --basefolder "$HOME/.vbox-disks" --vmname="$1" --cpus=$(nproc) && \
      VBoxManage modifyvm $1 --nic1 hostonly --host-only-adapter1=vboxnet0
    '';

    startvm = ''
      if [ $# -ne 1 ]; then
        echo "Usage: startvm <name>"
        return 1;
      fi
      if ! VBoxManage list vms |grep "\"$1\"" 1>/dev/null 2>/dev/null; then
        echo "VM $1 not found"
        echo "Available VMs:"
        VBoxManage list vms
        return 1;
      fi
      echo "Starting VM $1"
      VBoxHeadless -s $1
    '';

    stopvm = ''
      if [ $# -ne 1 ]; then
        echo "Usage: stopvm <name>"
        return 1;
      fi
      if ! VBoxManage list vms |grep "\"$1\"" 1>/dev/null 2>/dev/null; then
        echo "VM $1 not found"
        echo "Available VMs:"
        VBoxManage list vms
        return 1;
      fi
      echo "Stopping VM $1"
      VBoxManage controlvm "$1" poweroff
    '';

    purgevm = ''
      if [ $# -ne 1 ]; then
        echo "Usage: purgevm <name>"
        return 1;
      fi
      if ! VBoxManage list vms |grep "\"$1\"" 1>/dev/null 2>/dev/null; then
        echo "VM $1 not found"
        echo "Available VMs:"
        VBoxManage list vms
        return 1;
      fi
      echo "Purging VM $1"
      VBoxManage unregistervm "$1" --delete-all
    '';

    readnotes = ''
      touch $HOME/.notes
      tail +1f $HOME/.notes
    '';

    note = ''
      echo -e "$@\n" >> $HOME/.notes
      echo -e "${style.bold}${ansi colors.primary}Saved${reset}"
    '';

    discover_targets = ''
      if [ $# -ne 1 ]; then
        echo "Usage: $0 <network>"
        return 1;
      fi
      nmap -sP $1
    '';

    scan = ''
      if [ $# -ne 1 ]; then
        echo "Usage: $0 <target>"
        return 1;
      fi
      sudo nmap -sSCV -p- --open --min-rate 4000 -v -n -Pn -oN nmapScan "$1"
    '';

    enumw = let
      all_exts = builtins.concatStringsSep "," [
        "txt" "jpg" "png" "zip" "html" "php" "css" "pdf"
      ];
    in ''
      if [ $# -ne 1 ]; then
        echo "Usage: $0 <url> [any other param to feroxbuster]"
        return 1;
      fi
      TARGET=$1
      shift 1

      FNAME=''${TARGET// /_}
      FNAME=''${FNAME//[^a-zA-Z0-9_]/}
      FNAME=`echo -n $FNAME | tr A-Z a-z`

      feroxbuster \
        -u "$TARGET" \
        -x ${all_exts} \
        --auto-tune \
        --thorough \
        -o "/tmp/enumw_$FNAME" \
        -C 404 -r \
        -w ~/.seclists/Discovery/Web-Content/directory-list-2.3-big.txt \
        $@ 
      echo -e "\n\n[*] $1\n" >> ./enumw
      cat "/tmp/enumw_$FNAME" >> ./enumw
    '';

    vhostenum = ''
      if [ $# -ne 1 ]; then
        echo "Usage: $0 <domain>"
        return 1;
      fi
      gobuster vhost \
        --append-domain \
        -u "$1" \
        -w ~/.seclists/Discovery/DNS/subdomains-top1million-110000.txt
        -o "/tmp/gobuster_vhost_tmp_out_$1"
      echo -e "\n\n[*] $1\n" >> ./vhost_enum
      cat "/tmp/gobuster_vhost_tmp_out_$1" >> ./vhost_enum
    '';

    archive = ''
      if [ $# -lt 2 ]; then
        echo "Usage: $0 <name> [paths]"
        return 1;
      fi

      mkdir -p $HOME/.archives
      NAME=$1
      shift 1;
      tar -cf $HOME/.archives/$NAME.tar.gz $@ && echo "Archive OK"
    '';

    start_socks = ''
      if [ $# -ne 1 ]; then
        echo "Usage: $0 <port>"
        return 1;
      fi
       ssh -i /host/home/john/.ssh/id_rsa -D "$1" -C -N john@localhost
    '';

    addhost = ''
      if [ $# -ne 2 ]; then
        echo "Usage: $0 <IP> <hostname>"
        return 1;
      fi

      echo "$1 $2" >> $HOME/.add_hosts
      echo "$1 $2" | sudo tee -a /etc/hosts
    '';
  };

  # The custom PS1 to be used
  shell.ps1 = with colorstool; ps1tool.mkPs1 [
    { style=style.bold; color=colors.highlight; text="󱎶 "; }
    { style=style.italic; color=colors.secondary; text="\\w"; }
    (ps1tool.mkGitPs1 { style=style.italic; color = colors.primary; left = "󰊢 "; right = ""; })
    # { style=style.bold; color=colors.highlight; text=""; }
  ];

  # Some code executed each time we fire up the shell environment
  initScript = ''
    mkdir -p ${vm_dir}/

    touch $HOME/.add_hosts
    echo "Adding additionnal hosts to /etc/hosts"
    cat $HOME/.add_hosts | sudo tee -a /etc/hosts
  '';

  exitScript = ''
    sudo rm /etc/hosts
  '';

  # Spawning a custom tmux when creating the shell
  tmux = {
    enable = true;
    configs_files = [
      ../data/tmux.conf
    ];

    theme_overwrite = vars: {
      "window-status-current-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=greencolor; add="nobold,noitalics"; }
        { txt = "󰱨"; fg=greencolor; add="bold"; }
        { txt = " #I"; fg=greencolor; add="nobold"; }
      ];
      "window-status-format" = tmuxtool.tmuxfmts [
        { txt = " "; bg = "default"; fg=redcolor; add="nobold,noitalics"; }
        { txt = "󰱩"; fg=redcolor; add="bold"; }
        { txt = " #I"; fg=redcolor; add="nobold"; }
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
