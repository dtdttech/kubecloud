{ lib, config, ... }:

let
  cfg = config.security.acme-dns;

  namespace = "acme-dns";

  configFile = ''
[general]
listen = "0.0.0.0:53"
protocol = "both"
domain = "${cfg.domain}"
nsname = "${cfg.nsname}"
nsadmin = "${cfg.nsadmin}"
debug = ${lib.boolToString cfg.debug}

[database]
engine = "sqlite3"
connection = "/var/lib/acme-dns/acme-dns.db"

[api]
ip = "0.0.0.0"
port = "80"
tls = "none"
disable_registration = ${lib.boolToString cfg.api.disableRegistration}
corsorigins = ["*"]
use_header = false

[logconfig]
loglevel = "${cfg.logging.level}"
logtype = "stdout"
logformat = "${cfg.logging.format}"
  '';
in
{
  options.security.acme-dns = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable acme-dns server for ACME DNS challenges";
    };

    domain = mkOption {
      type = types.str;
      default = "acme-dns.local";
      description = "Domain for acme-dns instance";
    };

    nsname = mkOption {
      type = types.str;
      default = "acme-dns.local";
      description = "Name server name for DNS responses";
    };

    nsadmin = mkOption {
      type = types.str;
      default = "admin.acme-dns.local";
      description = "Name server admin email";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug mode";
    };

    api = {
      disableRegistration = mkOption {
        type = types.bool;
        default = false;
        description = "Disable new account registration";
      };
    };

    logging = {
      level = mkOption {
        type = types.enum [ "error" "warning" "info" "debug" ];
        default = "info";
        description = "Log level";
      };

      format = mkOption {
        type = types.enum [ "json" "text" ];
        default = "text";
        description = "Log format";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.acme-dns = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # ConfigMap for acme-dns configuration
        configMaps.acme-dns-config = {
          data = {
            "config.cfg" = configFile;
          };
        };

        # acme-dns Application
        deployments.acme-dns = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "acme-dns";
              component = "server";
            };
            template = {
              metadata.labels = {
                app = "acme-dns";
                component = "server";
              };
              spec = {
                containers = [{
                  name = "acme-dns";
                  image = "joohoi/acme-dns:latest";
                  ports = [
                    {
                      name = "dns-tcp";
                      containerPort = 53;
                      protocol = "TCP";
                    }
                    {
                      name = "dns-udp";
                      containerPort = 53;
                      protocol = "UDP";
                    }
                    {
                      name = "http";
                      containerPort = 80;
                      protocol = "TCP";
                    }
                  ];
                  volumeMounts = [
                    {
                      name = "acme-dns-config";
                      mountPath = "/etc/acme-dns";
                      readOnly = true;
                    }
                    {
                      name = "acme-dns-data";
                      mountPath = "/var/lib/acme-dns";
                    }
                  ];
                  resources = {
                    requests = {
                      memory = "64Mi";
                      cpu = "100m";
                    };
                    limits = {
                      memory = "128Mi";
                      cpu = "200m";
                    };
                  };
                  livenessProbe = {
                    httpGet = {
                      path = "/health";
                      port = 80;
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 30;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/health";
                      port = 80;
                    };
                    initialDelaySeconds = 5;
                    periodSeconds = 10;
                  };
                }];
                volumes = [
                  {
                    name = "acme-dns-config";
                    configMap.name = "acme-dns-config";
                  }
                  {
                    name = "acme-dns-data";
                    persistentVolumeClaim.claimName = "acme-dns-data-pvc";
                  }
                ];
              };
            };
          };
        };

        # DNS Service (TCP and UDP)
        services.acme-dns-dns = {
          spec = {
            type = "LoadBalancer";
            selector = {
              app = "acme-dns";
              component = "server";
            };
            ports = [
              {
                name = "dns-tcp";
                port = 53;
                targetPort = 53;
                protocol = "TCP";
              }
              {
                name = "dns-udp";
                port = 53;
                targetPort = 53;
                protocol = "UDP";
              }
            ];
          };
        };

        # HTTP API Service
        services.acme-dns-api = {
          spec = {
            selector = {
              app = "acme-dns";
              component = "server";
            };
            ports = [{
              name = "http";
              port = 80;
              targetPort = 80;
              protocol = "TCP";
            }];
          };
        };

        # PVC for SQLite database
        persistentVolumeClaims.acme-dns-data-pvc = {
          spec = {
            accessModes = ["ReadWriteOnce"];
            resources.requests.storage = "1Gi";
          };
        };

        # Ingress for HTTP API
        ingresses.acme-dns = {
          metadata.annotations = {
            "traefik.ingress.kubernetes.io/router.tls" = "true";
          };
          spec = {
            ingressClassName = "traefik";
            tls = [{
              secretName = "acme-dns-tls";
              hosts = [cfg.domain];
            }];
            rules = [{
              host = cfg.domain;
              http.paths = [{
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "acme-dns-api";
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