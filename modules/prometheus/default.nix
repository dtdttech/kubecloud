{ lib, config, charts, ... }:

let
  cfg = config.monitoring.prometheus;

  namespace = "monitoring";

  values = {
    alertmanager.enabled = false;
    pushgateway.enabled = false;
    kubeStateMetrics.enabled = true;
    # prometheus = {
    #   prometheusSpec = {
    #     serviceMonitorSelectorNilUsesHelmValues = false;
    #     podMonitorSelectorNilUsesHelmValues = false;
    #     serviceMonitorSelector.matchLabels = {
    #       team = "frontend";
    #     };
    #     retention = "15d";
    #   };
    # };
  } // cfg.values;
in
{
  options.monitoring.prometheus = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Prometheus via Helm";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Extra Helm values for Prometheus";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.prometheus = {
      inherit namespace;

      helm.releases.prometheus = {
        chart = charts.prometheus-community.prometheus;
        inherit values;
        # version = "27.26.1";
      };
    };
  };
}
