{
  lib,
  config,
  charts,
  ...
}:

let
  cfg = config.monitoring.uptime-kuma;

  namespace = "monitoring";

  values = lib.attrsets.recursiveUpdate {
    # Image configuration
    image = {
      repository = "louislam/uptime-kuma";
      tag = "1";
      pullPolicy = "IfNotPresent";
    };

    # Service configuration
    service = {
      type = "ClusterIP";
      port = 3001;
      targetPort = 3001;
    };

    # Enable persistence for Uptime Kuma data
    persistence = {
      enabled = cfg.storage.enabled;
      size = cfg.storage.size;
      storageClass = lib.optionalString (cfg.storage.className != "") cfg.storage.className;
      accessMode = "ReadWriteOnce";
      mountPath = "/app/data";
    };

    # Configure ingress
    ingress = lib.mkIf cfg.ingress.enabled {
      enabled = true;
      className = cfg.ingress.className;
      annotations = cfg.ingress.annotations;
      hosts = [
        {
          host = cfg.domain;
          paths = [
            {
              path = "/";
              pathType = "Prefix";
            }
          ];
        }
      ];
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
        cpu = "500m";
        memory = "512Mi";
      };
      requests = {
        cpu = "100m";
        memory = "128Mi";
      };
    };

    # Security context
    securityContext = {
      runAsUser = 1000;
      runAsGroup = 1000;
      fsGroup = 1000;
      runAsNonRoot = true;
    };

    # Container security context
    containerSecurityContext = {
      allowPrivilegeEscalation = false;
      readOnlyRootFilesystem = false;
      capabilities = {
        drop = [ "ALL" ];
      };
    };

    # Environment variables
    env = [
      {
        name = "UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN";
        value = "0";
      }
    ];

    # Probes
    livenessProbe = {
      httpGet = {
        path = "/";
        port = 3001;
      };
      initialDelaySeconds = 180;
      periodSeconds = 20;
      timeoutSeconds = 5;
      failureThreshold = 3;
    };

    readinessProbe = {
      httpGet = {
        path = "/";
        port = 3001;
      };
      initialDelaySeconds = 30;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
    };
  } cfg.values;
in
{
  options.monitoring.uptime-kuma = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Uptime Kuma via Helm";
    };

    domain = mkOption {
      type = types.str;
      default = "uptime.kube.vkm";
      description = "Domain for Uptime Kuma access";
    };

    namespace = mkOption {
      type = types.str;
      default = "monitoring";
      description = "Namespace for Uptime Kuma deployment";
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
            default = "2Gi";
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
            default = "nginx";
            description = "Ingress class";
          };
          annotations = mkOption {
            type = types.attrsOf types.str;
            default = {
              "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600";
              "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600";
              "nginx.ingress.kubernetes.io/server-snippets" = ''
                location / {
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "upgrade";
                }
              '';
            };
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
                  default = "uptime-kuma-tls";
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
      description = "Extra Helm values for Uptime Kuma";
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ./generated.nix ];

    applications.uptime-kuma = {
      inherit namespace;
      createNamespace = true;

      helm.releases.uptime-kuma = {
        chart = charts.uptime-kuma.uptime-kuma;
        inherit values;
      };

      resources = { };
    };
  };
}