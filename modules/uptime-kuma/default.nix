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
  options = with lib; {
    kconf.core.baseDomainX = mkOption {
      type = types.str;
    };
  };

  # config = lib.mkIf cfg.enable {
  #   nixidy.applicationImports = [ ./generated.nix ];

  #   applications.uptime-kuma = {
  #     inherit namespace;
  #     createNamespace = true;

  #     helm.releases.uptime-kuma = {
  #       chart = charts.uptime-kuma.uptime-kuma;
  #       inherit values;
  #     };

  #     resources = { };
  #   };
  # };
}
