{ lib, config, charts, ... }:

let
  cfg = config.monitoring.grafana;

  namespace = "monitoring";

  values = {
    # Enable persistence for Grafana data
    persistence = {
      enabled = true;
      size = "10Gi";
    };

    # Configure admin credentials
    adminUser = "admin";
    
    # Datasources configuration
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://prometheus-server.monitoring.svc.cluster.local";
            access = "proxy";
            isDefault = true;
          }
        ];
      };
    };

    # Enable ingress if needed
    ingress = {
      enabled = false;
    };

    # Resource limits
    resources = {
      limits = {
        cpu = "200m";
        memory = "256Mi";
      };
      requests = {
        cpu = "100m";
        memory = "128Mi";
      };
    };
  } // cfg.values;
in
{
  options.monitoring.grafana = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Grafana via Helm";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Extra Helm values for Grafana";
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [./generated.nix];
    
    applications.grafana = {
      inherit namespace;
      createNamespace = true;

      helm.releases.grafana = {
        chart = charts.grafana.grafana;
        inherit values;
      };
    };
  };
}