# Build and activate the current host from this checkout.
switch:
  nh os switch "{{justfile_directory()}}"

# Build and select the configuration for the next boot without activating it now.
boot:
  nh os boot "{{justfile_directory()}}"

# Evaluate every host and run the flake checks with the real private inputs.
check:
  nix flake check "{{justfile_directory()}}"

# Compare the hand-made version pins with their upstream.
pins:
  "{{justfile_directory()}}/scripts/pins.sh"
