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
  cfg = config.webservers.nginx;

  # Helper function to create nginx configuration
  generateNginxConfig =
    {
      name,
      sites ? { },
      upstreams ? { },
      globalConfig ? { },
      modules ? [ ],
      ...
    }:
    let
      # Default global configuration
      defaultGlobalConfig = {
        user = "nginx";
        worker_processes = "auto";
        worker_connections = "1024";
        keepalive_timeout = "65";
        gzip = "on";
        server_tokens = "off";
        client_max_body_size = "1m";
      };

      # Merge global config with defaults
      finalGlobalConfig = defaultGlobalConfig // globalConfig;

      # Generate upstream blocks
      upstreamBlocks = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (upstreamName: upstream: ''
          upstream ${upstreamName} {
            ${lib.concatStringsSep "\n    " (map (server: "server ${server};") upstream.servers)}
            ${lib.optionalString (upstream.method or null != null) upstream.method}
            ${lib.optionalString (
              upstream.keepalive or null != null
            ) "keepalive ${toString upstream.keepalive};"}
          }
        '') upstreams
      );

      # Generate server blocks
      serverBlocks = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (siteName: site: ''
          server {
            listen ${toString (site.port or 80)}${
              lib.optionalString (site.defaultServer or false) " default_server"
            };
            ${lib.optionalString (site.serverName or null != null) "server_name ${site.serverName};"}
            
            ${lib.optionalString (site.root or null != null) "root ${site.root};"}
            ${lib.optionalString (site.index or null != null) "index ${site.index};"}
            
            # Security headers
            add_header X-Frame-Options SAMEORIGIN always;
            add_header X-Content-Type-Options nosniff always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header Referrer-Policy strict-origin-when-cross-origin always;
            
            ${lib.concatStringsSep "\n    " (
              map (location: ''
                location ${location.path} {
                  ${lib.optionalString (location.proxyPass or null != null) "proxy_pass ${location.proxyPass};"}
                  ${lib.optionalString (location.proxyPass or null != null) ''
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  ''}
                  ${lib.optionalString (location.tryFiles or null != null) "try_files ${location.tryFiles};"}
                  ${lib.optionalString (location.return or null != null) "return ${location.return};"}
                  ${lib.optionalString (location.alias or null != null) "alias ${location.alias};"}
                  ${location.extraConfig or ""}
                }
              '') (site.locations or [ ])
            )}
            
            ${site.extraConfig or ""}
          }
        '') sites
      );

    in
    ''
      # Global configuration
      user ${finalGlobalConfig.user};
      worker_processes ${finalGlobalConfig.worker_processes};

      error_log /var/log/nginx/error.log warn;
      pid /var/run/nginx.pid;

      events {
          worker_connections ${finalGlobalConfig.worker_connections};
      }

      http {
          include /etc/nginx/mime.types;
          default_type application/octet-stream;
          
          # Logging format
          log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                         '$status $body_bytes_sent "$http_referer" '
                         '"$http_user_agent" "$http_x_forwarded_for"';
          
          access_log /var/log/nginx/access.log main;
          
          # Basic settings
          sendfile on;
          tcp_nopush on;
          tcp_nodelay on;
          keepalive_timeout ${finalGlobalConfig.keepalive_timeout};
          types_hash_max_size 2048;
          server_tokens ${finalGlobalConfig.server_tokens};
          
          # Gzip compression
          gzip ${finalGlobalConfig.gzip};
          gzip_vary on;
          gzip_proxied any;
          gzip_comp_level 6;
          gzip_types
              text/plain
              text/css
              text/xml
              text/javascript
              application/json
              application/javascript
              application/xml+rss
              application/atom+xml
              image/svg+xml;
          
          # Client settings
          client_max_body_size ${finalGlobalConfig.client_max_body_size};
          
          ${upstreamBlocks}
          
          ${serverBlocks}
      }
    '';

  # Helper function to create nginx deployment
  createNginxDeployment =
    name: nginxConfig:
    let
      namespace = nginxConfig.namespace or "nginx";
      replicas = nginxConfig.replicas or 1;
      image = nginxConfig.image or "nginx:1.25.4-alpine";

      # Create volumes for configuration and content
      volumes =
        lib.optionalAttrs (nginxConfig.storage.config.enable or false) {
          "${name}-config" = storageLib.commonVolumes.config {
            name = "${name}-config";
            size = nginxConfig.storage.config.size or "1Gi";
            provider = nginxConfig.storage.provider or storageConfig.defaultProvider;
          };
        }
        // lib.optionalAttrs (nginxConfig.storage.content.enable or false) {
          "${name}-content" = storageLib.commonVolumes.data {
            name = "${name}-content";
            size = nginxConfig.storage.content.size or "5Gi";
            provider = nginxConfig.storage.provider or storageConfig.defaultProvider;
          };
        };

      # Create secrets if needed
      secrets = lib.optionalAttrs (nginxConfig.tls.enable or false && !nginxConfig.tls.useExisting) {
        "${name}-tls" = secretsLib.commonSecrets.tls {
          name = "${name}-tls";
          provider = nginxConfig.secrets.provider or secretsConfig.defaultProvider;
          certificate = nginxConfig.tls.certificate or "";
          key = nginxConfig.tls.key or "";
        };
      };

    in
    {
      applications."nginx-${name}" = {
        inherit namespace;
        createNamespace = nginxConfig.createNamespace or false;

        resources = {
          # Persistent Volume Claims
          persistentVolumeClaims = volumes;

          # Secrets
          secrets = lib.filterAttrs (name: secret: secret != null) secrets;

          # ConfigMap for nginx configuration
          configMaps."${name}-config" = {
            data = {
              "nginx.conf" = generateNginxConfig {
                inherit name;
                sites = nginxConfig.sites or { };
                upstreams = nginxConfig.upstreams or { };
                globalConfig = nginxConfig.globalConfig or { };
              };
            }
            // (nginxConfig.staticFiles or { });
          };

          # Deployment
          deployments."${name}" = {
            spec = {
              replicas = replicas;
              selector.matchLabels = {
                app = "nginx";
                instance = name;
              };
              template = {
                metadata.labels = {
                  app = "nginx";
                  instance = name;
                };
                spec = {
                  securityContext = {
                    runAsNonRoot = false; # nginx needs to bind to port 80
                    fsGroup = 101; # nginx group
                  };
                  containers = [
                    {
                      name = "nginx";
                      image = image;
                      ports = [
                        { containerPort = 80; }
                      ]
                      ++ lib.optional (nginxConfig.tls.enable or false) { containerPort = 443; };

                      volumeMounts = [
                        {
                          name = "config";
                          mountPath = "/etc/nginx/nginx.conf";
                          subPath = "nginx.conf";
                        }
                      ]
                      ++ lib.optionals (nginxConfig.storage.content.enable or false) [
                        {
                          name = "content";
                          mountPath = "/usr/share/nginx/html";
                        }
                      ]
                      ++ lib.optionals (nginxConfig.tls.enable or false) [
                        {
                          name = "tls";
                          mountPath = "/etc/nginx/ssl";
                          readOnly = true;
                        }
                      ]
                      ++ (nginxConfig.extraVolumeMounts or [ ]);

                      livenessProbe = {
                        httpGet = {
                          path = "/";
                          port = 80;
                        };
                        initialDelaySeconds = 30;
                        periodSeconds = 10;
                      };

                      readinessProbe = {
                        httpGet = {
                          path = "/";
                          port = 80;
                        };
                        initialDelaySeconds = 5;
                        periodSeconds = 5;
                      };

                      resources = {
                        requests = {
                          cpu = nginxConfig.resources.requests.cpu or "10m";
                          memory = nginxConfig.resources.requests.memory or "16Mi";
                        };
                        limits = {
                          cpu = nginxConfig.resources.limits.cpu or "100m";
                          memory = nginxConfig.resources.limits.memory or "64Mi";
                        };
                      };
                    }
                  ];

                  volumes = [
                    {
                      name = "config";
                      configMap.name = "${name}-config";
                    }
                  ]
                  ++ lib.optionals (nginxConfig.storage.content.enable or false) [
                    {
                      name = "content";
                      persistentVolumeClaim.claimName = "${name}-content-pvc";
                    }
                  ]
                  ++ lib.optionals (nginxConfig.tls.enable or false) [
                    {
                      name = "tls";
                      secret.secretName =
                        if nginxConfig.tls.useExisting then nginxConfig.tls.existingSecret else "${name}-tls";
                    }
                  ]
                  ++ (nginxConfig.extraVolumes or [ ]);
                };
              };
            };
          };

          # Service
          services."${name}" = {
            spec = {
              selector = {
                app = "nginx";
                instance = name;
              };
              ports = [
                {
                  name = "http";
                  port = 80;
                  targetPort = 80;
                }
              ]
              ++ lib.optional (nginxConfig.tls.enable or false) {
                name = "https";
                port = 443;
                targetPort = 443;
              };
            };
          };

          # Ingress (if configured)
          ingresses = lib.optionalAttrs (nginxConfig.ingress.enable or false) {
            "${name}" = {
              metadata.annotations = {
                "nginx.ingress.kubernetes.io/ssl-redirect" = toString (nginxConfig.ingress.tls or true);
              }
              // (nginxConfig.ingress.annotations or { });
              spec = {
                ingressClassName = nginxConfig.ingress.className or "nginx";
                tls = lib.optional (nginxConfig.ingress.tls or true) {
                  secretName = "${name}-tls";
                  hosts = [ nginxConfig.ingress.host ];
                };
                rules = [
                  {
                    host = nginxConfig.ingress.host;
                    http.paths = [
                      {
                        path = "/";
                        pathType = "Prefix";
                        backend.service = {
                          name = name;
                          port.number = 80;
                        };
                      }
                    ];
                  }
                ];
              };
            };
          };

          # ServiceMonitor for Prometheus (if enabled)
          serviceMonitors = lib.optionalAttrs (nginxConfig.monitoring.enabled or false) {
            "${name}" = {
              metadata.labels = {
                app = "nginx";
                instance = name;
              };
              spec = {
                selector.matchLabels = {
                  app = "nginx";
                  instance = name;
                };
                endpoints = [
                  {
                    port = "http";
                    path = "/nginx_status";
                    interval = "30s";
                  }
                ];
              };
            };
          };
        };
      };
    };

