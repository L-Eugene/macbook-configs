# home-manager integration settings
{ local, username, configRepoPath, nix-vscode-extensions, agenix, system, ... }:

let
  specialArgs = {
    inherit local username configRepoPath nix-vscode-extensions agenix system;
  };
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
    users.${username} = import ../home/default.nix;
  };
}
