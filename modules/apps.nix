# System-level packages installed into /run/current-system/sw
{
  pkgs,
  agenix,
  system,
  ...
}:

{
  environment.systemPackages =
    (with pkgs; [
      # ---------------------------------------------------------------------------
      # Core utilities
      # ---------------------------------------------------------------------------
      curl
      wget
      git
      gnupg

      # ---------------------------------------------------------------------------
      # Shell & terminal utilities
      # ---------------------------------------------------------------------------
      starship # Cross-shell prompt
      direnv # Per-directory environment variables

      # ---------------------------------------------------------------------------
      # File & text utilities
      # ---------------------------------------------------------------------------
      ripgrep # Fast grep replacement
      fd # Fast find replacement
      bat # Better cat
      eza # Better ls
      fzf # Fuzzy finder
      jq # JSON processor
      yq-go # YAML/JSON/TOML processor

      # ---------------------------------------------------------------------------
      # Development tools
      # ---------------------------------------------------------------------------
      nixfmt # Nix code formatter
      nil # Nix language server (LSP)
      shellcheck # Shell script linter
      pre-commit # Git hook framework

      # ---------------------------------------------------------------------------
      # Networking utilities
      # ---------------------------------------------------------------------------
      openssh
      nmap

      # ---------------------------------------------------------------------------
      # macOS-specific helpers
      # ---------------------------------------------------------------------------
      defaultbrowser # CLI tool to set the default browser
      mas # Mac App Store CLI
    ])
    ++ [
      # agenix CLI – manage encrypted secrets
      agenix.packages.${system}.agenix
    ];

  # ---------------------------------------------------------------------------
  # System fonts
  # ---------------------------------------------------------------------------
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];
}
