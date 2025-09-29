{
  lib,
  config,
  charts,
  ...
}:

let
  cfg = config.monitoring.grafana;

  namespace = "monitoring";

  values = lib.attrsets.recursiveUpdate {
    # Configure admin credentials
    adminUser = cfg.admin.user;
    adminPassword = cfg.admin.password;

    # Enable persistence for Grafana data
    persistence = {
      enabled = cfg.storage.enabled;
      size = cfg.storage.size;
      storageClassName = lib.optionalString (cfg.storage.className != "") cfg.storage.className;
    };

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

    # Configure Grafana service
    service = {
      type = "ClusterIP";
      port = 80;
    };

    # Configure ingress
    ingress = lib.mkIf cfg.ingress.enabled {
      enabled = true;
      className = cfg.ingress.className;
      annotations = cfg.ingress.annotations;
      hosts = [ cfg.domain ];
      tls = lib.mkIf cfg.ingress.tls.enabled [
        {
          secretName = cfg.ingress.tls.secretName;
          hosts = [ cfg.domain ];
        }
      ];
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

    # Security context
    securityContext = {
      runAsUser = 472;
      runAsGroup = 472;
      fsGroup = 472;
    };

    # Configure Grafana server
    grafana.ini = {
      server = {
        domain = cfg.domain;
        root_url = "https://${cfg.domain}";
        serve_from_sub_path = false;
      };
      auth = {
        disable_login_form = false;
      };
      users = {
        allow_sign_up = false;
      };
    };
  } cfg.values;
in
{
  options.monitoring.grafana = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Grafana via Helm";
    };

    domain = mkOption {
      type = types.str;
      default = "grafana.kube.vkm";
      description = "Domain for Grafana access";
    };

    namespace = mkOption {
      type = types.str;
      default = "monitoring";
      description = "Namespace for Grafana deployment";
    };

    admin = mkOption {
      type = types.submodule {
        options = {
          user = mkOption {
            type = types.str;
            default = "admin";
            description = "Admin username";
          };
          password = mkOption {
            type = types.str;
            default = "admin";
            description = "Admin password";
          };
        };
      };
      default = { };
      description = "Admin credentials";
    };

    storage = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable persistent storage";
          };
          size = mkOption {
            type = types.str;
            default = "10Gi";
            description = "Storage size";
          };
          className = mkOption {
            type = types.str;
            default = "";
            description = "Storage class name";
          };
        };
      };
      default = { };
      description = "Storage configuration";
    };

    ingress = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable ingress";
          };
          className = mkOption {
            type = types.str;
            default = "traefik";
            description = "Ingress class";
          };
          annotations = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Ingress annotations";
          };
          tls = mkOption {
            type = types.submodule {
              options = {
                enabled = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Enable TLS";
                };
                secretName = mkOption {
                  type = types.str;
                  default = "grafana-tls";
                  description = "TLS secret name";
                };
              };
            };
            default = { };
            description = "TLS configuration";
          };
        };
      };
      default = { };
      description = "Ingress configuration";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extra Helm values for Grafana";
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ./generated.nix ];

    applications.grafana = {
      inherit namespace;
      createNamespace = true;

      helm.releases.grafana = {
        chart = charts.grafana.grafana;
        inherit values;
      };

      resources = { };
    };
  };
}
