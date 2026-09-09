{ pkgs, ... }:

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
  xdg.configFile."karabiner/karabiner.json" = {
    source = (pkgs.formats.json { }).generate "karabiner.json" {
      global = {
        show_in_menu_bar = true;
      };
      profiles = [
        {
          name = "Default profile";
          selected = true;
          complex_modifications = {
            rules = [
              {
                description = "Windows-like shortcuts on external keyboard only";
                manipulators = [
                  # Ctrl → Cmd on external keyboard (except in terminals)
                  # This makes Ctrl+C copy, Ctrl+Z undo, Ctrl+A select-all, etc.
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
                ];
              }
            ];
          };
        }
      ];
    };
  };
}
