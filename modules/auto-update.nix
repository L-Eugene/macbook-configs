# Unattended weekly updates for Homebrew-managed applications.
#
# `homebrew.onActivation.upgrade` only upgrades apps when you manually run
# `darwin-rebuild switch`. This module puts the same upgrade on a schedule: a
# LaunchAgent runs `brew update` + `brew bundle install` against the very same
# Brewfile that nix-darwin generates from modules/homebrew.nix, so the declared
# package set stays the single source of truth.
#
# Runs as the user (Homebrew must never run as root) and never removes anything
# — `zap` cleanup stays reserved for explicit activations.
{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  # The exact Brewfile nix-darwin builds from `homebrew.{taps,brews,casks,masApps}`.
  brewfile = pkgs.writeText "Brewfile" config.homebrew.brewfile;

  logFile = "/Users/${username}/Library/Logs/homebrew-auto-update.log";

  # Casks excluded from every unattended `brew bundle` run — both the weekly
  # agent below and `darwin-rebuild switch`. They stay declared in
  # modules/homebrew.nix, so `cleanup = "zap"` still keeps them installed:
  # `brew bundle cleanup` builds its keep-list from the Brewfile itself and
  # never consults this skip list.
  #
  # tunnelblick: its cask chowns /Applications/Tunnelblick.app to root:wheel
  #   for the privileged OpenVPN helper. macOS App Management (TCC) blocks
  #   that "even when using sudo", and a launchd job has no way to be granted
  #   the permission — verified: the agent fails identically to a terminal.
  #   One failing cask fails the whole `brew bundle` invocation, so skip it and
  #   let Tunnelblick's own updater (which requests admin rights properly) do
  #   the job. To upgrade it via Homebrew, grant your terminal App Management
  #   under System Settings → Privacy & Security, then run
  #   `brew upgrade --cask tunnelblick`.
  unattendedCaskSkip = [ "tunnelblick" ];

  caskSkipEnv = lib.concatStringsSep " " unattendedCaskSkip;

  updateScript = ''
    export HOMEBREW_NO_ENV_HINTS=1
    export HOMEBREW_BUNDLE_CASK_SKIP=${lib.escapeShellArg caskSkipEnv}
    # `brew update` runs explicitly below; skip Homebrew's implicit auto-update.
    export HOMEBREW_NO_AUTO_UPDATE=1

    # Trim the log in place (launchd holds the fd open, so no mv/rotate).
    if [ -f ${lib.escapeShellArg logFile} ] \
      && [ "$(/usr/bin/stat -f%z ${lib.escapeShellArg logFile})" -gt 1048576 ]; then
      trimmed=$(tail -n 500 ${lib.escapeShellArg logFile})
      printf '%s\n' "$trimmed" > ${lib.escapeShellArg logFile}
    fi

    echo "=== $(date '+%Y-%m-%d %H:%M:%S') Homebrew auto-update ==="

    if ! brew update; then
      echo "brew update failed (offline?) – skipping this run."
      exit 0
    fi

    # Installs anything missing and upgrades everything declared, including
    # self-updating casks (see homebrew.greedyCasks below). Skipped casks are
    # reported as "Skipping <name>" in the log.
    brew bundle install --file=${brewfile} || echo "brew bundle reported failures (see above)."

    brew cleanup --prune=30 || true

    echo "=== $(date '+%Y-%m-%d %H:%M:%S') done ==="
  '';
in
{
  # Upgrade casks even when they ship their own updater (Firefox, VSCode,
  # Docker Desktop …). Without this, `brew bundle` skips them and they only
  # update when you happen to launch the app.
  homebrew.greedyCasks = true;

  # Apply the same exclusions to the `brew bundle` run during
  # `darwin-rebuild switch`; otherwise a cask that cannot be upgraded
  # unattended fails activation.
  homebrew.onActivation.extraEnv.HOMEBREW_BUNDLE_CASK_SKIP = caskSkipEnv;

  launchd.user.agents.homebrew-auto-update = {
    # brew needs git (taps) and mas (Mac App Store apps) on PATH.
    path = [
      "${config.homebrew.prefix}/bin"
      "${pkgs.mas}/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ];

    script = updateScript;

    serviceConfig = {
      # Mondays at 09:00. If the Mac is asleep, launchd runs the job on wake.
      StartCalendarInterval = [
        {
          Weekday = 1;
          Hour = 9;
          Minute = 0;
        }
      ];
      RunAtLoad = false;

      # Stay out of the way of interactive work.
      ProcessType = "Background";
      LowPriorityIO = true;
      Nice = 5;

      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
