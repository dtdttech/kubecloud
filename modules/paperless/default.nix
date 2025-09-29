{
  lib,
  config,
  charts,
  ...
}:

let
  cfg = config.applications.paperless;

  namespace = "paperless";

  values = {
    # Paperless-ngx image configuration
    image = {
      repository = "ghcr.io/paperless-ngx/paperless-ngx";
      tag = "2.13.4";
      pullPolicy = "IfNotPresent";
    };

    # Paperless-ngx configuration
    paperless = {
      # Admin user configuration
      adminUser = "admin";
      adminPassword = "changeme123";
      adminMail = "admin@example.com";

      # Application settings
      secretKey = "change-this-secret-key";
      allowedHosts = [ "paperless.local" ];
      corsAllowedHosts = [ "http://localhost:8000" ];

      # Timezone
      timezone = "UTC";

      # URL configuration
      url = "https://paperless.local";

      # Redis configuration
      redis = {
        host = "paperless-redis-master";
        port = 6379;
      };

      # Database configuration
      database = {
        host = "paperless-postgresql";
        port = 5432;
        name = "paperless";
        user = "paperless";
        password = "paperless123";
      };

      # Storage configuration
      dataDir = "/usr/src/paperless/data";
      mediaDir = "/usr/src/paperless/media";
      consumeDir = "/usr/src/paperless/consume";
      exportDir = "/usr/src/paperless/export";

      # Additional environment variables
      extraEnv = {
        PAPERLESS_OCR_LANGUAGES = "eng";
        PAPERLESS_OCR_MODE = "skip";
        PAPERLESS_ENABLE_UPDATE_CHECK = "false";
      };
    };

    # Persistence configuration
    persistence = {
      enabled = true;
      storageClass = "";
      accessMode = "ReadWriteOnce";
      size = "10Gi";

      # Media storage
      media = {
        enabled = true;
        storageClass = "";
        accessMode = "ReadWriteOnce";
        size = "50Gi";
      };

      # Data storage
      data = {
        enabled = true;
        storageClass = "";
        accessMode = "ReadWriteOnce";
        size = "5Gi";
      };

      # Export storage
      export = {
        enabled = true;
        storageClass = "";
        accessMode = "ReadWriteOnce";
        size = "10Gi";
      };

      # Consume storage
      consume = {
        enabled = true;
        storageClass = "";
        accessMode = "ReadWriteOnce";
        size = "5Gi";
      };
    };

    # PostgreSQL database
    postgresql = {
      enabled = true;
      auth = {
        username = "paperless";
        password = "paperless123";
        database = "paperless";
      };
      primary = {
        persistence = {
          enabled = true;
          size = "20Gi";
          storageClass = "";
        };
      };
    };

    # Redis cache
    redis = {
      enabled = true;
      auth = {
        enabled = true;
        password = "redis123";
      };
      master = {
        persistence = {
          enabled = true;
          size = "8Gi";
          storageClass = "";
        };
      };
    };

    # Service configuration
    service = {
      type = "ClusterIP";
      port = 8000;
    };

    # Ingress configuration
    ingress = {
      enabled = true;
      className = "nginx";
      annotations = {
        "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
        "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true";
        "nginx.ingress.kubernetes.io/enable-gzip" = "true";
      };
      tls = [
        {
          secretName = "paperless-tls";
          hosts = [ "paperless.local" ];
        }
      ];
      hosts = [
        {
          host = "paperless.local";
          paths = [
            {
              path = "/";
              pathType = "Prefix";
            }
          ];
        }
      ];
    };

    # Resource limits
    resources = {
      requests = {
        cpu = "200m";
        memory = "512Mi";
      };
      limits = {
        cpu = "1000m";
        memory = "2Gi";
      };
    };

    # Liveness and readiness probes
    livenessProbe = {
      enabled = true;
      httpGet = {
        path = "/";
        port = 8000;
      };
      initialDelaySeconds = 30;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
      successThreshold = 1;
    };

    readinessProbe = {
      enabled = true;
      httpGet = {
        path = "/";
        port = 8000;
      };
      initialDelaySeconds = 5;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
      successThreshold = 1;
    };
  }
  // cfg.values;
in
{
  options.applications.paperless = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Paperless-ngx via Helm";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extra Helm values for Paperless-ngx";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.paperless = {
      inherit namespace;
      createNamespace = true;

      helm.releases.paperless = {
        chart = {
          name = "paperless-ngx";
          repository = "https://charts.paperless-ngx.com";
          version = "1.1.0";
        };
        inherit values;
      };
    };
  };
}
