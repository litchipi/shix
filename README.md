# Shix

Create a fully custom, nix-enhanced, tailored workspaces.

## Usage

```
shix init
```
Prepares a directory in `$HOME/.shix` which can be pushed to a remote git
(to store your shells on your repo).

```
shix edit <name>
```
Edit the shell `<name>`, and commit the changes into the directory (to always keep the repo clean)
> If the git remote `shixremote` is set, will also push automatically to it

```
shix <name>
```
Starts the shell `<name>`

```
shix remote <url> <name>
```
Uses the remote shells stored at `<url>` (github or private git repo), to start the shell `<name>`
> Note: The url has to be formatted in a way that `nix` can use it, like "github:", "git+ssh:", etc ...

## Shell composition, usage in projects

You can setup a shix devshell inside your project that can be "composed" with some more personnal settings
In the flake of the project, add:
``` nix
outputs: let
   pkgs = import inputs.nixpkgs {
      system = <system>;
      overlays = [ inputs.shix.overlays.default ];
   };
in {
   apps.<system>.<appname> = pkgs.lib.shix.mkShixCompose ./shix.nix;
};
```
And setup the common shell configuration inside the `shix.nix` file (or whatever name you chose)

Then you can do `nix run .#<appname> $HOME/my_perso_shix.nix`, and the tool will merge the common configuration and custom one, then start the shell.

It allows then to set up in the common configuration things like:
- Fetch project dev dependencies and build tools
- Setup help scripts and misc automation

And at the same time allow any individual developper to set up his environment:
- Fancy PS1 and theming
- Directory configuration
- Overwrite any config he doesn't like on the common config

## Want to try it out ?

```
nix run github:litchipi/shix#shix -- remote github:litchipi/shix example
```
To test it without installing the tool, or the shells

## Required dependencies

- `git`
- `nix` with enabled flakes and nix-commands.

## Installation

For non-NixOS users:

```
nix run github:litchipi/shix -- install
```

For NixOS users, a module is defined, simply import `shix.nixosModules.<system>.default`

## Creating a shell

Locally, you can create a shell inside the `./shells/` directory, and run
`nix run .#<name>` to fire it up.

Take a look at [the example](./shells/example.nix), used as a template for new shells,
for a fully working example.

## How it works ?

When a shell is started, this is what happends:

- Sets a different $HOME for the shell
- Merges `bashrc` with shell-specific instructions into a custom bashrc
- Adds packages to be used inside this shell only
- Set up scripts, create symlinks, and set up a very specific work environment
without having to adapt the global system around it.
- Can execute a custom command at startup

## Tools for development

Some of the utilities used for this tool are located in `tools/`, including:

- Tmux configuration utility (in `./tools/tmux.nix`)
- Bash utility (in `./tools/bash.nix`)
- Terminal colors utility (in `./tools/colors.nix`)
- PS1 definition utility (in `./tools/ps1.nix`)

The code used to generate the shell can be read in `./tools/generate_shell.nix`.

## Storing private data inside a public repository

If you have to store some personnal data in the shell repo to use with `nix`,
this repo is already ready to work with `git-crypt`, and will encrypt any file
inside the `data` folder.
