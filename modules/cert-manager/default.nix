{
  lib,
  config,
  charts,
  secretsLib,
  secretsConfig,
  ...
}:

let
  cfg = config.security.cert-manager;
  namespace = cfg.namespace;
  values = lib.attrsets.recursiveUpdate {
    # Install CRDs
    installCRDs = true;

    # Global settings
    global = {
      leaderElection = {
        namespace = namespace;
      };
    };

    # Controller configuration
    replicaCount = 1;
    strategy = {
      type = "RollingUpdate";
      rollingUpdate = {
        maxSurge = 0;
        maxUnavailable = 1;
      };
    };

    # Resources
    resources = {
      requests = {
        cpu = "10m";
        memory = "32Mi";
      };
      limits = {
        cpu = "100m";
        memory = "128Mi";
      };
    };

    # Security context
    securityContext = {
      runAsNonRoot = true;
      seccompProfile = {
        type = "RuntimeDefault";
      };
    };

    containerSecurityContext = {
      allowPrivilegeEscalation = false;
      capabilities = {
        drop = [ "ALL" ];
      };
      readOnlyRootFilesystem = true;
      runAsNonRoot = true;
    };

    # Pod disruption budget
    podDisruptionBudget = {
      enabled = true;
      minAvailable = 1;
    };

    # Monitoring
    prometheus = {
      enabled = cfg.monitoring.enabled;
      servicemonitor = {
        enabled = cfg.monitoring.enabled;
        prometheusInstance = "default";
        targetPort = 9402;
        path = "/metrics";
        interval = "60s";
        scrapeTimeout = "30s";
      };
    };

    # Webhook configuration
    webhook = {
      replicaCount = 1;
      strategy = {
        type = "RollingUpdate";
        rollingUpdate = {
          maxSurge = 0;
          maxUnavailable = 1;
        };
      };
      resources = {
        requests = {
          cpu = "10m";
          memory = "32Mi";
        };
        limits = {
          cpu = "100m";
          memory = "128Mi";
        };
      };
      securityContext = cfg.security.securityContext;
      containerSecurityContext = cfg.security.containerSecurityContext;
      podDisruptionBudget = {
        enabled = true;
        minAvailable = 1;
      };
    };

    # CA Injector configuration
    cainjector = {
      enabled = true;
      replicaCount = 1;
      strategy = {
        type = "RollingUpdate";
        rollingUpdate = {
          maxSurge = 0;
          maxUnavailable = 1;
        };
      };
      resources = {
        requests = {
          cpu = "10m";
          memory = "32Mi";
        };
        limits = {
          cpu = "100m";
          memory = "128Mi";
        };
      };
      securityContext = cfg.security.securityContext;
      containerSecurityContext = cfg.security.containerSecurityContext;
    };

  } cfg.values;

  # Create ClusterIssuers based on configuration
  clusterIssuers = lib.mapAttrs' (name: issuer: {
    name = name;
    value = {
      apiVersion = "cert-manager.io/v1";
      kind = "ClusterIssuer";
      metadata = {
        name = name;
        labels = (secretsConfig.commonLabels or { }) // {
          "app.kubernetes.io/component" = "cluster-issuer";
        };
        annotations = secretsConfig.commonAnnotations or { };
      };
      spec =
        if issuer.type == "acme" then
          {
            acme = {
              server = issuer.acme.server;
              email = issuer.acme.email;
              privateKeySecretRef = {
                name = "${name}-private-key";
              };
              solvers = issuer.acme.solvers;
            };
          }
        else if issuer.type == "ca" then
          {
            ca = {
              secretName = issuer.ca.secretName;
            };
          }
        else if issuer.type == "selfSigned" then
          {
            selfSigned = { };
          }
        else if issuer.type == "vault" then
          {
            vault = issuer.vault;
          }
        else
          throw "Unsupported issuer type: ${issuer.type}";
    };
  }) cfg.clusterIssuers;

