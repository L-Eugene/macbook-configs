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

  # Generate a Ctrl+<key> → Cmd+<key> manipulator.
  # The general Ctrl→Cmd modifier remap would intercept the Ctrl key before
  # Ctrl+Arrow rules could fire, so we enumerate specific keys instead.
  ctrlToCmd = key: {
    type = "basic";
    conditions = [ externalKeyboard notTerminal ];
    from = {
      key_code = key;
      modifiers = {
        mandatory = [ "left_control" ];
        optional = [ "any" ];
      };
    };
    to = [ { key_code = key; modifiers = [ "left_command" ]; } ];
  };

  # All letter and common symbol keys that should follow Ctrl→Cmd.
  # Arrow keys are intentionally excluded – Ctrl+Left/Right is word-jump (below).
  ctrlCmdKeys = [
    "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m"
    "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
    "1" "2" "3" "4" "5" "6" "7" "8" "9" "0"
    "hyphen" "equal_sign"
    "open_bracket" "close_bracket" "backslash"
    "semicolon" "quote"
    "comma" "period" "slash"
    "tab" "delete_or_backspace" "return_or_enter"
    "spacebar"
  ];

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

  # Write karabiner.json as a regular writable file via activation script.
  # xdg.configFile would create a read-only symlink into the Nix store, which
  # Karabiner can't write back to (it saves device state there on startup).
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
                  manipulators =
                    [
                      # Ctrl+Left/Right → Option+Left/Right (word jump, Windows behaviour).
                      # Listed before the Ctrl→Cmd rules so they take priority.
                      # Ctrl+Shift+Left/Right selects by word (Shift passes through).
                      {
                        type = "basic";
                        conditions = [ externalKeyboard notTerminal ];
                        from = {
                          key_code = "left_arrow";
                          modifiers = {
                            mandatory = [ "left_control" ];
                            optional = [ "any" ];
                          };
                        };
                        to = [ { key_code = "left_arrow"; modifiers = [ "left_option" ]; } ];
                      }
                      {
                        type = "basic";
                        conditions = [ externalKeyboard notTerminal ];
                        from = {
                          key_code = "right_arrow";
                          modifiers = {
                            mandatory = [ "left_control" ];
                            optional = [ "any" ];
                          };
                        };
                        to = [ { key_code = "right_arrow"; modifiers = [ "left_option" ]; } ];
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
                        # Ctrl+Option+Space = "select next source in Input menu".
                        # Ctrl+Space is consumed by MS Teams, so use this instead.
                        to_if_alone = [
                          {
                            key_code = "spacebar";
                            modifiers = [ "left_control" "left_option" ];
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

                      # Ctrl+Alt+L → lock screen (Cmd+Ctrl+Q on macOS).
                      # Must be before the generic Ctrl+L → Cmd+L rule below.
                      {
                        type = "basic";
                        conditions = [ externalKeyboard ];
                        from = {
                          key_code = "l";
                          modifiers = {
                            mandatory = [ "left_control" "left_option" ];
                            optional = [ "any" ];
                          };
                        };
                        to = [ { key_code = "q"; modifiers = [ "left_command" "left_control" ]; } ];
                      }
                    ]
                    # Ctrl+<key> → Cmd+<key> for all common keys (excluding arrows above)
                    ++ (map ctrlToCmd ctrlCmdKeys);
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
