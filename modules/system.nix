# macOS system-level configuration via nix-darwin
{
  lib,
  pkgs,
  username,
  ...
}:

{
  # Allow only explicitly-approved unfree packages.
  nixpkgs.config.allowUnfreePredicate = pkg:
    let
      name = lib.getName pkg;
    in
    name == "vscode" || lib.hasPrefix "vscode-extension-" name;

  # ---------------------------------------------------------------------------
  # macOS system defaults
  # ---------------------------------------------------------------------------

  system.defaults = {
    # Dock
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      show-recents = false;
      launchanim = false;
      mineffect = "scale";
      minimize-to-application = true;
      tilesize = 48;
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = false;
      FXDefaultSearchScope = "SCcf"; # Search current folder by default
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv"; # List view
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = false;
    };

    # Global NSGlobalDomain preferences
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false; # Enable key repeat
      AppleShowAllExtensions = true;
      "com.apple.swipescrolldirection" = false; # Disable natural scrolling
      InitialKeyRepeat = 15; # Delay before key repeat starts (lower = faster)
      KeyRepeat = 2; # Key repeat rate (lower = faster)
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };

    # Login window
    loginwindow = {
      GuestEnabled = false;
    };

    # Screen capture – save as PNG to ~/Desktop by default
    screencapture = {
      location = "~/Desktop";
      type = "png";
    };

    # Trackpad
    trackpad = {
      Clicking = true; # Tap-to-click
      TrackpadThreeFingerDrag = true;
    };

    # macOS software update
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
  };

  # ---------------------------------------------------------------------------
  # Security
  # ---------------------------------------------------------------------------

  # Enable Touch ID authentication for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # nix-darwin now applies user-scoped defaults for this account.
  system.primaryUser = username;

  # ---------------------------------------------------------------------------
  # Nix settings
  # ---------------------------------------------------------------------------

  nix = {
    settings = {
      # Enable flakes and the new `nix` CLI
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Trusted users – required for binary cache substituters
      trusted-users = [
        "root"
        "@admin"
        username
      ];

      # Public binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBo="
      ];
    };

    # Automatic garbage collection – runs weekly, keeps last 30 days
    gc = {
      automatic = true;
      interval = {
        Weekday = 7;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    # Keep build dependencies so `nix-store --query --requisites` works offline
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # ---------------------------------------------------------------------------
  # Shell & environment
  # ---------------------------------------------------------------------------

  programs.zsh.enable = true;

  environment.shells = [ pkgs.zsh ];

  # ---------------------------------------------------------------------------
  # System state version
  # Consult `man 5 darwin-configuration` before changing.
  # ---------------------------------------------------------------------------
  system.stateVersion = 5;
}
