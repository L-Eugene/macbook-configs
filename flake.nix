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
      # Machine-specific values are NOT stored in this repository. They are read
      # from ~/.config/macbook-configs/local.nix (see local.nix.example for a
      # template); anything that file does not set falls back to the defaults in
      # lib/local-config.nix.
      #
      # Because that file lives outside the flake source, evaluation must be
      # impure:
      #
      #   darwin-rebuild switch --impure --flake .#$(hostname -s)
      # -----------------------------------------------------------------------
      localConfig = import ./lib/local-config.nix {
        lib = nixpkgs.lib;
        # Resolves against the copied flake source. Present only when the flake
        # was referenced as `path:` — the git fetcher omits gitignored files.
        sourceFile = ./local.nix;
      };

      local = localConfig.config;

      inherit (local)
        system
        username
        hostname
        configRepoPath
        ;

      pkgs = nixpkgs.legacyPackages.${system};

      specialArgs = {
        inherit
          local
          username
          hostname
          configRepoPath
          nix-vscode-extensions
          agenix
          system
          ;
      };
    in
    {
      # Primary Darwin configuration – apply with:
      #   darwin-rebuild switch --flake path:<repo>#${hostname}
      #
      # If local.nix cannot be found, every value would silently be a
      # placeholder and asking for the real host reports a baffling "flake does
      # not provide attribute". Fail with the actual reason instead. Only this
      # output is gated: the formatter, packages and localConfigReport keep
      # working so the problem can still be diagnosed.
      darwinConfigurations =
        if localConfig.notFound then
          throw ''
            local.nix could not be found, so every machine-specific value would
            fall back to a placeholder — building a configuration for the wrong
            user and hostname.

            Most likely this flake was referenced as a plain path. local.nix is
            .gitignore'd, and a flake in a git repository only sees git-TRACKED
            files, so it is invisible that way. Use the `path:` fetcher, which
            copies the directory as-is:

                darwin-rebuild switch --flake path:<repo>#<hostname>
                nix build path:<repo>#darwinConfigurations.<hostname>.system

            If local.nix simply does not exist yet, create it from the template:

                cp <repo>/local.nix.example <repo>/local.nix

            A copy outside the repo (~/.config/macbook-configs/local.nix or
            $MACBOOK_CONFIGS_LOCAL) is also honoured, but only with --impure.
            The `darwin-switch` alias uses that route.
          ''
        else
          {
            ${hostname} = nix-darwin.lib.darwinSystem {
              inherit system specialArgs;
              modules = [
                ./modules/config_host.nix
                ./modules/system.nix
                ./modules/apps.nix
                ./modules/homebrew.nix
                ./modules/auto-update.nix

                # Agenix system module (secrets decrypted at activation)
                agenix.darwinModules.default

                # home-manager integration
                home-manager.darwinModules.home-manager
                ./modules/config_home-manager.nix
              ];
            };
          };

      # Which machine-local values are set, and which would fall back to a
      # default. Queried by the preflight guardrail (scripts/preflight-local-config.sh)
      # so it can list the fallbacks and ask before a rebuild applies them:
      #   nix eval --impure --json .#localConfigReport
      # Note this still cannot be read while MACBOOK_CONFIGS_STRICT is set:
      # darwinConfigurations is keyed by the hostname from the merged config,
      # which throws under strict, and that breaks the whole output set. The
      # preflight therefore clears that variable for its query.
      localConfigReport = {
        inherit (localConfig) source missing;
        missingNames = builtins.attrNames localConfig.missing;
      };

      # Expose the agenix CLI so you can run `nix run .#agenix -- -e secret.age`
      packages.${system}.agenix = agenix.packages.${system}.agenix;

      # Convenience: `nix fmt` formats all Nix files with nixfmt
      formatter.${system} = pkgs.nixfmt;
    };
}
