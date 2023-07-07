# Use a Crabcan-like "container"

Do not use bubblewrap as a sandbox

Get a "container" implementation, which will basically be a wrapper around chroot,
mount everything needed in the built system (in order to work with NixOS)

Isolate the processes, but do not map the UID / GID

Bridge networking interfaces
