{ lib, config, ... }:

let
  cfg = config.scheduling.librebooking;

  namespace = "librebooking";
in
{
  options.scheduling.librebooking = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable LibreBooking scheduling system";
    };

    domain = mkOption {
      type = types.str;
      default = "librebooking.local";
      description = "Domain for LibreBooking instance";
    };

    database = {
      name = mkOption {
        type = types.str;
        default = "librebooking";
        description = "Database name for LibreBooking";
      };

      user = mkOption {
        type = types.str;
        default = "librebooking";
        description = "Database user for LibreBooking";
      };

      password = mkOption {
        type = types.str;
        default = "librebooking123";
        description = "Database password for LibreBooking";
      };
    };

    install = {
      password = mkOption {
        type = types.str;
        default = "install123";
        description = "Installation password for LibreBooking setup";
      };
    };

    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "Timezone for LibreBooking";
    };

    environment = mkOption {
      type = types.enum [ "development" "production" ];
      default = "production";
      description = "Environment mode for LibreBooking";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.librebooking = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # MariaDB Database for LibreBooking
        deployments.mariadb = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "mariadb";
              component = "database";
            };
            template = {
              metadata.labels = {
                app = "mariadb";
                component = "database";
              };
              spec = {
                containers = [{
                  name = "mariadb";
                  image = "mariadb:11.4";
                  env = [
                    {
                      name = "MYSQL_ROOT_PASSWORD";
                      value = "rootpassword123";
                    }
                    {
                      name = "MYSQL_DATABASE";
                      value = cfg.database.name;
                    }
                    {
                      name = "MYSQL_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "MYSQL_PASSWORD";
                      value = cfg.database.password;
                    }
                  ];
                  ports = [{
                    containerPort = 3306;
                  }];
                  volumeMounts = [{
                    name = "mariadb-storage";
                    mountPath = "/var/lib/mysql";
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
                  name = "mariadb-storage";
                  persistentVolumeClaim.claimName = "mariadb-pvc";
                }];
              };
            };
          };
        };

        # MariaDB Service
        services.mariadb = {
          spec = {
            selector = {
              app = "mariadb";
              component = "database";
            };
            ports = [{
              port = 3306;
              targetPort = 3306;
            }];
          };
        };

        # MariaDB PVC
        persistentVolumeClaims.mariadb-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "20Gi";
          };
        };

        # LibreBooking Application
        deployments.librebooking = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "librebooking";
              component = "app";
            };
            template = {
              metadata.labels = {
                app = "librebooking";
                component = "app";
              };
              spec = {
                initContainers = [{
                  name = "wait-for-mariadb";
                  image = "busybox:1.36";
                  command = [
                    "sh"
                    "-c"
                    "until nc -z mariadb.${namespace}.svc.cluster.local 3306; do echo waiting for mariadb; sleep 2; done;"
                  ];
                }];
                containers = [{
                  name = "librebooking";
                  image = "librebooking/librebooking:2.8.0";
                  env = [
                    {
                      name = "LB_DB_HOST";
                      value = "mariadb.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "LB_DB_NAME";
                      value = cfg.database.name;
                    }
                    {
                      name = "LB_DB_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "LB_DB_USER_PWD";
                      value = cfg.database.password;
                    }
                    {
                      name = "LB_INSTALL_PWD";
                      value = cfg.install.password;
                    }
                    {
                      name = "TZ";
                      value = cfg.timezone;
                    }
                    {
                      name = "LB_ENV";
                      value = cfg.environment;
                    }
                    {
                      name = "LB_LOG_LEVEL";
                      value = "info";
                    }
                    {
                      name = "LB_CRON_ENABLED";
                      value = "true";
                    }
                  ];
                  ports = [{
                    containerPort = 80;
                  }];
                  volumeMounts = [
                    {
                      name = "librebooking-config";
                      mountPath = "/opt/librebooking/config";
                    }
                    {
                      name = "librebooking-uploads";
                      mountPath = "/opt/librebooking/Web/uploads";
                    }
                  ];
                  resources = {
                    requests = {
                      memory = "512Mi";
                      cpu = "300m";
                    };
                    limits = {
                      memory = "1Gi";
                      cpu = "1000m";
                    };
                  };
                  livenessProbe = {
                    httpGet = {
                      path = "/";
                      port = 80;
                    };
                    initialDelaySeconds = 60;
                    periodSeconds = 30;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/";
                      port = 80;
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 10;
                  };
                }];
                volumes = [
                  {
                    name = "librebooking-config";
                    persistentVolumeClaim.claimName = "librebooking-config-pvc";
                  }
                  {
                    name = "librebooking-uploads";
                    persistentVolumeClaim.claimName = "librebooking-uploads-pvc";
                  }
                ];
              };
            };
          };
        };

        # LibreBooking Service
        services.librebooking = {
          spec = {
            selector = {
              app = "librebooking";
              component = "app";
            };
            ports = [{
              port = 80;
              targetPort = 80;
            }];
          };
        };

        # LibreBooking PVCs
        persistentVolumeClaims.librebooking-config-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "1Gi";
          };
        };

        persistentVolumeClaims.librebooking-uploads-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "5Gi";
          };
        };

        # Ingress for LibreBooking
        ingresses.librebooking = {
          metadata.annotations = {
            "traefik.ingress.kubernetes.io/router.tls" = "true";
          };
          spec = {
            ingressClassName = "traefik";
            tls = [{
              secretName = "librebooking-tls";
              hosts = [cfg.domain];
            }];
            rules = [{
              host = cfg.domain;
              http.paths = [{
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "librebooking";
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