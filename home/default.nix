# home-manager configuration for the primary user
{
  pkgs,
  username,
  configRepoPath,
  nix-vscode-extensions,
  system,
  ...
}:

let
  # All VSCode Marketplace extensions, pinned by nix-vscode-extensions
  marketplace = nix-vscode-extensions.extensions.${system}.vscode-marketplace;
in
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
      # Rebuild and switch the Darwin configuration
      darwin-switch = "sudo darwin-rebuild switch --flake ${configRepoPath}";
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
  # Visual Studio Code – app installed via Homebrew Cask, settings via Nix.
  # ---------------------------------------------------------------------------
  programs.vscode =
    let
      # Overrides the default pkgs.vscode (unfree) with a stub pointing to the
      # Homebrew-installed binary; home-manager still writes settings.json.
      vscodeStub = pkgs.writeShellScriptBin "code" ''
        exec "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$@"
      '';
    in
    {
      enable = true;
      package = vscodeStub;

      # Extensions are managed manually via the UI; declaring any here causes
      # home-manager to write .extensions-immutable.json which fails when VSCode
      # is installed by Homebrew and owns the extensions directory.
      mutableExtensionsDir = true;

      profiles.default = {

        userSettings = {
          # Editor
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', Menlo, Monaco, 'Courier New', monospace";
          "editor.fontSize" = 14;
          "editor.lineHeight" = 1.5;
          "editor.formatOnSave" = true;
          "editor.formatOnPaste" = false;
          "editor.rulers" = [
            80
            120
          ];
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

          # Security – trust workspaces you explicitly open
          "security.workspace.trust.enabled" = true;
          "security.workspace.trust.untrustedFiles" = "prompt";

          # Nix
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nil";
        };
      };
    };

  # ---------------------------------------------------------------------------
  # Syncthing – user-level continuous file synchronisation
  # The launchd agent is enabled by home-manager on macOS.
  # Web UI: http://127.0.0.1:8384
  # ---------------------------------------------------------------------------
  services.syncthing.enable = true;

  # ---------------------------------------------------------------------------
  # SSH client
  # ---------------------------------------------------------------------------
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
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
  ];
}
