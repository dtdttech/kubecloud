{ lib, config, ... }:

let
  cfg = config.identity.keycloak;

  namespace = "keycloak";
in
{
  options.identity.keycloak = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Keycloak identity and access management";
    };

    domain = mkOption {
      type = types.str;
      default = "keycloak.local";
      description = "Domain for Keycloak instance";
    };

    admin = {
      username = mkOption {
        type = types.str;
        default = "admin";
        description = "Bootstrap admin username for Keycloak";
      };

      password = mkOption {
        type = types.str;
        default = "admin123";
        description = "Bootstrap admin password for Keycloak";
      };
    };

    database = {
      name = mkOption {
        type = types.str;
        default = "keycloak";
        description = "Database name for Keycloak";
      };

      user = mkOption {
        type = types.str;
        default = "keycloak";
        description = "Database user for Keycloak";
      };

      password = mkOption {
        type = types.str;
        default = "keycloak123";
        description = "Database password for Keycloak";
      };
    };

    mode = mkOption {
      type = types.enum [ "development" "production" ];
      default = "production";
      description = "Deployment mode for Keycloak";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.keycloak = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # PostgreSQL Database for Keycloak
        deployments.postgresql = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "postgresql";
              component = "database";
            };
            template = {
              metadata.labels = {
                app = "postgresql";
                component = "database";
              };
              spec = {
                containers = [{
                  name = "postgresql";
                  image = "postgres:16";
                  env = [
                    {
                      name = "POSTGRES_DB";
                      value = cfg.database.name;
                    }
                    {
                      name = "POSTGRES_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "POSTGRES_PASSWORD";
                      value = cfg.database.password;
                    }
                  ];
                  ports = [{
                    containerPort = 5432;
                  }];
                  volumeMounts = [{
                    name = "postgresql-storage";
                    mountPath = "/var/lib/postgresql/data";
                  }];
                  resources = {
                    requests = {
                      memory = "256Mi";
                      cpu = "250m";
                    };
                    limits = {
                      memory = "512Mi";
                      cpu = "500m";
                    };
                  };
                }];
                volumes = [{
                  name = "postgresql-storage";
                  persistentVolumeClaim.claimName = "postgresql-pvc";
                }];
              };
            };
          };
        };

        # PostgreSQL Service
        services.postgresql = {
          spec = {
            selector = {
              app = "postgresql";
              component = "database";
            };
            ports = [{
              port = 5432;
              targetPort = 5432;
            }];
          };
        };

        # PostgreSQL PVC
        persistentVolumeClaims.postgresql-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "20Gi";
          };
        };

        # Keycloak Application
        deployments.keycloak = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "keycloak";
              component = "app";
            };
            template = {
              metadata.labels = {
                app = "keycloak";
                component = "app";
              };
              spec = {
                initContainers = [{
                  name = "wait-for-postgresql";
                  image = "busybox:1.36";
                  command = [
                    "sh"
                    "-c"
                    "until nc -z postgresql.${namespace}.svc.cluster.local 5432; do echo waiting for postgresql; sleep 2; done;"
                  ];
                }];
                containers = [{
                  name = "keycloak";
                  image = "quay.io/keycloak/keycloak:25.0";
                  args = if cfg.mode == "development" then ["start-dev"] else ["start" "--optimized"];
                  env = [
                    {
                      name = "KC_BOOTSTRAP_ADMIN_USERNAME";
                      value = cfg.admin.username;
                    }
                    {
                      name = "KC_BOOTSTRAP_ADMIN_PASSWORD";
                      value = cfg.admin.password;
                    }
                    {
                      name = "KC_DB";
                      value = "postgres";
                    }
                    {
                      name = "KC_DB_URL";
                      value = "jdbc:postgresql://postgresql.${namespace}.svc.cluster.local:5432/${cfg.database.name}";
                    }
                    {
                      name = "KC_DB_USERNAME";
                      value = cfg.database.user;
                    }
                    {
                      name = "KC_DB_PASSWORD";
                      value = cfg.database.password;
                    }
                    {
                      name = "KC_HOSTNAME";
                      value = cfg.domain;
                    }
                    {
                      name = "KC_HOSTNAME_STRICT_HTTPS";
                      value = if cfg.mode == "production" then "true" else "false";
                    }
                    {
                      name = "KC_HTTP_ENABLED";
                      value = if cfg.mode == "development" then "true" else "false";
                    }
                    {
                      name = "KC_PROXY_HEADERS";
                      value = "xforwarded";
                    }
                    {
                      name = "KC_HEALTH_ENABLED";
                      value = "true";
                    }
                    {
                      name = "KC_METRICS_ENABLED";
                      value = "true";
                    }
                  ];
                  ports = [
                    {
                      name = "http";
                      containerPort = 8080;
                    }
                    {
                      name = "https";
                      containerPort = 8443;
                    }
                    {
                      name = "management";
                      containerPort = 9000;
                    }
                  ];
                  resources = {
                    requests = {
                      memory = "1Gi";
                      cpu = "500m";
                    };
                    limits = {
                      memory = "2Gi";
                      cpu = "1000m";
                    };
                  };
                  livenessProbe = {
                    httpGet = {
                      path = "/health/live";
                      port = 9000;
                    };
                    initialDelaySeconds = 120;
                    periodSeconds = 30;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/health/ready";
                      port = 9000;
                    };
                    initialDelaySeconds = 60;
                    periodSeconds = 10;
                  };
                  startupProbe = {
                    httpGet = {
                      path = "/health/started";
                      port = 9000;
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 5;
                    timeoutSeconds = 2;
                    failureThreshold = 60;
                  };
                }];
              };
            };
          };
        };

        # Keycloak Service
        services.keycloak = {
          spec = {
            selector = {
              app = "keycloak";
              component = "app";
            };
            ports = [
              {
                name = "http";
                port = 80;
                targetPort = 8080;
              }
              {
                name = "https";
                port = 443;
                targetPort = 8443;
              }
              {
                name = "management";
                port = 9000;
                targetPort = 9000;
              }
            ];
          };
        };

        # Ingress for Keycloak
        ingresses.keycloak = {
          metadata.annotations = {
            "traefik.ingress.kubernetes.io/router.tls" = "true";
          };
          spec = {
            ingressClassName = "traefik";
            tls = [{
              secretName = "keycloak-tls";
              hosts = [cfg.domain];
            }];
            rules = [{
              host = cfg.domain;
              http.paths = [{
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "keycloak";
                  port.number = 80;
                };
              }];
            }];
          };
        };
      };
    };
  };
}