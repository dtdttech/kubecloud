{ lib, config, charts, ... }:

let
  cfg = config.applications.nextcloud;

  namespace = "nextcloud";

  values = {
    # Nextcloud image configuration
    image = {
      repository = "nextcloud";
      tag = "29-apache";
      pullPolicy = "IfNotPresent";
    };

    # Admin user configuration
    nextcloud = {
      host = "nextcloud.local";
      username = "admin";
      password = "changeme123";
      
      # Mail configuration
      mail = {
        enabled = false;
      };
      
      # Configure data directory
      datadir = "/var/www/html/data";
      
      # Configure trusted domains
      configs = {
        custom.php = ''
          <?php
          $CONFIG = array (
            'overwriteprotocol' => 'https',
            'overwrite.cli.url' => 'https://nextcloud.local',
            'trusted_domains' => array (
              0 => 'nextcloud.local',
              1 => 'localhost',
            ),
          );
        '';
      };
    };

    # Persistence configuration
    persistence = {
      enabled = true;
      storageClass = "";
      accessMode = "ReadWriteOnce";
      size = "50Gi";
      nextcloudData = {
        enabled = true;
        storageClass = "";
        accessMode = "ReadWriteOnce";
        size = "100Gi";
      };
    };

    # Service configuration
    service = {
      type = "ClusterIP";
      port = 8080;
    };

    # Ingress configuration
    ingress = {
      enabled = true;
      className = "traefik";
      annotations = {
        "traefik.ingress.kubernetes.io/router.tls" = "true";
        "traefik.ingress.kubernetes.io/router.middlewares" = "nextcloud-nextcloud-redirect@kubernetescrd";
      };
      tls = [
        {
          secretName = "nextcloud-tls";
          hosts = ["nextcloud.local"];
        }
      ];
      hosts = [
        {
          host = "nextcloud.local";
          paths = [
            {
              path = "/";
              pathType = "Prefix";
            }
          ];
        }
      ];
    };

    # PostgreSQL database
    postgresql = {
      enabled = true;
      auth = {
        username = "nextcloud";
        password = "nextcloud123";
        database = "nextcloud";
      };
      primary = {
        persistence = {
          enabled = true;
          size = "20Gi";
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
        };
      };
    };

    # Resource limits
    resources = {
      requests = {
        cpu = "300m";
        memory = "512Mi";
      };
      limits = {
        cpu = "1";
        memory = "1Gi";
      };
    };

    # Liveness and readiness probes
    livenessProbe = {
      enabled = true;
      initialDelaySeconds = 120;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
      successThreshold = 1;
    };

    readinessProbe = {
      enabled = true;
      initialDelaySeconds = 30;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
      successThreshold = 1;
    };
  } // cfg.values;
in
{
  options.applications.nextcloud = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Nextcloud via Helm";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Extra Helm values for Nextcloud";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.nextcloud = {
      inherit namespace;
      createNamespace = true;

      helm.releases.nextcloud = {
        chart = {
          name = "nextcloud";
          repository = "https://nextcloud.github.io/helm/";
          version = "5.5.2";
        };
        inherit values;
      };
    };
  };
}