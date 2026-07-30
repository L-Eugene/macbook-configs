# Homebrew casks and brews
# nix-darwin's homebrew module manages the lifecycle of Homebrew itself as
# well as all formulae and casks declared here.
#
# IMPORTANT: Homebrew must already be installed before running `darwin-rebuild`.
# Install it with: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
{
  username,
  pkgs,
  lib,
  ...
}:

{
  homebrew = {
    enable = true;

    # Lifecycle management
    onActivation = {
      autoUpdate = true; # Run `brew update` on every activation
      upgrade = true; # Upgrade out-of-date casks/formulae
      # "zap" removes any installed cask/formula NOT listed here.
      # Use "uninstall" if you want softer cleanup (keeps manually-installed packages).
      cleanup = "zap";
    };

    # Additional Homebrew taps
    taps = [ ];

    # Homebrew formulae (CLI packages)
    brews = [ ];

    # Homebrew Casks (GUI applications)
    casks = [
      # Web browser – set as default browser via activation script below
      "firefox"

      # Password manager (KeePassXC is the actively-maintained successor to KeePassX)
      "keepassxc"

      # Code editor – installed via cask to avoid nixpkgs unfree restrictions
      "visual-studio-code"
    ];

    # Mac App Store applications (requires prior App Store sign-in)
    # masApps = { "1Password" = 1333542190; };
    masApps = { };
  };

  # ---------------------------------------------------------------------------
  # Set Firefox as the default browser.
  #
  # Activation now runs as root in nix-darwin, so execute as the primary user.
  # defaultbrowser(1) shows a one-time system confirmation dialog on first run;
  # subsequent runs are silent.
  # ---------------------------------------------------------------------------
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Setting Firefox as the default browser…"
    sudo -u ${username} ${pkgs.defaultbrowser}/bin/defaultbrowser firefox \
      || echo "  defaultbrowser: dialog may be pending user approval."
  '';
}
