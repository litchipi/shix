# Shix

Create fully custom, nix-enhanced, tailored workspaces.

You can create a shell inside the `./shells/` directory, and run `nix run .#<name>`
to fire it up.

Take a look at `./shells/example.nix` for a fully working example.

It does the following:

- Sets a different $HOME for the shell
- Merges `bashrc` with shell-specific instructions into a custom `.profile`
- Adds packages to be used inside this shell only
- Set up scripts, create symlinks, and set up a very specific work environment
without having to adapt the global system around it.
- Can start a custom command at startup

Some utilities are already defined, such as:

- Tmux configuration utility (in `./tools/tmux.nix`)
- Bash utility (in `./tools/bash.nix`)
- Terminal colors utility (in `./tools/colors.nix`)

The code used to generate the shell can be read in `./tools/generate_shell.nix`.
