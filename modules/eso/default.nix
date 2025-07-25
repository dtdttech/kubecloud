{
  lib,
  config,
  charts,
  ...
}: let
  cfg = config.secrets.eso;
  namespace = "kube-system";
  # values = {};
  values = cfg.values;
in {
    options.secrets.eso = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
  };
  config = lib.mkIf cfg.enable {
    # nixidy.applicationImports = [./generated.nix];
    applications.eso = {
      inherit namespace;
      helm.releases.eso = {
        inherit values;
        chart = charts.external-secrets.external-secrets;
      };
    };
  };
}