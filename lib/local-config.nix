# Machine-local configuration loader.
#
# Every value that is specific to one machine, one person or one network lives
# in local.nix, which is .gitignore'd — so nothing personal is ever committed
# and `git status` stays clean on a configured machine. local.nix.example is the
# tracked template.
#
# The file must evaluate to an attribute set. Every key is optional: a key that
# is absent (or explicitly `null`) falls back to the default declared below.
#
# IMPORTANT — reference this flake as `path:`, not as a bare path:
#
#   darwin-rebuild switch --flake path:<repo>#<hostname>
#
# A flake in a git repository only ever sees git-TRACKED files, so a gitignored
# local.nix is invisible to `--flake <repo>`. The `path:` fetcher copies the
# whole directory instead, local.nix included, and needs no `--impure`.
#
# As a fallback the loader also honours a copy kept outside the repository at
# ~/.config/macbook-configs/local.nix (or $MACBOOK_CONFIGS_LOCAL). Those live
# outside the flake source, so reading them *does* require `--impure`.
{
  lib,
  # Path to local.nix inside the flake source. Passed from flake.nix so it
  # resolves against the copied source tree rather than against this file.
  sourceFile ? null,
}:

let
  # ---------------------------------------------------------------------------
  # Fallback defaults — the values used when the local file is missing or does
  # not set a given key. Keep these generic; never put real values here.
  # ---------------------------------------------------------------------------
  defaults = {
    # "aarch64-darwin" for Apple Silicon (M-series); "x86_64-darwin" for Intel.
    system = "aarch64-darwin";

    # macOS short username (the one shown by `whoami`).
    username = "changeme";

    # Machine hostname (System Settings → General → Sharing → Local hostname).
    hostname = "macbook";

    # Path to this flake repository on the machine.
    configRepoPath = "~/.config/nixpkgs";

    # Git identity. `null` leaves the key unset, so git falls back to whatever
    # is configured globally or per-repo.
    gitUserName = null;
    gitUserEmail = null;

    # Private network the local HTTP proxy accepts connections from, in CIDR
    # notation. `null` restricts the proxy to loopback only.
    trustedSubnet = null;

    # Hosts on that network get relaxed SSH checking (they are re-imaged often,
    # so their host keys change). `null` disables the block entirely.
    trustedHostGlob = null;
    trustedHostUser = "admin";

    # Local tinyproxy listener (http://127.0.0.1:<port>).
    tinyproxyPort = 8787;

    # Remote development host. The HostName/IP itself is not stored here — it
    # lives in the agenix-encrypted secrets/ssh-<host>.age, decrypted at
    # activation to ~/.ssh/<host>.conf.
    devSshHost = "dev";
    devSshUser = "dev";

    # Port opened on the dev host that tunnels back to the local proxy.
    devRemoteForward = 48401;
  };

  # ---------------------------------------------------------------------------
  # Locate the file
  # ---------------------------------------------------------------------------
  env = name: builtins.getEnv name;

  home = env "HOME";

  # `sudo darwin-rebuild` evaluates as root, and depending on the sudoers
  # `env_keep` settings HOME may already be /var/root by then. Fall back to the
  # invoking user's home so a plain `sudo darwin-rebuild switch --impure` works
  # without having to forward any environment variable.
  sudoUser = env "SUDO_USER";

  envPath = env "MACBOOK_CONFIGS_LOCAL";

  relPath = ".config/macbook-configs/local.nix";

  # local.nix inside the flake source wins. It is present only when the flake
  # was fetched with `path:` (the git fetcher drops gitignored files), so this
  # resolving is itself the signal that the reference was correct.
  inSource = sourceFile != null && builtins.pathExists sourceFile;

  # Out-of-tree fallbacks. Each requires --impure, since getEnv yields "" under
  # pure evaluation and these paths lie outside the flake source anyway.
  outOfTree =
    lib.optional (envPath != "") envPath
    ++ lib.optional (home != "") "${home}/${relPath}"
    ++ lib.optional (sudoUser != "") "/Users/${sudoUser}/${relPath}";

  candidates = lib.optional inSource sourceFile ++ outOfTree;

  found = lib.findFirst builtins.pathExists null candidates;

  loaded = if found == null then { } else import found;

  # ---------------------------------------------------------------------------
  # Validate, then merge over the defaults
  # ---------------------------------------------------------------------------
  unknown = builtins.attrNames (builtins.removeAttrs loaded (builtins.attrNames defaults));

  # An explicit `null` means "no opinion", i.e. use the default. Without this a
  # commented-out-then-nulled key would silently override with null.
  provided = lib.filterAttrs (_: v: v != null) loaded;

  # Keys the local file does not set, which will therefore fall back to a
  # default. Surfaced as `missing` so the preflight guardrail can list them and
  # ask before a rebuild silently applies them — Nix itself cannot prompt, so
  # the question has to be asked by the wrapper, not during evaluation.
  # devSshHost becomes a file name that agenix writes as root
  # (~/.ssh/<devSshHost>.conf) and an ssh_config Host pattern, so only a plain
  # name is accepted: no "/" or leading "." to escape ~/.ssh, no whitespace or
  # newline to inject extra ssh_config directives.
  invalidDevSshHost =
    provided ? devSshHost
    && (
      !builtins.isString provided.devSshHost
      || builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" provided.devSshHost == null
    );

  missingNames = lib.subtractLists (builtins.attrNames provided) (builtins.attrNames defaults);
  missing = lib.getAttrs missingNames defaults;

  # Escape hatch for the non-interactive path: with MACBOOK_CONFIGS_STRICT set,
  # evaluation refuses to fall back at all. This guards invocations that bypass
  # the `darwin-switch` wrapper and so never see the prompt.
  strict = env "MACBOOK_CONFIGS_STRICT" != "";

  config =
    if strict && missingNames != [ ] then
      throw ''
        MACBOOK_CONFIGS_STRICT is set and these keys are not set in ${
          if found == null then "any machine-local config (no file found)" else toString found
        }:
            ${lib.concatStringsSep ", " missingNames}
        Set them, or unset MACBOOK_CONFIGS_STRICT to accept the defaults.
      ''
    else
      defaults // provided;
in

if !builtins.isAttrs loaded then
  throw "Machine-local config ${found} must evaluate to an attribute set."

else if unknown != [ ] then
  throw ''
    Unknown key(s) in machine-local config ${found}:
        ${lib.concatStringsSep ", " unknown}
    Known keys:
        ${lib.concatStringsSep ", " (builtins.attrNames defaults)}
  ''

else if invalidDevSshHost then
  throw ''
    devSshHost in machine-local config ${found} must be a plain host alias
    (letters, digits, ".", "_", "-"; not starting with "."). Got: ${builtins.toJSON provided.devSshHost}
  ''

else
  {
    inherit
      config
      defaults
      missing
      inSource
      ;
    # True when no local.nix could be located at all — neither in the flake
    # source nor out of tree. The flake turns this into an actionable error
    # rather than silently building the placeholder machine.
    notFound = found == null;
    source = if found == null then null else toString found;
  }
