{
  lib,
  config,
  storageLib,
  storageConfig,
  secretsLib,
  secretsConfig,
  ...
}:

let
  cfg = config.documentation.bookstack;

  namespace = "bookstack";
in
{
  options.documentation.bookstack = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable BookStack documentation platform";
    };

    domain = mkOption {
      type = types.str;
      default = "bookstack.local";
      description = "Domain for BookStack instance";
    };

    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "Timezone for BookStack";
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "mariadb.${namespace}.svc.cluster.local";
        description = "Database host for BookStack";
      };

      name = mkOption {
        type = types.str;
        default = "bookstack";
        description = "Database name for BookStack";
      };

      user = mkOption {
        type = types.str;
        default = "bookstack";
        description = "Database user for BookStack";
      };

      password = mkOption {
        type = types.str;
        default = "bookstack123";
        description = "Database password for BookStack";
      };
    };

    app = {
      key = mkOption {
        type = types.str;
        default = "base64:H+eX8SaXwaCTY7jKDfXDfm2NvGV9RkSKzGHvwdHvz/w=";
        description = "Application encryption key for BookStack";
      };
    };

    storage = {
      provider = mkOption {
        type = types.enum [
          "local"
          "ceph"
          "longhorn"
        ];
        default = storageConfig.defaultProvider;
        description = "Storage provider to use for BookStack volumes";
      };

      database = {
        size = mkOption {
          type = types.str;
          default = "20Gi";
          description = "Size of the database storage volume";
        };
      };

      config = {
        size = mkOption {
          type = types.str;
          default = "5Gi";
          description = "Size of the BookStack config storage volume";
        };
      };
    };

    secrets = {
      provider = mkOption {
        type = types.enum [
          "internal"
          "external"
        ];
        default = secretsConfig.defaultProvider;
        description = "Secrets provider to use for BookStack secrets";
      };

      database = {
        useExisting = mkOption {
          type = types.bool;
          default = false;
          description = "Use existing database secret instead of generating one";
        };

        existingSecret = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Name of existing database secret to use";
        };
      };

      app = {
        useExisting = mkOption {
          type = types.bool;
          default = false;
          description = "Use existing application secret instead of generating one";
        };

        existingSecret = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Name of existing application secret to use";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # Create volumes using storage abstraction
      volumes = {
        mariadb = storageLib.commonVolumes.database {
          name = "mariadb";
          size = cfg.storage.database.size;
          provider = cfg.storage.provider;
        };
        bookstack-config = storageLib.commonVolumes.config {
          name = "bookstack-config";
          size = cfg.storage.config.size;
          provider = cfg.storage.provider;
        };
      };

      # Create secrets using secrets abstraction
      secrets = {
        database = lib.mkIf (!cfg.secrets.database.useExisting) (
          secretsLib.commonSecrets.database {
            name = "bookstack-database";
            provider = cfg.secrets.provider;
            username = cfg.database.user;
            password = cfg.database.password;
            database = cfg.database.name;
          }
        );

        app = lib.mkIf (!cfg.secrets.app.useExisting) (
          secretsLib.commonSecrets.application {
            name = "bookstack-app";
            provider = cfg.secrets.provider;
            secrets = {
              APP_KEY = cfg.app.key;
              APP_URL = "https://${cfg.domain}";
            };
          }
        );
      };
    in
    {

      applications.bookstack = {
        inherit namespace;
        createNamespace = true;

        resources = {
          # MariaDB Database for BookStack
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
                  containers = [
                    {
                      name = "mariadb";
                      image = "mariadb:11.4";
                      env = [
                        {
                          name = "MYSQL_ROOT_PASSWORD";
                          value = "rootpassword123"; # Keep separate for now
                        }
                      ]
                      ++ (
                        if cfg.secrets.database.useExisting then
                          [
                            (secretsLib.createSecretEnvVar {
                              name = "MYSQL_DATABASE";
                              secretName = cfg.secrets.database.existingSecret;
                              secretKey = "database";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "MYSQL_USER";
                              secretName = cfg.secrets.database.existingSecret;
                              secretKey = "username";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "MYSQL_PASSWORD";
                              secretName = cfg.secrets.database.existingSecret;
                              secretKey = "password";
                            })
                          ]
                        else
                          [
                            (secretsLib.createSecretEnvVar {
                              name = "MYSQL_DATABASE";
                              secretName = "bookstack-database";
                              secretKey = "database";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "MYSQL_USER";
                              secretName = "bookstack-database";
                              secretKey = "username";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "MYSQL_PASSWORD";
                              secretName = "bookstack-database";
                              secretKey = "password";
                            })
                          ]
                      );
                      ports = [
                        {
                          containerPort = 3306;
                        }
                      ];
                      volumeMounts = [
                        {
                          name = "mariadb-storage";
                          mountPath = "/var/lib/mysql";
                        }
                      ];
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
                    }
                  ];
                  volumes = [
                    {
                      name = "mariadb-storage";
                      persistentVolumeClaim.claimName = "mariadb-pvc";
                    }
                  ];
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
              ports = [
                {
                  port = 3306;
                  targetPort = 3306;
                }
              ];
            };
          };

          # PVCs generated from storage abstraction
          persistentVolumeClaims = volumes;

          # Secrets generated from secrets abstraction
          secrets = lib.filterAttrs (name: secret: secret != null) secrets;

          # BookStack Application
          deployments.bookstack = {
            spec = {
              replicas = 1;
              selector.matchLabels = {
                app = "bookstack";
                component = "app";
              };
              template = {
                metadata.labels = {
                  app = "bookstack";
                  component = "app";
                };
                spec = {
                  initContainers = [
                    {
                      name = "wait-for-mariadb";
                      image = "busybox:1.36";
                      command = [
                        "sh"
                        "-c"
                        "until nc -z mariadb.${namespace}.svc.cluster.local 3306; do echo waiting for mariadb; sleep 2; done;"
                      ];
                    }
                  ];
                  containers = [
                    {
                      name = "bookstack";
                      image = "lscr.io/linuxserver/bookstack:latest";
                      env = [
                        {
                          name = "PUID";
                          value = "1000";
                        }
                        {
                          name = "PGID";
                          value = "1000";
                        }
                        {
                          name = "TZ";
                          value = cfg.timezone;
                        }
                        {
                          name = "DB_HOST";
                          value = cfg.database.host;
                        }
                        {
                          name = "DB_PORT";
                          value = "3306";
                        }
                      ]
                      ++ (
                        if cfg.secrets.app.useExisting then
                          [
                            (secretsLib.createSecretEnvVar {
                              name = "APP_URL";
                              secretName = cfg.secrets.app.existingSecret;
                              secretKey = "APP_URL";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "APP_KEY";
                              secretName = cfg.secrets.app.existingSecret;
                              secretKey = "APP_KEY";
                            })
                          ]
                        else
                          [
                            (secretsLib.createSecretEnvVar {
                              name = "APP_URL";
                              secretName = "bookstack-app";
                              secretKey = "APP_URL";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "APP_KEY";
                              secretName = "bookstack-app";
                              secretKey = "APP_KEY";
                            })
                          ]
                      )
                      ++ (
                        if cfg.secrets.database.useExisting then
                          [
                            (secretsLib.createSecretEnvVar {
                              name = "DB_DATABASE";
                              secretName = cfg.secrets.database.existingSecret;
                              secretKey = "database";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "DB_USERNAME";
                              secretName = cfg.secrets.database.existingSecret;
                              secretKey = "username";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "DB_PASSWORD";
                              secretName = cfg.secrets.database.existingSecret;
                              secretKey = "password";
                            })
                          ]
                        else
                          [
                            (secretsLib.createSecretEnvVar {
                              name = "DB_DATABASE";
                              secretName = "bookstack-database";
                              secretKey = "database";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "DB_USERNAME";
                              secretName = "bookstack-database";
                              secretKey = "username";
                            })
                            (secretsLib.createSecretEnvVar {
                              name = "DB_PASSWORD";
                              secretName = "bookstack-database";
                              secretKey = "password";
                            })
                          ]
                      );
                      ports = [
                        {
                          containerPort = 80;
                        }
                      ];
                      volumeMounts = [
                        {
                          name = "bookstack-config";
                          mountPath = "/config";
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
                    }
                  ];
                  volumes = [
                    {
                      name = "bookstack-config";
                      persistentVolumeClaim.claimName = "bookstack-config-pvc";
                    }
                  ];
                };
              };
            };
          };

          # BookStack Service
          services.bookstack = {
            spec = {
              selector = {
                app = "bookstack";
                component = "app";
              };
              ports = [
                {
                  port = 80;
                  targetPort = 80;
                }
              ];
            };
          };

          # Ingress for BookStack
          ingresses.bookstack = {
            metadata.annotations = {
              "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
              "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true";
            };
            spec = {
              ingressClassName = "nginx";
              tls = [
                {
                  secretName = "bookstack-tls";
                  hosts = [ cfg.domain ];
                }
              ];
              rules = [
                {
                  host = cfg.domain;
                  http.paths = [
                    {
                      path = "/";
                      pathType = "Prefix";
                      backend.service = {
                        name = "bookstack";
                        port.number = 80;
                      };
                    }
                  ];
                }
              ];
            };
          };
        };
      };
    }
  );
}
