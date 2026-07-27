# macbook-configs

A reproducible macOS configuration managed by [Nix](https://nixos.org/),
[nix-darwin](https://github.com/LnL7/nix-darwin), and
[home-manager](https://github.com/nix-community/home-manager).
Secrets are encrypted at rest using [agenix](https://github.com/ryantm/agenix).

---

## What this installs

| Software | How | Notes |
|---|---|---|
| **Firefox** | Homebrew Cask | Set as the default browser automatically |
| **Visual Studio Code** | nixpkgs | Extensions managed by Nix |
| ↳ GitHub Pull Requests & Issues | nix-vscode-extensions | |
| ↳ GitHub Codespaces | nix-vscode-extensions | |
| ↳ Dev Containers | nix-vscode-extensions | |
| ↳ Power Platform Tools (+ deps) | nix-vscode-extensions | |
| ↳ Remote - SSH | nixpkgs | |
| **Syncthing** | nixpkgs (launchd service) | Web UI on http://127.0.0.1:8384 |
| **KeePassXC** | Homebrew Cask | Actively-maintained successor to KeePassX |

> **Note on KeePassX vs KeePassXC:** KeePassX is no longer actively
> maintained. This configuration installs [KeePassXC](https://keepassxc.org/),
> its community-maintained fork, which is fully compatible with the `.kdbx`
> format and adds features such as browser integration, TOTP, and SSH-agent
> support.

---

## Prerequisites

1. **Xcode Command Line Tools**

   ```sh
   xcode-select --install
   ```

2. **Homebrew** – required before the first `darwin-rebuild`

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

   Follow the post-install instructions to add Homebrew to your `PATH`.

3. **Nix** – multi-user installation (recommended)

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

   Or use the official installer:

   ```sh
   sh <(curl -L https://nixos.org/nix/install)
   ```

   Restart your terminal after installation.

---

## First-time setup

### 1. Clone this repository

```sh
git clone https://github.com/L-Eugene/macbook-configs.git ~/.config/nixpkgs
cd ~/.config/nixpkgs
```

### 2. Personalise the configuration

Open `flake.nix` and edit the three values near the top of the `outputs`
section:

```nix
# "aarch64-darwin" for Apple Silicon  |  "x86_64-darwin" for Intel
system = "aarch64-darwin";

# Your macOS short username (output of `whoami`)
username = "changeme";

# Machine hostname (System Preferences → Sharing → Computer Name)
hostname = "macbook";
```

Optionally fill in `home/default.nix` with your Git identity:

```nix
programs.git = {
  userName  = "Your Name";
  userEmail = "you@example.com";
};
```

### 3. Bootstrap nix-darwin (first run only)

If `darwin-rebuild` is not yet in your `PATH`:

```sh
nix run nix-darwin -- switch --flake ~/.config/nixpkgs
```

### 4. Apply the configuration

On every subsequent change:

```sh
darwin-rebuild switch --flake ~/.config/nixpkgs
```

Or use the shell alias set up by this config:

```sh
darwin-switch
```

> **Default browser dialog:** The first time the activation script calls
> `defaultbrowser firefox` a macOS confirmation dialog will appear.
> Click **Use Firefox** to confirm.

---

## Keeping the configuration up to date

### Update all flake inputs

```sh
nix flake update
darwin-rebuild switch --flake ~/.config/nixpkgs
```

### Update a single input (e.g. nixpkgs only)

```sh
nix flake lock --update-input nixpkgs
darwin-rebuild switch --flake ~/.config/nixpkgs
```

---

## Editing the configuration

```
~/.config/nixpkgs/
├── flake.nix            ← top-level inputs, system/username/hostname
├── modules/
│   ├── system.nix       ← macOS system defaults (Dock, Finder, keyboard…)
│   ├── apps.nix         ← system-level Nix packages + Syncthing service
│   └── homebrew.nix     ← Homebrew casks (Firefox, KeePassXC) + cleanup
├── home/
│   └── default.nix      ← per-user config: VSCode, Git, Zsh, SSH…
└── secrets/
    └── secrets.nix      ← agenix secret declarations
```

### Adding a new package (Nix)

Add the package to `modules/apps.nix` (system-wide) or `home/default.nix`
(`home.packages`, user-only):

```nix
# modules/apps.nix
environment.systemPackages = with pkgs; [
  ...
  your-new-package
];
```

### Adding a new Homebrew cask

Add the cask name to `modules/homebrew.nix`:

```nix
casks = [
  "firefox"
  "keepassxc"
  "your-new-cask"   # ← add here
];
```

### Adding a VSCode extension

**From nixpkgs** (see `pkgs.vscode-extensions.*`):

```nix
# home/default.nix – programs.vscode.extensions
(with pkgs.vscode-extensions; [
  ...
  publisher.extension-name
])
```

**From the Marketplace** (via `nix-vscode-extensions`):

Add the extension to the `marketplaceExts` list in `home/default.nix`:

```nix
marketplaceExts = with marketplace; [
  github.codespaces
  publisher.extension-name   # exactly as it appears in the Marketplace URL
];
```

### Changing macOS system defaults

Edit `modules/system.nix`.  All options are documented in the
[nix-darwin manual](https://daiderd.com/nix-darwin/manual/index.html).

---

## Secrets management with Agenix

[agenix](https://github.com/ryantm/agenix) encrypts secrets with
[age](https://age-encryption.org/) using your **SSH public key(s)**.
Encrypted `*.age` files are safe to commit to this repository; only the
corresponding private key(s) can decrypt them.

### Setup

#### 1. Register your public key in `secrets/secrets.nix`

```nix
let
  machineKey = builtins.readFile /Users/you/.ssh/id_ed25519.pub;
  # or inline the key string directly:
  # machineKey = "ssh-ed25519 AAAA... you@macbook";
in {
  "my-secret.age".publicKeys = [ machineKey ];
}
```

#### 2. Create or edit a secret

```sh
# From the repository root:
nix run .#agenix -- -e secrets/my-secret.age
```

Your `$EDITOR` opens with a temporary decrypted file.  Save and quit — agenix
re-encrypts and writes the `.age` file.

#### 3. Reference a secret in a Nix module

```nix
# In any nix-darwin or home-manager module:
{ config, ... }:
{
  age.secrets."my-secret" = {
    file = ../secrets/my-secret.age;
    # Optional overrides:
    # owner = "username";
    # mode  = "0400";
  };

  # The decrypted value is available at runtime as:
  # config.age.secrets."my-secret".path
}
```

#### 4. Re-key all secrets (after adding a new SSH key)

```sh
nix run .#agenix -- -r -i ~/.ssh/id_ed25519
```

### Security best practices

- **Never commit plaintext secrets.** Use agenix for all credentials, tokens,
  and passwords.
- **Rotate your SSH keys** if you believe they have been compromised, then
  re-key all secrets immediately with the new key.
- **Backup your private key** securely (e.g. in KeePassXC or on a hardware
  security key). Without it you cannot decrypt your secrets.
- Keep `secrets/secrets.nix` up to date — remove keys for decommissioned
  machines or revoked access.
- Prefer **ed25519** or **RSA-4096** keys; avoid RSA-2048 for new keys.

---

## Garbage collection

Nix automatically collects unused store paths every Sunday at 03:00 (see
`modules/system.nix`).  To run it manually:

```sh
nix-collect-garbage --delete-older-than 30d
# Remove old system generations too:
sudo nix-collect-garbage --delete-older-than 30d
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `darwin-rebuild: command not found` | Run `nix run nix-darwin -- switch --flake ~/.config/nixpkgs` |
| Homebrew cask not found | Run `brew update` then retry `darwin-rebuild switch` |
| VSCode extension missing | Check the publisher/name against the [Marketplace](https://marketplace.visualstudio.com/) and ensure `nix flake update` was run |
| Default browser dialog never appeared | Run `defaultbrowser firefox` manually in your terminal |
| Syncthing not starting | Check `launchctl list | grep syncthing`; logs are in `~/Library/Logs/` |
| `agenix: no identity found` | Ensure `~/.ssh/id_ed25519` exists and matches a key in `secrets/secrets.nix` |

---

## License

[Unlicense](LICENSE)