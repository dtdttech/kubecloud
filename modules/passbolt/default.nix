{ lib, config, ... }:

let
  cfg = config.security.passbolt;

  namespace = "passbolt";
in
{
  options.security.passbolt = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Passbolt password manager";
    };

    domain = mkOption {
      type = types.str;
      default = "passbolt.local";
      description = "Domain for Passbolt instance";
    };

    database = {
      password = mkOption {
        type = types.str;
        default = "passbolt123";
        description = "Database password for Passbolt";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.passbolt = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # MySQL Database for Passbolt
        deployments.mysql = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "mysql";
              component = "database";
            };
            template = {
              metadata.labels = {
                app = "mysql";
                component = "database";
              };
              spec = {
                containers = [{
                  name = "mysql";
                  image = "mysql:8.0";
                  env = [
                    {
                      name = "MYSQL_ROOT_PASSWORD";
                      value = "rootpassword123";
                    }
                    {
                      name = "MYSQL_DATABASE";
                      value = "passbolt";
                    }
                    {
                      name = "MYSQL_USER";
                      value = "passbolt";
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
                    name = "mysql-storage";
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
                  name = "mysql-storage";
                  persistentVolumeClaim.claimName = "mysql-pvc";
                }];
              };
            };
          };
        };

        # MySQL Service
        services.mysql = {
          spec = {
            selector = {
              app = "mysql";
              component = "database";
            };
            ports = [{
              port = 3306;
              targetPort = 3306;
            }];
          };
        };

        # MySQL PVC
        persistentVolumeClaims.mysql-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "20Gi";
          };
        };

        # Passbolt Application
        deployments.passbolt = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "passbolt";
              component = "app";
            };
            template = {
              metadata.labels = {
                app = "passbolt";
                component = "app";
              };
              spec = {
                initContainers = [{
                  name = "wait-for-mysql";
                  image = "busybox:1.36";
                  command = [
                    "sh"
                    "-c"
                    "until nc -z mysql.${namespace}.svc.cluster.local 3306; do echo waiting for mysql; sleep 2; done;"
                  ];
                }];
                containers = [{
                  name = "passbolt";
                  image = "passbolt/passbolt:latest-ce";
                  env = [
                    {
                      name = "APP_FULL_BASE_URL";
                      value = "https://${cfg.domain}";
                    }
                    {
                      name = "DATASOURCES_DEFAULT_HOST";
                      value = "mysql.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "DATASOURCES_DEFAULT_USERNAME";
                      value = "passbolt";
                    }
                    {
                      name = "DATASOURCES_DEFAULT_PASSWORD";
                      value = cfg.database.password;
                    }
                    {
                      name = "DATASOURCES_DEFAULT_DATABASE";
                      value = "passbolt";
                    }
                    {
                      name = "EMAIL_DEFAULT_FROM";
                      value = "admin@${cfg.domain}";
                    }
                    {
                      name = "EMAIL_TRANSPORT_DEFAULT_HOST";
                      value = "localhost";
                    }
                    {
                      name = "EMAIL_TRANSPORT_DEFAULT_PORT";
                      value = "587";
                    }
                    {
                      name = "EMAIL_TRANSPORT_DEFAULT_TLS";
                      value = "false";
                    }
                  ];
                  ports = [{
                    containerPort = 80;
                  }];
                  volumeMounts = [
                    {
                      name = "passbolt-gpg";
                      mountPath = "/etc/passbolt/gpg";
                    }
                    {
                      name = "passbolt-jwt";
                      mountPath = "/etc/passbolt/jwt";
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
                      path = "/healthcheck/status.json";
                      port = 80;
                    };
                    initialDelaySeconds = 60;
                    periodSeconds = 30;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/healthcheck/status.json";
                      port = 80;
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 10;
                  };
                }];
                volumes = [
                  {
                    name = "passbolt-gpg";
                    persistentVolumeClaim.claimName = "passbolt-gpg-pvc";
                  }
                  {
                    name = "passbolt-jwt";
                    persistentVolumeClaim.claimName = "passbolt-jwt-pvc";
                  }
                ];
              };
            };
          };
        };

        # Passbolt Service
        services.passbolt = {
          spec = {
            selector = {
              app = "passbolt";
              component = "app";
            };
            ports = [{
              port = 80;
              targetPort = 80;
            }];
          };
        };

        # Passbolt PVCs
        persistentVolumeClaims.passbolt-gpg-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "1Gi";
          };
        };

        persistentVolumeClaims.passbolt-jwt-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "1Gi";
          };
        };

        # Ingress for Passbolt
        ingresses.passbolt = {
          metadata.annotations = {
            "traefik.ingress.kubernetes.io/router.tls" = "true";
          };
          spec = {
            ingressClassName = "traefik";
            tls = [{
              secretName = "passbolt-tls";
              hosts = [cfg.domain];
            }];
            rules = [{
              host = cfg.domain;
              http.paths = [{
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "passbolt";
                  port.number = 80;
                };
              }];
            }];
          };
        };

        # ConfigMap for additional configuration if needed
        configMaps.passbolt-config = {
          data = {
            "nginx.conf" = ''
              add_header X-Frame-Options DENY;
              add_header X-Content-Type-Options nosniff;
              add_header Referrer-Policy same-origin;
            '';
          };
        };
      };
    };
  };
}