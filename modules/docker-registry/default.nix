{
  lib,
  config,
  charts,
  storageLib,
  storageConfig,
  secretsLib,
  secretsConfig,
  ...
}:

let
  cfg = config.services.docker-registry;

  namespace = "docker-registry";

  # Generate registry configuration
  registryConfig = {
    version = "0.1";
    log = {
      fields = {
        service = "registry";
      };
    };
    storage = {
      filesystem = {
        rootdirectory = "/var/lib/registry";
      };
      delete = {
        enabled = cfg.storage.deleteEnabled;
      };
    };
    http = {
      addr = ":5000";
      headers = {
        "X-Content-Type-Options" = [ "nosniff" ];
      };
    };
    health = {
      storagedriver = {
        enabled = true;
        interval = "10s";
        threshold = 3;
      };
    };
  }
  // lib.optionalAttrs cfg.auth.enabled {
    auth = {
      htpasswd = {
        realm = "Registry Realm";
        path = "/auth/htpasswd";
      };
    };
  }
  // lib.optionalAttrs cfg.proxy.enabled {
    proxy = {
      remoteurl = cfg.proxy.remoteUrl;
      username = cfg.proxy.username;
      password = cfg.proxy.password;
    };
  };

  values = lib.attrsets.recursiveUpdate {
    # Image configuration
    image = {
      repository = "registry";
      tag = "2.8.3";
      pullPolicy = "IfNotPresent";
    };

    # Service configuration
    service = {
      type = "ClusterIP";
      port = 5000;
      targetPort = 5000;
    };

    # Registry configuration
    configData = registryConfig;

    # Enable persistence for registry data
    persistence = {
      enabled = cfg.storage.enabled;
      size = cfg.storage.size;
      storageClass = lib.optionalString (cfg.storage.className != "") cfg.storage.className;
      accessMode = "ReadWriteOnce";
      mountPath = "/var/lib/registry";
    };

    # Configure ingress
    ingress = lib.mkIf cfg.ingress.enabled {
      enabled = true;
      className = cfg.ingress.className;
      annotations = lib.mergeAttrs {
        "nginx.ingress.kubernetes.io/proxy-body-size" = "0";
        "nginx.ingress.kubernetes.io/client-max-body-size" = "0";
        "nginx.ingress.kubernetes.io/proxy-buffering" = "off";
        "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off";
      } cfg.ingress.annotations;
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
        cpu = "1000m";
        memory = "1Gi";
      };
      requests = {
        cpu = "100m";
        memory = "256Mi";
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
      readOnlyRootFilesystem = true;
      capabilities = {
        drop = [ "ALL" ];
      };
    };

    # Health probes
    livenessProbe = {
      httpGet = {
        path = "/";
        port = 5000;
      };
      initialDelaySeconds = 30;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
    };

    readinessProbe = {
      httpGet = {
        path = "/";
        port = 5000;
      };
      initialDelaySeconds = 5;
      periodSeconds = 5;
      timeoutSeconds = 5;
      failureThreshold = 3;
    };

    # Authentication configuration
    secrets = lib.mkIf cfg.auth.enabled {
      htpasswd = cfg.auth.htpasswd;
    };

    # Additional volumes for tmp and cache
    extraVolumes = [
      {
        name = "tmp";
        emptyDir = { };
      }
      {
        name = "cache";
        emptyDir = { };
      }
    ];

    extraVolumeMounts = [
      {
        name = "tmp";
        mountPath = "/tmp";
      }
      {
        name = "cache";
        mountPath = "/var/cache/registry";
      }
    ];
  } cfg.values;
in
{
  options.services.docker-registry = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Docker Registry via Helm";
    };

    domain = mkOption {
      type = types.str;
      default = "registry.kube.vkm";
      description = "Domain for Docker Registry access";
    };

    namespace = mkOption {
      type = types.str;
      default = "docker-registry";
      description = "Namespace for Docker Registry deployment";
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
            default = "50Gi";
            description = "Storage size for registry data";
          };
          className = mkOption {
            type = types.str;
            default = "";
            description = "Storage class name";
          };
          deleteEnabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable deletion of image blobs and manifests";
          };
        };
      };
      default = { };
      description = "Storage configuration";
    };

    auth = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable HTTP basic authentication";
          };
          htpasswd = mkOption {
            type = types.str;
            default = "";
            description = "Htpasswd file content for authentication";
          };
        };
      };
      default = { };
      description = "Authentication configuration";
    };

    proxy = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable registry proxy mode";
          };
          remoteUrl = mkOption {
            type = types.str;
            default = "https://registry-1.docker.io";
            description = "Remote registry URL to proxy";
          };
          username = mkOption {
            type = types.str;
            default = "";
            description = "Username for remote registry authentication";
          };
          password = mkOption {
            type = types.str;
            default = "";
            description = "Password for remote registry authentication";
          };
        };
      };
      default = { };
      description = "Proxy configuration for pull-through cache";
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
            default = { };
            description = "Additional ingress annotations";
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
                  default = "docker-registry-tls";
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
      description = "Extra Helm values for Docker Registry";
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ./generated.nix ];

    applications.docker-registry = {
      inherit namespace;
      createNamespace = true;

      helm.releases.docker-registry = {
        chart = charts.docker-registry.docker-registry;
        inherit values;
      };

      resources = { };
    };
  };
}
