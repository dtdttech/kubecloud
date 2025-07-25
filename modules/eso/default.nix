{
  lib,
  config,
  charts,
  ...
}: let
  cfg = config.secrets.eso;
  namespace = "kube-system";
in {
  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [./generated.nix];
    applications.eso = {
      inherit namespace;
      helm.releases.eso = {
        inherit values;
        chart = charts.external-secrets.external-secrets;
      };
    };
  };
}