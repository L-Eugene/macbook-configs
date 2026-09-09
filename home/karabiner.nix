{ pkgs, lib, ... }:

let
  # Condition: only fire on non-built-in (external) keyboards
  externalKeyboard = {
    type = "device_unless";
    identifiers = [ { is_built_in_keyboard = true; } ];
  };

  # Condition: skip terminal emulators so Ctrl still sends SIGINT there
  notTerminal = {
    type = "frontmost_application_unless";
    bundle_identifiers = [
      "^com\\.apple\\.Terminal$"
      "^com\\.googlecode\\.iterm2$"
      "^io\\.alacritty$"
      "^com\\.github\\.wez\\.wezterm$"
      "^com\\.mitchellh\\.ghostty$"
    ];
  };

in
{
  # ---------------------------------------------------------------------------
  # Karabiner-Elements – per-device key remapping
  # App is installed via Homebrew Cask (see modules/homebrew.nix).
  #
  # Rules apply to external keyboards only; the built-in keyboard is unchanged.
  # Ctrl is not remapped in terminal emulators (SIGINT must survive).
  #
  # Win key alone → switch input source (System Settings > Keyboard >
  # Shortcuts > Input Sources must have Ctrl+Space assigned there).
  # ---------------------------------------------------------------------------
  # ---------------------------------------------------------------------------
  # Write karabiner.json as a regular writable file via activation script.
  # xdg.configFile would create a read-only symlink into the Nix store, which
  # Karabiner can't write back to (it saves device state there on startup).
  # ---------------------------------------------------------------------------
  home.activation.karabinerConfig =
    let
      cfg = (pkgs.formats.json { }).generate "karabiner.json" {
        profiles = [
          {
            name = "Default profile";
            selected = true;
            # All keystrokes flow through Karabiner's virtual HID keyboard.
            # keyboard_type_v2 = "ansi" tells macOS to use standard PC/ANSI key
            # positions, fixing punctuation on Windows keyboards.
            virtual_hid_keyboard = {
              keyboard_type_v2 = "ansi";
            };
            complex_modifications = {
              rules = [
                {
                  description = "Windows-like shortcuts on external keyboard only";
                  manipulators = [
                    # Ctrl → Cmd (except in terminals, where Ctrl signals must survive)
                    {
                      type = "basic";
                      conditions = [ externalKeyboard notTerminal ];
                      from = {
                        key_code = "left_control";
                        modifiers = { optional = [ "any" ]; };
                      };
                      to = [ { key_code = "left_command"; } ];
                    }

                    # Alt+Tab → Cmd+Tab  (application switcher)
                    {
                      type = "basic";
                      conditions = [ externalKeyboard ];
                      from = {
                        key_code = "tab";
                        modifiers = {
                          mandatory = [ "left_option" ];
                          optional = [ "any" ];
                        };
                      };
                      to = [ { key_code = "tab"; modifiers = [ "left_command" ]; } ];
                    }

                    # Win key alone → switch input source (Ctrl+Space).
                    # Win + other key still acts as Cmd (passed through via `to`).
                    {
                      type = "basic";
                      conditions = [ externalKeyboard ];
                      from = {
                        key_code = "left_command";
                        modifiers = { optional = [ "any" ]; };
                      };
                      to = [ { key_code = "left_command"; } ];
                      to_if_alone = [
                        {
                          key_code = "spacebar";
                          modifiers = [ "left_control" ];
                        }
                      ];
                    }

                    # Home/End → beginning/end of line (Windows behaviour).
                    # On Mac these keys scroll the document instead.
                    {
                      type = "basic";
                      conditions = [ externalKeyboard ];
                      from = { key_code = "home"; modifiers = { optional = [ "any" ]; }; };
                      to = [ { key_code = "left_arrow"; modifiers = [ "left_command" ]; } ];
                    }
                    {
                      type = "basic";
                      conditions = [ externalKeyboard ];
                      from = { key_code = "end"; modifiers = { optional = [ "any" ]; }; };
                      to = [ { key_code = "right_arrow"; modifiers = [ "left_command" ]; } ];
                    }
                  ];
                }
              ];
            };
          }
        ];
      };
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      configDir="$HOME/.config/karabiner"
      configPath="$configDir/karabiner.json"
      $DRY_RUN_CMD mkdir -p "$configDir"
      $DRY_RUN_CMD install -m 0600 ${cfg} "$configPath"
    '';
}
