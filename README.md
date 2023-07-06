# Shix

Create a fully custom, nix-enhanced, tailored workspaces, sandboxed using `bubblewrap`.

## Non-NixOS usage

You can clone this repo anywhere in your filesystem, copy the `example` shell in the `shells/` directory
to create your very own shell.

Then, start it up using `nix run /path/to/your/repo#<shell name>`.

Note that as it uses flakes, you can run a shell stored in a remote git repository like so: `nix run <url to repo>#<shell name>`

## NixOS usage

You can install a handy `shix` by importing the NixOS module.

It will export the configuration options:

``` nix
shix = {
   remoteRepoUrl = "url to remote repo where your shells are stored";
   pullBeforeEditing = true; # Every time we edit a shell, pull from remote repo before
   pushAfterEditing = true; # Every time we edit a shell, push to remote repo
   baseDir = "path to shix dir on filesystem";
   shellEditCommand = "neovim";
};
```

Then you'll be able to use the command `shix` to use the shells:
```
shix init    # Clones the remote repo into the folder
shix edit <name>    # Edit the shell <name> / create it
shix <name>    # Starts the shell <name>
shix remote <url> <name>   # Starts a remote shell <name> from repository at URL <url>
```

> Note: The url has to be formatted in a way that `nix` can use it, like "github:", "git+ssh:", etc ...

## Overlay

If you want to create a shell in another project, you can import the overlay.
It will provide the function `lib.shix.mkShell` that takes a shell file as an argument,
and will output a derivation for a shell script starting the environment.

## Required dependencies

- `git`
- `nix` with enabled flakes and nix-commands.

## Tools for development

Some of the utilities used for this tool are located in `tools/`, including:

- Tmux configuration utility (in `./tools/tmux.nix`)
- Bash utility (in `./tools/bash.nix`)
- Terminal colors utility (in `./tools/colors.nix`)
- PS1 definition utility (in `./tools/ps1.nix`)

The code used to generate the shell can be read in `./tools/generate_shell.nix`.

The sandbox is created using `bubblewrap`, you can see its usage in `./tools/bwrap.nix`.

## Known limitations

Because of [This issue](https://github.com/NixOS/nixpkgs/issues/42117), the environment inside
`bubblewrap` won't be able to execute files with SUID bit set.

For example, that means that `sudo` is not possible, at least until
[this PR](https://github.com/NixOS/nixpkgs/pull/231673) lands.
