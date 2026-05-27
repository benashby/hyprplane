self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.hyprplane;
  inherit (lib) mkEnableOption mkOption mkIf types concatStringsSep;

  slotKeysStr    = concatStringsSep "," cfg.settings.slot.keys;
  persistentStr  = concatStringsSep "," cfg.settings.persistentWorkspaces;
  passthroughStr = concatStringsSep "," cfg.settings.passthroughWorkspaces;
in
{
  options.programs.hyprplane = {
    enable  = mkEnableOption "hyprplane plane-level workspace manager";

    package = mkOption {
      type        = types.package;
      default     = self.packages.${pkgs.stdenv.hostPlatform.system}.hyprplane;
      description = "The hyprplane package.";
    };

    systemd = {
      enable = mkOption {
        type    = types.bool;
        default = true;
        description = "Manage hyprplane as a systemd user service.";
      };
      target = mkOption {
        type    = types.str;
        default = "hyprland-session.target";
        description = "Systemd target to bind the service to.";
      };
    };

    settings = {
      slotsPerPlane = mkOption {
        type    = types.int;
        default = 12;
        description = "Number of workspace slots per plane.";
      };

      persistentWorkspaces = mkOption {
        type    = types.listOf types.str;
        default = [];
        description = "Named Hyprland workspaces never assigned to any plane's slot range.";
        example  = [ "gaming" "browsers" "chat" "media" ];
      };

      passthroughWorkspaces = mkOption {
        type    = types.listOf types.str;
        default = [];
        description = "Workspaces where slot keys are unbound so they pass through to the app.";
        example  = [ "gaming" ];
      };

      slot = {
        keys = mkOption {
          type        = types.nonEmptyListOf types.str;
          description = "Key names for slot bindings (any Hyprland key name). Required — hyprplane binds no keys by default.";
          example     = [ "F1" "F2" "F3" "F4" "F5" "F6" "F7" "F8" "F9" "F10" "F11" "F12" ];
        };

        modifier = mkOption {
          type    = types.str;
          default = "";
          description = "Modifier for slot bindings. Empty string = no modifier (hyprctl bind syntax: ',KEY,...').";
          example  = "SUPER";
        };

        moveModifier = mkOption {
          type        = types.str;
          description = "Modifier for move-window-to-slot bindings. Use \"NONE\" to disable move-to-slot bindings entirely. Required.";
          example     = "SHIFT";
        };
      };
    };
  };

  config = mkIf (cfg.enable && cfg.systemd.enable) {
    systemd.user.services.hyprplane = {
      Unit = {
        Description = "hyprplane workspace plane manager";
        After       = [ cfg.systemd.target ];
        PartOf      = [ cfg.systemd.target ];
      };
      Service = {
        Type       = "simple";
        ExecStart  = lib.concatStringsSep " " (
          [
            "${cfg.package}/bin/hyprplane"
            "--slots"                  (toString cfg.settings.slotsPerPlane)
            "--slot-keys"              slotKeysStr
            "--move-modifier"          cfg.settings.slot.moveModifier
            "--persistent-workspaces"  persistentStr
            "--passthrough-workspaces" passthroughStr
          ]
          # omit --slot-modifier when empty — systemd tokenizer drops empty args
          ++ lib.optionals (cfg.settings.slot.modifier != "") [ "--slot-modifier" cfg.settings.slot.modifier ]
        );
        Restart          = "on-failure";
        RestartSec       = "3s";
        Environment      = [ "XDG_RUNTIME_DIR=%t" ];
        StandardOutput   = "journal";
        StandardError    = "journal";
        SyslogIdentifier = "hyprplane";
      };
      Install.WantedBy = [ cfg.systemd.target ];
    };
  };
}
