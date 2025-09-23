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
      default = false;
      description = "Enable Prometheus via Helm";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Extra Helm values for Prometheus";
    };

    rules = mkOption {
      type = types.listOf types.anything;
      default = [];
      description = "Prometheus alerting rules";
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [./generated.nix];
    
    applications.prometheus = {
      inherit namespace;
      createNamespace = true;

      helm.releases.prometheus = {
        chart = charts.prometheus-community.prometheus;
        inherit values;
        # version = "27.26.1";
      };

      resources = {
        # Create PrometheusRule resources from the rules option
        prometheusRules = lib.listToAttrs (lib.imap0 (i: rule: {
          name = rule.name or "rule-${toString i}";
          value = {
            apiVersion = "monitoring.coreos.com/v1";
            kind = "PrometheusRule";
            metadata = {
              name = rule.name or "rule-${toString i}";
              namespace = namespace;
              labels = {
                app = "prometheus";
                component = "rules";
              };
            };
            spec = {
              groups = [{
                name = rule.name or "rule-${toString i}";
                rules = rule.rules or [];
              }];
            };
          };
        }) cfg.rules);
      };
    };
  };
}
