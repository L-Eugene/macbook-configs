# home-manager integration settings
{ username, configRepoPath, nix-vscode-extensions, agenix, system, ... }:

let
  specialArgs = {
    inherit username configRepoPath nix-vscode-extensions agenix system;
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
