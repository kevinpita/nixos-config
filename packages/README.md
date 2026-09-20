# Local packages

This folder contains Nix package definitions for tools that need local source or packaging. Change it when an executable, its dependencies, or its build needs to change. Host selection, service settings, and desktop integration belong in `modules/`, not in the package definition.

## What belongs here

A local package can contain source, or just a `package.nix` that fetches upstream source. Do not copy upstream code into this folder merely to change its version. Keep runtime dependencies in the package definition so the tool does not depend on an interactive shell setup.

## Adding or changing a package

Give a new helper its own directory and a `package.nix`. Add an output in `modules/packages.nix` if it should be built directly through the flake. The consuming feature module must separately install or call it. A package output alone does not put the tool on any host.

Change the package for executable behavior and build dependencies. Change its caller for when it runs, its permissions, or which machines use it. For fetched sources, review the version or revision and source hash together. Some Go packages also require a vendor hash update.

## Checking and using changes

From the repository root, build one output with `nix build .#<package-name>`. This does not activate a system configuration. `just switch` deploys changes to the current host if its selected features use the package.

Use each package's tests where available. A successful build does not prove that service integration works. Check the consuming feature when changing runtime behavior.
