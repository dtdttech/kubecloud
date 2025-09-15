{ lib, config, ... }:

let
  cfg = config.support.zammad;

  namespace = "zammad";
in
{
  options.support.zammad = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Zammad helpdesk and customer support system";
    };

    domain = mkOption {
      type = types.str;
      default = "zammad.local";
      description = "Domain for Zammad instance";
    };

    version = mkOption {
      type = types.str;
      default = "6.5.1";
      description = "Zammad version to deploy";
    };

    database = {
      name = mkOption {
        type = types.str;
        default = "zammad_production";
        description = "Database name for Zammad";
      };

      user = mkOption {
        type = types.str;
        default = "zammad";
        description = "Database user for Zammad";
      };

      password = mkOption {
        type = types.str;
        default = "zammad123";
        description = "Database password for Zammad";
      };
    };

    elasticsearch = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Elasticsearch for Zammad";
      };

      version = mkOption {
        type = types.str;
        default = "8.19.2";
        description = "Elasticsearch version";
      };
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Berlin";
      description = "Timezone for Zammad";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.zammad = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # PostgreSQL Database
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
                  image = "postgres:15";
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
                      memory = "512Mi";
                      cpu = "300m";
                    };
                    limits = {
                      memory = "1Gi";
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

        # Redis Cache
        deployments.redis = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "redis";
              component = "cache";
            };
            template = {
              metadata.labels = {
                app = "redis";
                component = "cache";
              };
              spec = {
                containers = [{
                  name = "redis";
                  image = "redis:7.4.5";
                  ports = [{
                    containerPort = 6379;
                  }];
                  volumeMounts = [{
                    name = "redis-storage";
                    mountPath = "/data";
                  }];
                  resources = {
                    requests = {
                      memory = "128Mi";
                      cpu = "100m";
                    };
                    limits = {
                      memory = "256Mi";
                      cpu = "200m";
                    };
                  };
                }];
                volumes = [{
                  name = "redis-storage";
                  persistentVolumeClaim.claimName = "redis-pvc";
                }];
              };
            };
          };
        };

        # Memcached
        deployments.memcached = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "memcached";
              component = "cache";
            };
            template = {
              metadata.labels = {
                app = "memcached";
                component = "cache";
              };
              spec = {
                containers = [{
                  name = "memcached";
                  image = "memcached:1.6.39";
                  ports = [{
                    containerPort = 11211;
                  }];
                  resources = {
                    requests = {
                      memory = "64Mi";
                      cpu = "50m";
                    };
                    limits = {
                      memory = "128Mi";
                      cpu = "100m";
                    };
                  };
                }];
              };
            };
          };
        };

        # Elasticsearch (conditional)
        deployments.elasticsearch = lib.mkIf cfg.elasticsearch.enabled {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "elasticsearch";
              component = "search";
            };
            template = {
              metadata.labels = {
                app = "elasticsearch";
                component = "search";
              };
              spec = {
                containers = [{
                  name = "elasticsearch";
                  image = "docker.elastic.co/elasticsearch/elasticsearch:${cfg.elasticsearch.version}";
                  env = [
                    {
                      name = "discovery.type";
                      value = "single-node";
                    }
                    {
                      name = "xpack.security.enabled";
                      value = "false";
                    }
                    {
                      name = "ES_JAVA_OPTS";
                      value = "-Xms512m -Xmx512m";
                    }
                  ];
                  ports = [{
                    containerPort = 9200;
                  }];
                  volumeMounts = [{
                    name = "elasticsearch-storage";
                    mountPath = "/usr/share/elasticsearch/data";
                  }];
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
                }];
                volumes = [{
                  name = "elasticsearch-storage";
                  persistentVolumeClaim.claimName = "elasticsearch-pvc";
                }];
              };
            };
          };
        };

        # Zammad Init
        jobs.zammad-init = {
          spec = {
            template = {
              spec = {
                restartPolicy = "OnFailure";
                initContainers = [
                  {
                    name = "wait-for-postgresql";
                    image = "busybox:1.36";
                    command = [
                      "sh"
                      "-c"
                      "until nc -z postgresql.${namespace}.svc.cluster.local 5432; do echo waiting for postgresql; sleep 2; done;"
                    ];
                  }
                ] ++ lib.optionals cfg.elasticsearch.enabled [{
                  name = "wait-for-elasticsearch";
                  image = "busybox:1.36";
                  command = [
                    "sh"
                    "-c"
                    "until nc -z elasticsearch.${namespace}.svc.cluster.local 9200; do echo waiting for elasticsearch; sleep 2; done;"
                  ];
                }];
                containers = [{
                  name = "zammad-init";
                  image = "ghcr.io/zammad/zammad:${cfg.version}";
                  command = ["zammad" "run" "rails" "r" "Setting.set('system_init_done', true)"];
                  env = [
                    {
                      name = "POSTGRES_HOST";
                      value = "postgresql.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "POSTGRES_DB";
                      value = cfg.database.name;
                    }
                    {
                      name = "POSTGRES_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "POSTGRES_PASS";
                      value = cfg.database.password;
                    }
                    {
                      name = "REDIS_URL";
                      value = "redis://redis.${namespace}.svc.cluster.local:6379";
                    }
                    {
                      name = "MEMCACHE_SERVERS";
                      value = "memcached.${namespace}.svc.cluster.local:11211";
                    }
                  ] ++ lib.optionals cfg.elasticsearch.enabled [
                    {
                      name = "ELASTICSEARCH_ENABLED";
                      value = "true";
                    }
                    {
                      name = "ELASTICSEARCH_HOST";
                      value = "elasticsearch.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "ELASTICSEARCH_PORT";
                      value = "9200";
                    }
                  ];
                }];
              };
            };
          };
        };

        # Zammad Rails Server
        deployments.zammad-railsserver = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "zammad";
              component = "railsserver";
            };
            template = {
              metadata.labels = {
                app = "zammad";
                component = "railsserver";
              };
              spec = {
                containers = [{
                  name = "zammad-railsserver";
                  image = "ghcr.io/zammad/zammad:${cfg.version}";
                  command = ["zammad" "run" "rails" "server"];
                  env = [
                    {
                      name = "POSTGRES_HOST";
                      value = "postgresql.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "POSTGRES_DB";
                      value = cfg.database.name;
                    }
                    {
                      name = "POSTGRES_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "POSTGRES_PASS";
                      value = cfg.database.password;
                    }
                    {
                      name = "REDIS_URL";
                      value = "redis://redis.${namespace}.svc.cluster.local:6379";
                    }
                    {
                      name = "MEMCACHE_SERVERS";
                      value = "memcached.${namespace}.svc.cluster.local:11211";
                    }
                    {
                      name = "TZ";
                      value = cfg.timezone;
                    }
                  ] ++ lib.optionals cfg.elasticsearch.enabled [
                    {
                      name = "ELASTICSEARCH_ENABLED";
                      value = "true";
                    }
                    {
                      name = "ELASTICSEARCH_HOST";
                      value = "elasticsearch.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "ELASTICSEARCH_PORT";
                      value = "9200";
                    }
                  ];
                  ports = [{
                    containerPort = 3000;
                  }];
                  volumeMounts = [{
                    name = "zammad-storage";
                    mountPath = "/opt/zammad/storage";
                  }];
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
                      path = "/";
                      port = 3000;
                    };
                    initialDelaySeconds = 60;
                    periodSeconds = 30;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/";
                      port = 3000;
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 10;
                  };
                }];
                volumes = [{
                  name = "zammad-storage";
                  persistentVolumeClaim.claimName = "zammad-storage-pvc";
                }];
              };
            };
          };
        };

        # Zammad Scheduler
        deployments.zammad-scheduler = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "zammad";
              component = "scheduler";
            };
            template = {
              metadata.labels = {
                app = "zammad";
                component = "scheduler";
              };
              spec = {
                containers = [{
                  name = "zammad-scheduler";
                  image = "ghcr.io/zammad/zammad:${cfg.version}";
                  command = ["zammad" "run" "rails" "runner" "Scheduler.work"];
                  env = [
                    {
                      name = "POSTGRES_HOST";
                      value = "postgresql.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "POSTGRES_DB";
                      value = cfg.database.name;
                    }
                    {
                      name = "POSTGRES_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "POSTGRES_PASS";
                      value = cfg.database.password;
                    }
                    {
                      name = "REDIS_URL";
                      value = "redis://redis.${namespace}.svc.cluster.local:6379";
                    }
                    {
                      name = "MEMCACHE_SERVERS";
                      value = "memcached.${namespace}.svc.cluster.local:11211";
                    }
                    {
                      name = "TZ";
                      value = cfg.timezone;
                    }
                  ] ++ lib.optionals cfg.elasticsearch.enabled [
                    {
                      name = "ELASTICSEARCH_ENABLED";
                      value = "true";
                    }
                    {
                      name = "ELASTICSEARCH_HOST";
                      value = "elasticsearch.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "ELASTICSEARCH_PORT";
                      value = "9200";
                    }
                  ];
                  volumeMounts = [{
                    name = "zammad-storage";
                    mountPath = "/opt/zammad/storage";
                  }];
                  resources = {
                    requests = {
                      memory = "512Mi";
                      cpu = "200m";
                    };
                    limits = {
                      memory = "1Gi";
                      cpu = "500m";
                    };
                  };
                }];
                volumes = [{
                  name = "zammad-storage";
                  persistentVolumeClaim.claimName = "zammad-storage-pvc";
                }];
              };
            };
          };
        };

        # Zammad WebSocket
        deployments.zammad-websocket = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "zammad";
              component = "websocket";
            };
            template = {
              metadata.labels = {
                app = "zammad";
                component = "websocket";
              };
              spec = {
                containers = [{
                  name = "zammad-websocket";
                  image = "ghcr.io/zammad/zammad:${cfg.version}";
                  command = ["zammad" "run" "websocket"];
                  env = [
                    {
                      name = "POSTGRES_HOST";
                      value = "postgresql.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "POSTGRES_DB";
                      value = cfg.database.name;
                    }
                    {
                      name = "POSTGRES_USER";
                      value = cfg.database.user;
                    }
                    {
                      name = "POSTGRES_PASS";
                      value = cfg.database.password;
                    }
                    {
                      name = "REDIS_URL";
                      value = "redis://redis.${namespace}.svc.cluster.local:6379";
                    }
                    {
                      name = "MEMCACHE_SERVERS";
                      value = "memcached.${namespace}.svc.cluster.local:11211";
                    }
                    {
                      name = "TZ";
                      value = cfg.timezone;
                    }
                  ] ++ lib.optionals cfg.elasticsearch.enabled [
                    {
                      name = "ELASTICSEARCH_ENABLED";
                      value = "true";
                    }
                    {
                      name = "ELASTICSEARCH_HOST";
                      value = "elasticsearch.${namespace}.svc.cluster.local";
                    }
                    {
                      name = "ELASTICSEARCH_PORT";
                      value = "9200";
                    }
                  ];
                  ports = [{
                    containerPort = 6042;
                  }];
                  resources = {
                    requests = {
                      memory = "256Mi";
                      cpu = "100m";
                    };
                    limits = {
                      memory = "512Mi";
                      cpu = "300m";
                    };
                  };
                }];
              };
            };
          };
        };

        # Services
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

        services.redis = {
          spec = {
            selector = {
              app = "redis";
              component = "cache";
            };
            ports = [{
              port = 6379;
              targetPort = 6379;
            }];
          };
        };

        services.memcached = {
          spec = {
            selector = {
              app = "memcached";
              component = "cache";
            };
            ports = [{
              port = 11211;
              targetPort = 11211;
            }];
          };
        };

        services.elasticsearch = lib.mkIf cfg.elasticsearch.enabled {
          spec = {
            selector = {
              app = "elasticsearch";
              component = "search";
            };
            ports = [{
              port = 9200;
              targetPort = 9200;
            }];
          };
        };

        services.zammad-railsserver = {
          spec = {
            selector = {
              app = "zammad";
              component = "railsserver";
            };
            ports = [{
              port = 3000;
              targetPort = 3000;
            }];
          };
        };

        services.zammad-websocket = {
          spec = {
            selector = {
              app = "zammad";
              component = "websocket";
            };
            ports = [{
              port = 6042;
              targetPort = 6042;
            }];
          };
        };

        # PVCs
        persistentVolumeClaims.postgresql-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "20Gi";
          };
        };

        persistentVolumeClaims.redis-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "1Gi";
          };
        };

        persistentVolumeClaims.elasticsearch-pvc = lib.mkIf cfg.elasticsearch.enabled {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "10Gi";
          };
        };

        persistentVolumeClaims.zammad-storage-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "10Gi";
          };
        };

        # Ingress
        ingresses.zammad = {
          metadata.annotations = {
            "traefik.ingress.kubernetes.io/router.tls" = "true";
            "nginx.ingress.kubernetes.io/proxy-body-size" = "50m";
          };
          spec = {
            ingressClassName = "traefik";
            tls = [{
              secretName = "zammad-tls";
              hosts = [cfg.domain];
            }];
            rules = [{
              host = cfg.domain;
              http.paths = [
                {
                  path = "/ws";
                  pathType = "Prefix";
                  backend.service = {
                    name = "zammad-websocket";
                    port.number = 6042;
                  };
                }
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "zammad-railsserver";
                    port.number = 3000;
                  };
                }
              ];
            }];
          };
        };
      };
    };
  };
}