# home-manager integration settings
{ username, nix-vscode-extensions, agenix, system, ... }:

let
  specialArgs = {
    inherit username nix-vscode-extensions agenix system;
  };
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      {
        nixpkgs.config.allowUnfree = true;
      }
    ];
    extraSpecialArgs = specialArgs;
    users.${username} = import ../home/default.nix;
  };
}
