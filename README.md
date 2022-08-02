# Shix

Create fully custom, nix-enhanced, tailored workspaces.

The script will prepare a directory in `$HOME/.shix` which can be linked
to a remote git.  
It's made to always have a clean git repo between shell editions.

To set up your own shells, you can fork this repo and provide the URL during the
initialization phase.

> You can also manually edit the `shixremote` remote in the `$HOME/.shix` git repo

## Want to try it out ?

```
nix run github:litchipi/shix#shix -- remote github:litchipi/shix example
```

## Installation

Required dependencies: `git` and `nix` with enabled flakes and nix-commands.

For non-NixOS users:

```
nix run github:litchipi/shix -- install
```

For NixOS users, a module is defined, simply import `shix.nixosModules.<system>.default`

## Usage

```
shix init                # Setup the directory if needed
shix <name>              # Starts the shell <name> if it exists
shix edit <name>         # Opens the shell <name> in $EDITOR, create new if doesn't exist
shix remote <url> <name> # Opens the shell <name> defined in the flake located at <url>
```

Locally, you can create a shell inside the `./shells/` directory, and run
`nix run .#<name>` to fire it up.

Take a look at [the example](./shells/example.nix), used as a template for new shells,
for a fully working example.

It does the following:

- Sets a different $HOME for the shell
- Merges `bashrc` with shell-specific instructions into a custom bashrc
- Adds packages to be used inside this shell only
- Set up scripts, create symlinks, and set up a very specific work environment
without having to adapt the global system around it.
- Can start a custom command at startup

Some utilities are already defined and integrated, such as:

- Tmux configuration utility (in `./tools/tmux.nix`)
- Bash utility (in `./tools/bash.nix`)
- Terminal colors utility (in `./tools/colors.nix`)
- PS1 definition utility (in `./tools/ps1.nix`)

The code used to generate the shell can be read in `./tools/generate_shell.nix`.

## Storing personnal data

If you have to store some personnal data in the shell repo to use with `nix`,
this repo is already ready to work with `git-crypt`, and will encrypt any file
inside the `data` folder.
