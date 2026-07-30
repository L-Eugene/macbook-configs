# Agenix secrets configuration
#
# This file declares which SSH public keys are allowed to decrypt each secret.
# Encrypted secret files (*.age) ARE committed to the repository – only the
# keys listed here can decrypt them.
#
# Usage:
#   1. Add your SSH public key paths to the recipient lists below.
#   2. Create/re-key secrets with:
#        nix run .#agenix -- -e secrets/example-secret.age
#   3. Reference secrets in nix modules via:
#        config.age.secrets."example-secret".path
#
# See https://github.com/ryantm/agenix for full documentation.
let
  # ---------------------------------------------------------------------------
  # Public key definitions
  # ---------------------------------------------------------------------------

  # Read the machine's SSH public key from the current user's home (evaluated
  # on the Mac, where agenix runs). Adjust the filename if not id_ed25519.
  machineKey = builtins.readFile "${builtins.getEnv "HOME"}/.ssh/id_ed25519.pub";

  # Optional: add a YubiKey/hardware key or a remote backup key
  # backupKey = "ssh-ed25519 AAAA... backup-key";
in
{
  # ---------------------------------------------------------------------------
  # Secret declarations
  #
  # Each attribute name corresponds to an *.age file in this directory.
  # The `publicKeys` list determines who can decrypt it.
  # ---------------------------------------------------------------------------

  # SSH connection details (HostName/IP) for host `dev`.
  "ssh-dev.age".publicKeys = [ machineKey ];

  # Example: a Wi-Fi password
  # "wifi-password.age".publicKeys = [ machineKey ];

  # Example: an API token
  # "api-token.age".publicKeys = [ machineKey ];

  # Example: a syncthing API key
  # "syncthing-api-key.age".publicKeys = [ machineKey ];
}
