# home-manager configuration for the primary user
{
  pkgs,
  lib,
  local,
  username,
  configRepoPath,
  ...
}:
let
  # Both keys are optional: an unset one is simply omitted from ~/.gitconfig so
  # git keeps falling back to its own global/per-repo value.
  gitUser =
    lib.optionalAttrs (local.gitUserName != null) { name = local.gitUserName; }
    // lib.optionalAttrs (local.gitUserEmail != null) { email = local.gitUserEmail; };

  # Guardrail: lists any machine-local value that is about to fall back to a
  # built-in default and asks before the rebuild applies it. Nix evaluation
  # cannot prompt, so this has to run as a separate step beforehand.
  preflightLocalConfig = pkgs.writeShellApplication {
    name = "preflight-local-config";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ../scripts/preflight-local-config.sh;
  };
in
{
  imports = [
    ./karabiner.nix
    ./input-sources.nix
  ];

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
    # Identity comes from ~/.config/macbook-configs/local.nix (gitUserName /
    # gitUserEmail) so it is never committed here.
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.autocrlf = "input";
    }
    // lib.optionalAttrs (gitUser != { }) { user = gitUser; };
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
      # Update the repo (preserving local changes), check for machine-local
      # values that would silently fall back to a default, then rebuild.
      #
      # The preflight runs before sudo so it can prompt on your terminal.
      #
      # --impure: machine-specific values are read from a file outside the
      # flake source (see lib/local-config.nix). MACBOOK_CONFIGS_LOCAL is passed
      # explicitly because sudo may reset HOME to /var/root before nix evaluates.
      darwin-switch = "git -C ${configRepoPath} pull --autostash && preflight-local-config ${configRepoPath} && sudo MACBOOK_CONFIGS_LOCAL=\"$HOME/.config/macbook-configs/local.nix\" darwin-rebuild switch --impure --flake ${configRepoPath}";
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

        # Remote SSH – use ssh-noshell to suppress RemoteCommand (screen -dR)
        # so VSCode's -T connection isn't killed by screen requiring a terminal.
        "remote.SSH.path" = "/etc/profiles/per-user/${username}/bin/ssh-noshell";

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
  # Tinyproxy – lightweight HTTP/HTTPS proxy
  # Runs as a user launchd agent; accessible at http://127.0.0.1:8787
  # ---------------------------------------------------------------------------
  launchd.agents.tinyproxy =
    let
      settings = {
        Port = local.tinyproxyPort;
        LogLevel = "Connect";
        # Multiple Allow entries – rendered as repeated "Allow <value>" lines.
        # Tinyproxy uses CIDR notation for subnets, not shell-style wildcards.
        # The private subnet is site-specific and comes from local.nix.
        Allow = [
          "127.0.0.1"
          "::1"
        ]
        ++ lib.optional (local.trustedSubnet != null) local.trustedSubnet;
      };
      conf = pkgs.writeText "tinyproxy.conf" (
        lib.concatStringsSep "\n" (
          lib.flatten (
            lib.mapAttrsToList (
              key: value:
              if lib.isList value
              then map (v: "${key} ${toString v}") value
              else [ "${key} ${toString value}" ]
            ) settings
          )
        )
      );
    in
    {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.tinyproxy}/bin/tinyproxy"
          "-d"
          "-c"
          "${conf}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/tinyproxy.log";
        StandardErrorPath = "/tmp/tinyproxy.log";
      };
    };

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

    # The dev host's name/user/ports come from local.nix. Its IP (HostName) is
    # kept out of git too: it lives in an agenix-encrypted file decrypted to
    # ~/.ssh/<devSshHost>.conf at activation (see age.secrets in system.nix).
    extraConfig = ''
      Host ${local.devSshHost}
        User ${local.devSshUser}
        ServerAliveInterval 60
        RequestTTY yes
        RemoteCommand screen -dR
        RemoteForward ${toString local.devRemoteForward} 127.0.0.1:${toString local.tinyproxyPort}
        Include ~/.ssh/${local.devSshHost}.conf
    ''
    # Hosts on the private subnet are re-imaged often, so their host keys
    # change; skip the checks for them. Site-specific, hence local.nix.
    + lib.optionalString (local.trustedHostGlob != null) ''

      Host ${local.trustedHostGlob}
        User ${local.trustedHostUser}
        StrictHostKeyChecking no
        ServerAliveInterval 60
        UserKnownHostsFile /dev/null
    '';
  };

  # ---------------------------------------------------------------------------
  # .NET – required for the `pac` (Power Platform CLI) dotnet global tool
  # ---------------------------------------------------------------------------
  home.sessionPath = [ "$HOME/.dotnet/tools" ];

  # DOTNET_ROOT tells dotnet global tools (like pac) where the Nix-managed
  # runtime lives, since Nix doesn't register it at the standard system paths.
  home.sessionVariables.DOTNET_ROOT = "${pkgs.dotnet-sdk_10}/share/dotnet";

  home.activation.installPacCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.dotnet/tools/pac" ]; then
      $DRY_RUN_CMD ${pkgs.dotnet-sdk_10}/bin/dotnet tool install --global Microsoft.PowerApps.CLI.Tool
    fi
  '';

  # ---------------------------------------------------------------------------
  # Additional user packages
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    # Guardrail used by the `darwin-switch` alias (and runnable on its own).
    preflightLocalConfig

    # ssh-noshell – suppresses any RemoteCommand directive set in ~/.ssh/config
    (writeShellScriptBin "ssh-noshell" ''
      exec /usr/bin/ssh -o RemoteCommand=none "$@"
    '')
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

    # .NET SDK – needed to install the `pac` Power Platform CLI global tool
    dotnet-sdk_10
  ];
}