in
{
  options.webservers.nginx = with lib; {
    deployments = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable this nginx deployment";
            };

            namespace = mkOption {
              type = types.str;
              default = "nginx";
              description = "Kubernetes namespace for the deployment";
            };

            createNamespace = mkOption {
              type = types.bool;
              default = false;
              description = "Create the namespace if it doesn't exist";
            };

            image = mkOption {
              type = types.str;
              default = "nginx:1.25.4-alpine";
              description = "nginx Docker image to use";
            };

            replicas = mkOption {
              type = types.int;
              default = 1;
              description = "Number of nginx replicas";
            };

            sites = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    port = mkOption {
                      type = types.int;
                      default = 80;
                      description = "Port to listen on";
                    };

                    serverName = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Server name (domain)";
                    };

                    root = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Document root path";
                    };

                    index = mkOption {
                      type = types.str;
                      default = "index.html index.htm";
                      description = "Index files";
                    };

                    defaultServer = mkOption {
                      type = types.bool;
                      default = false;
                      description = "Make this the default server";
                    };

                    locations = mkOption {
                      type = types.listOf (
                        types.submodule {
                          options = {
                            path = mkOption {
                              type = types.str;
                              description = "Location path";
                            };

                            proxyPass = mkOption {
                              type = types.nullOr types.str;
                              default = null;
                              description = "Proxy pass URL";
                            };

                            tryFiles = mkOption {
                              type = types.nullOr types.str;
                              default = null;
                              description = "Try files directive";
                            };

                            return = mkOption {
                              type = types.nullOr types.str;
                              default = null;
                              description = "Return directive";
                            };

                            alias = mkOption {
                              type = types.nullOr types.str;
                              default = null;
                              description = "Alias directive";
                            };

                            extraConfig = mkOption {
                              type = types.str;
                              default = "";
                              description = "Extra location configuration";
                            };
                          };
                        }
                      );
                      default = [ ];
                      description = "Location blocks";
                    };

                    extraConfig = mkOption {
                      type = types.str;
                      default = "";
                      description = "Extra server configuration";
                    };
                  };
                }
              );
              default = { };
              description = "Site configurations";
            };

            upstreams = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    servers = mkOption {
                      type = types.listOf types.str;
                      description = "Upstream servers";
                    };

                    method = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = "Load balancing method";
                    };

                    keepalive = mkOption {
                      type = types.nullOr types.int;
                      default = null;
                      description = "Keepalive connections";
                    };
                  };
                }
              );
              default = { };
              description = "Upstream configurations";
            };

            globalConfig = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Global nginx configuration overrides";
            };

            staticFiles = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Static files to include in the ConfigMap";
            };

            storage = {
              provider = mkOption {
                type = types.enum [
                  "local"
                  "ceph"
                  "longhorn"
                ];
                default = storageConfig.defaultProvider;
                description = "Storage provider to use";
              };

              config = {
                enable = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable persistent storage for configuration";
                };

                size = mkOption {
                  type = types.str;
                  default = "1Gi";
                  description = "Size of configuration storage";
                };
              };

              content = {
                enable = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable persistent storage for content";
                };

                size = mkOption {
                  type = types.str;
                  default = "5Gi";
                  description = "Size of content storage";
                };
              };
            };

            tls = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable TLS/SSL";
              };

              useExisting = mkOption {
                type = types.bool;
                default = false;
                description = "Use existing TLS secret";
              };

              existingSecret = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Name of existing TLS secret";
              };

              certificate = mkOption {
                type = types.str;
                default = "";
                description = "TLS certificate content";
              };

              key = mkOption {
                type = types.str;
                default = "";
                description = "TLS private key content";
              };
            };

            secrets = {
              provider = mkOption {
                type = types.enum [
                  "internal"
                  "external"
                ];
                default = secretsConfig.defaultProvider;
                description = "Secrets provider to use";
              };
            };

            ingress = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable ingress";
              };

              host = mkOption {
                type = types.str;
                description = "Ingress hostname";
              };

              className = mkOption {
                type = types.str;
                default = "nginx";
                description = "Ingress class name";
              };

              tls = mkOption {
                type = types.bool;
                default = true;
                description = "Enable TLS for ingress";
              };

              annotations = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = "Ingress annotations";
              };
            };

            monitoring = {
              enabled = mkOption {
                type = types.bool;
                default = false;
                description = "Enable Prometheus monitoring";
              };
            };

            resources = {
              requests = {
                cpu = mkOption {
                  type = types.str;
                  default = "10m";
                  description = "CPU request";
                };

                memory = mkOption {
                  type = types.str;
                  default = "16Mi";
                  description = "Memory request";
                };
              };

              limits = {
                cpu = mkOption {
                  type = types.str;
                  default = "100m";
                  description = "CPU limit";
                };

                memory = mkOption {
                  type = types.str;
                  default = "64Mi";
                  description = "Memory limit";
                };
              };
            };

            extraVolumes = mkOption {
              type = types.listOf types.anything;
              default = [ ];
              description = "Extra volumes to mount";
            };

            extraVolumeMounts = mkOption {
              type = types.listOf types.anything;
              default = [ ];
              description = "Extra volume mounts";
            };
          };
        }
      );
      default = { };
      description = "nginx deployment configurations";
    };
  };

  config = {
    # Generate applications for each enabled nginx deployment
    inherit
      (lib.foldl' (
        acc: name:
        let
          nginxConfig = cfg.deployments.${name};
        in
        if nginxConfig.enable then acc // (createNginxDeployment name nginxConfig) else acc
      ) { } (lib.attrNames cfg.deployments))
      ;

    # Add monitoring rules if any nginx deployment has monitoring enabled
    monitoring.prometheus.rules =
      lib.mkIf (lib.any (d: d.monitoring.enabled or false) (lib.attrValues cfg.deployments))
        [
          {
            name = "nginx";
            rules = [
              {
                alert = "NginxDown";
                expr = ''
                  up{job=~".*nginx.*"} == 0
                '';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "nginx is down";
                  description = "nginx instance {{ $labels.instance }} has been down for more than 5 minutes";
                };
              }

              {
                alert = "NginxHighRequestRate";
                expr = ''
                  rate(nginx_http_requests_total[5m]) > 100
                '';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "nginx high request rate";
                  description = "nginx instance {{ $labels.instance }} is receiving {{ $value }} requests per second";
                };
              }

              {
                alert = "NginxHighErrorRate";
                expr = ''
                  rate(nginx_http_requests_total{status=~"4..|5.."}[5m]) / rate(nginx_http_requests_total[5m]) > 0.1
                '';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "nginx high error rate";
                  description = "nginx instance {{ $labels.instance }} has error rate of {{ $value }}";
                };
              }
            ];
          }
        ];
  };
}
