{ username, ... }:

{
  imports = [
    ./packages/base.nix

    ./programs/git.nix
    ./programs/zsh.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.05"; # Add this line to set the state version
  };
}
