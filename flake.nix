{
  description = "MacBook configuration using nix-darwin and home-manager";

  inputs = {
    # Nixpkgs – use nixpkgs-unstable for up-to-date packages on macOS
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin – macOS system management
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home-manager – user-level configuration
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agenix – secrets management using age encryption + SSH keys
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-vscode-extensions – full VSCode Marketplace mirror for Nix
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      agenix,
      nix-vscode-extensions,
    }:
    let
      # -----------------------------------------------------------------------
      # Edit these values to match your machine before applying.
      # -----------------------------------------------------------------------

      # "aarch64-darwin" for Apple Silicon (M-series); "x86_64-darwin" for Intel.
      system = "aarch64-darwin";

      # Your macOS short username (the one shown by `whoami`).
      username = "changeme";

      # Machine hostname (System Preferences → Sharing → Computer Name).
      hostname = "macbook";

      # -----------------------------------------------------------------------

      pkgs = nixpkgs.legacyPackages.${system};

      specialArgs = {
        inherit
          username
          hostname
          nix-vscode-extensions
          agenix
          system
          ;
      };
    in
    {
      # Primary Darwin configuration – apply with:
      #   darwin-rebuild switch --flake .#${hostname}
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        inherit system specialArgs;
        modules = [
          ./modules/host.nix
          ./modules/system.nix
          ./modules/apps.nix
          ./modules/homebrew.nix

          # Agenix system module (secrets decrypted at activation)
          agenix.darwinModules.default

          # home-manager integration
          home-manager.darwinModules.home-manager
          ./modules/home-manager.nix
        ];
      };

      # Expose the agenix CLI so you can run `nix run .#agenix -- -e secret.age`
      packages.${system}.agenix = agenix.packages.${system}.agenix;

      # Convenience: `nix fmt` formats all Nix files with nixfmt
      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
