# home-manager configuration for the primary user
{
  pkgs,
  lib,
  username,
  configRepoPath,
  ...
}:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager state version – do NOT change after initial setup
  home.stateVersion = "24.11";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # ---------------------------------------------------------------------------
  # Git
  # ---------------------------------------------------------------------------
  programs.git = {
    enable = true;
    # Fill in your identity; or override per-repo with git config
    # settings.user.name = "Your Name";
    # settings.user.email = "you@example.com";
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
    };
    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv"
    ];
  };

  # ---------------------------------------------------------------------------
  # Zsh
  # ---------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --group-directories-first";
      cat = "bat";
      grep = "rg";
      find = "fd";
      # Update the repo (preserving local changes) then rebuild and switch.
      darwin-switch = "git -C ${configRepoPath} pull --autostash && sudo darwin-rebuild switch --flake ${configRepoPath}";
    };

    initContent = ''
      # Starship prompt
      eval "$(starship init zsh)"
      # direnv hook
      eval "$(direnv hook zsh)"
    '';
  };

  # ---------------------------------------------------------------------------
  # Starship prompt
  # ---------------------------------------------------------------------------
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
      nix_shell.symbol = "❄️ ";
    };
  };

  # ---------------------------------------------------------------------------
  # direnv – automatically load .envrc files
  # ---------------------------------------------------------------------------
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Visual Studio Code – app installed via Homebrew Cask (see homebrew.nix).
  #
  # settings.json is a plain, writable file (not a Nix symlink) so VSCode and
  # the user can keep editing it. On each activation the keys declared below
  # are merged in via jq; any other keys already present are preserved.
  # ---------------------------------------------------------------------------
  home.activation.vscodeSettings =
    let
      managedSettings = (pkgs.formats.json { }).generate "vscode-settings.json" {
        # Editor
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', Menlo, Monaco, 'Courier New', monospace";
        "editor.fontSize" = 14;
        "editor.lineHeight" = 1.5;
        "editor.formatOnSave" = true;
        "editor.formatOnPaste" = false;
        "editor.rulers" = [ 80 120 ];
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "boundary";
        "editor.tabSize" = 2;
        "editor.bracketPairColorization.enabled" = true;
        "editor.guides.bracketPairs" = "active";

        # Workbench
        "workbench.startupEditor" = "none";
        "workbench.colorTheme" = "Default Dark Modern";

        # Files
        "files.autoSave" = "onFocusChange";
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;

        # Terminal
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font Mono'";
        "terminal.integrated.fontSize" = 13;

        # Git
        "git.autofetch" = true;
        "git.confirmSync" = false;

        # Security
        "security.workspace.trust.enabled" = true;
        "security.workspace.trust.untrustedFiles" = "prompt";

        # Nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
      };
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settingsDir="$HOME/Library/Application Support/Code/User"
      settingsPath="$settingsDir/settings.json"
      $DRY_RUN_CMD mkdir -p "$settingsDir"

      tmpFile="$(mktemp)"
      if [ -s "$settingsPath" ]; then
        # Deep-merge: our managed keys win, everything else is kept.
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$settingsPath" ${managedSettings} > "$tmpFile"
      else
        cp ${managedSettings} "$tmpFile"
      fi
      $DRY_RUN_CMD install -m 0644 "$tmpFile" "$settingsPath"
      rm -f "$tmpFile"
    '';

  # ---------------------------------------------------------------------------
  # Syncthing – user-level continuous file synchronisation
  # The launchd agent is enabled by home-manager on macOS.
  # Web UI: http://127.0.0.1:8384
  # ---------------------------------------------------------------------------
  services.syncthing.enable = true;

  # ---------------------------------------------------------------------------
  # ssh-noshell wrapper – calls ssh with RemoteCommand= to suppress any
  # RemoteCommand directive set in ~/.ssh/config.
  # ---------------------------------------------------------------------------
  home.activation.sshNoshell =
    let
      wrapper = pkgs.writeShellScript "ssh-noshell" ''
        exec /usr/bin/ssh -o RemoteCommand= "$@"
      '';
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ln -sf ${wrapper} /usr/local/bin/ssh-noshell
    '';

  # ---------------------------------------------------------------------------
  # SSH client
  # ---------------------------------------------------------------------------
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      AddKeysToAgent = "yes";
      # UseKeychain is Apple-only. IgnoreUnknown makes non-Apple ssh skip it
      # instead of aborting with "Bad configuration option: usekeychain".
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
    };

    # Host `dev`. The IP (HostName) is kept out of git: it lives in an
    # agenix-encrypted file decrypted to ~/.ssh/dev.conf at activation
    # (see age.secrets."ssh-dev" in modules/system.nix).
    extraConfig = ''
      Host dev
        User dev
        ServerAliveInterval 60
        RequestTTY yes
        RemoteCommand screen -dR
        Include ~/.ssh/dev.conf

      Host 172.19.*
        User admin
        StrictHostKeyChecking no
        ServerAliveInterval 60
        UserKnownHostsFile /dev/null
    '';
  };

  # ---------------------------------------------------------------------------
  # Additional user packages
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    # Archive tools
    zip
    unzip
    p7zip

    # Network diagnostics
    whois
    dnsutils # provides dig, nslookup, etc.

    # Process & system inspection
    htop
    btop

    # AI assistant CLI
    claude-code
  ];
}