in
{
  options.security.cert-manager = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable cert-manager for automatic certificate management";
    };

    namespace = mkOption {
      type = types.str;
      default = "cert-manager";
      description = "Namespace for cert-manager";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Helm values for cert-manager";
    };

    clusterIssuers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            type = mkOption {
              type = types.enum [
                "acme"
                "ca"
                "selfSigned"
                "vault"
              ];
              description = "Type of certificate issuer";
            };

            acme = mkOption {
              type = types.nullOr (
                types.submodule {
                  options = {
                    server = mkOption {
                      type = types.str;
                      default = "https://acme-v02.api.letsencrypt.org/directory";
                      description = "ACME server URL";
                    };

                    email = mkOption {
                      type = types.str;
                      description = "Email address for ACME registration";
                    };

                    solvers = mkOption {
                      type = types.listOf types.anything;
                      default = [ ];
                      description = "ACME challenge solvers";
                    };
                  };
                }
              );
              default = null;
              description = "ACME issuer configuration";
            };

            ca = mkOption {
              type = types.nullOr (
                types.submodule {
                  options = {
                    secretName = mkOption {
                      type = types.str;
                      description = "Name of the secret containing CA certificate and key";
                    };
                  };
                }
              );
              default = null;
              description = "CA issuer configuration";
            };

            vault = mkOption {
              type = types.nullOr types.anything;
              default = null;
              description = "Vault issuer configuration";
            };
          };
        }
      );
      default = { };
      description = "ClusterIssuer configurations";
      example = {
        letsencrypt-prod = {
          type = "acme";
          acme = {
            server = "https://acme-v02.api.letsencrypt.org/directory";
            email = "admin@example.com";
            solvers = [
              {
                http01 = {
                  ingress = {
                    class = "nginx";
                  };
                };
              }
            ];
          };
        };
      };
    };

    defaultIssuer = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default ClusterIssuer to use for certificates";
    };

    security = {
      securityContext = mkOption {
        type = types.attrsOf types.anything;
        default = {
          runAsNonRoot = true;
          seccompProfile = {
            type = "RuntimeDefault";
          };
        };
        description = "Pod security context for cert-manager components";
      };

      containerSecurityContext = mkOption {
        type = types.attrsOf types.anything;
        default = {
          allowPrivilegeEscalation = false;
          capabilities = {
            drop = [ "ALL" ];
          };
          readOnlyRootFilesystem = true;
          runAsNonRoot = true;
        };
        description = "Container security context for cert-manager components";
      };

      networkPolicies = {
        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable network policies for cert-manager";
        };
      };
    };

    monitoring = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable monitoring for cert-manager";
      };

      alerts = {
        certificateExpiry = mkOption {
          type = types.bool;
          default = true;
          description = "Alert on certificate expiry";
        };

        certificateRenewalFailure = mkOption {
          type = types.bool;
          default = true;
          description = "Alert on certificate renewal failures";
        };
      };
    };

    dns = {
      providers = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              type = mkOption {
                type = types.enum [
                  "cloudflare"
                  "route53"
                  "cloudDNS"
                  "azureDNS"
                  "digitalocean"
                ];
                description = "DNS provider type";
              };

              secretName = mkOption {
                type = types.str;
                description = "Name of secret containing DNS provider credentials";
              };

              config = mkOption {
                type = types.attrsOf types.anything;
                default = { };
                description = "Provider-specific configuration";
              };
            };
          }
        );
        default = { };
        description = "DNS provider configurations for DNS-01 challenges";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ];

    applications.cert-manager = {
      inherit namespace;
      createNamespace = true;

      helm.releases.cert-manager = {
        inherit values;
        chart = charts.jetstack.cert-manager;
      };

      resources = {
        # Network policies for cert-manager
        networkPolicies = lib.mkIf cfg.security.networkPolicies.enabled {
          cert-manager-controller = {
            metadata = {
              name = "cert-manager-controller";
              namespace = namespace;
            };
            spec = {
              podSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "cert-manager";
                  "app.kubernetes.io/component" = "controller";
                };
              };
              policyTypes = [
                "Ingress"
                "Egress"
              ];
              ingress = [
                {
                  from = [
                    {
                      podSelector = {
                        matchLabels = {
                          "app.kubernetes.io/name" = "cert-manager";
                          "app.kubernetes.io/component" = "webhook";
                        };
                      };
                    }
                  ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 9402;
                    }
                  ];
                }
              ];
              egress = [
                # Allow DNS resolution
                {
                  to = [
                    {
                      namespaceSelector = {
                        matchLabels = {
                          "kubernetes.io/metadata.name" = "kube-system";
                        };
                      };
                      podSelector = {
                        matchLabels = {
                          "k8s-app" = "kube-dns";
                        };
                      };
                    }
                  ];
                  ports = [
                    {
                      protocol = "UDP";
                      port = 53;
                    }
                  ];
                }
                # Allow HTTPS to ACME servers
                {
                  to = [ ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 443;
                    }
                  ];
                }
                # Allow access to Kubernetes API
                {
                  to = [ ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 6443;
                    }
                  ];
                }
              ];
            };
          };

          cert-manager-webhook = {
            metadata = {
              name = "cert-manager-webhook";
              namespace = namespace;
            };
            spec = {
              podSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "cert-manager";
                  "app.kubernetes.io/component" = "webhook";
                };
              };
              policyTypes = [
                "Ingress"
                "Egress"
              ];
              ingress = [
                {
                  from = [
                    {
                      namespaceSelector = { };
                    }
                  ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 10250;
                    }
                  ];
                }
              ];
              egress = [
                # Allow DNS resolution
                {
                  to = [
                    {
                      namespaceSelector = {
                        matchLabels = {
                          "kubernetes.io/metadata.name" = "kube-system";
                        };
                      };
                      podSelector = {
                        matchLabels = {
                          "k8s-app" = "kube-dns";
                        };
                      };
                    }
                  ];
                  ports = [
                    {
                      protocol = "UDP";
                      port = 53;
                    }
                  ];
                }
                # Allow access to Kubernetes API
                {
                  to = [ ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 6443;
                    }
                  ];
                }
              ];
            };
          };
        };
      };
    };

    # TODO: Create ClusterIssuer resources manually after understanding nixidy structure
    # applications.cert-manager.resources.clusterIssuers = clusterIssuers;

    # Add default issuer annotation to ingresses if configured
    # This would typically be done by users in their ingress configurations
    # but we can provide a convenience option

    # Monitoring configuration - disabled for now
    monitoring.prometheus.rules = [ ];
  };
}
