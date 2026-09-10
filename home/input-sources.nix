{ pkgs, lib, ... }:

let
  # Swift script that uses the TIS API to enforce exactly the two desired input
  # sources. Runs without restarting SystemUIServer — TIS notifies the menu bar
  # itself. Called both from the activation hook and from a login LaunchAgent.
  manageScript = pkgs.writeTextFile {
    name = "manage-input-sources.swift";
    text = ''
      import Carbon
      import Foundation

      let desired: Set<String> = [
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.RussianWin"
      ]

      // Give the session a moment to finish initialising TIS.
      Thread.sleep(forTimeInterval: 5)

      // Disable every enabled source that is not in our desired set.
      if let list = TISCreateInputSourceList(nil, false)?
          .takeRetainedValue() as? [TISInputSource] {
        for src in list {
          guard
            let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID)
          else { continue }
          let id = Unmanaged<CFString>.fromOpaque(ptr)
                     .takeUnretainedValue() as String
          if !desired.contains(id) {
            TISDisableInputSource(src)
          }
        }
      }

      // Ensure Russian-PC is enabled (it may have been absent from the list).
      let filter = [kTISPropertyInputSourceID as String:
                    "com.apple.keylayout.RussianWin"] as CFDictionary
      if let list = TISCreateInputSourceList(filter, true)?
          .takeRetainedValue() as? [TISInputSource],
         let src = list.first {
        TISEnableInputSource(src)
      }
    '';
  };
in

{
  # Run once when darwin-rebuild switch is executed.
  home.activation.inputSources = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /usr/bin/swift ${manageScript} &
  '';

  # Run at every login via a LaunchAgent so macOS cannot restore old sources.
  launchd.agents.inputSources = {
    enable = true;
    config = {
      ProgramArguments = [ "/usr/bin/swift" "${manageScript}" ];
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
}
