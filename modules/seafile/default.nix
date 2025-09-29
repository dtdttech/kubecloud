{ lib, config, ... }:

let
  cfg = config.documentManagement.seafile;
  namespace = "seafile";
in
{
  options.documentManagement.seafile = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Seafile service";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.seafile = {
      inherit namespace;
      createNamespace = true;
    };
  };
}
