{
  lib,
  config,
  charts,
  secretsLib,
  secretsConfig,
  ...
}:

let
  cfg = config.ci.github-runner;
  namespace = cfg.namespace;
  values = lib.attrsets.recursiveUpdate {
    # Controller configuration
    controller = {
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
          memory = "64Mi";
        };
        limits = {
          cpu = "100m";
          memory = "256Mi";
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
      metrics = {
        enabled = cfg.monitoring.enabled;
        port = 8080;
      };

      # GitHub auth
      githubConfigUrl = cfg.githubConfigUrl;
      githubConfigSecret = cfg.githubConfigSecret;
    };

    # RBAC
    rbac = {
      create = true;
    };

    # Service account
    serviceAccount = {
      create = true;
      name = null;
      annotations = cfg.serviceAccount.annotations or { };
    };

  } cfg.values;

  # Create runner scale sets based on configuration
  runnerScaleSets = lib.mapAttrs' (name: scaleSet: {
    name = name;
    value = {
      apiVersion = "actions.summerwind.dev/v1alpha1";
      kind = "RunnerScaleSet";
      metadata = {
        inherit name;
        namespace = namespace;
        labels = (secretsConfig.commonLabels or { }) // {
          "app.kubernetes.io/component" = "runner-scale-set";
          "app.kubernetes.io/name" = "github-runner";
        };
        annotations = secretsConfig.commonAnnotations or { };
      };
      spec = {
        githubConfigUrl = scaleSet.githubConfigUrl or cfg.githubConfigUrl;
        githubConfigSecret = scaleSet.githubConfigSecret or cfg.githubConfigSecret;

        # Runner template
        template = {
          spec = {
            repo = scaleSet.repository or null;
            org = scaleSet.organization or null;
            labels =
              scaleSet.labels or [
                "self-hosted"
                "linux"
                "x64"
              ];
            group = scaleSet.group or "default";

            # Container configuration
            container = {
              image =
                scaleSet.image or {
                  repository = "summerwind/actions-runner";
                  tag = "v2.328.0";
                  pullPolicy = "IfNotPresent";
                };

              resources =
                scaleSet.resources or {
                  requests = {
                    cpu = "100m";
                    memory = "256Mi";
                  };
                  limits = {
                    cpu = "1000m";
                    memory = "2Gi";
                  };
                };

              env = scaleSet.env or [ ];
            };

            # Workdir volume
            workDir = {
              emptyDir = { };
            };

            # Docker volume configuration (if needed)
            dockerdWithinRunnerContainer = scaleSet.dockerdWithinRunnerContainer or false;

            # Security context
            securityContext =
              scaleSet.securityContext or {
                runAsNonRoot = true;
                seccompProfile = {
                  type = "RuntimeDefault";
                };
              };

            # Service account
            serviceAccountName = scaleSet.serviceAccountName or "default";

            # Node selector and tolerations
            nodeSelector = scaleSet.nodeSelector or { };
            tolerations = scaleSet.tolerations or [ ];

            # Affinity
            affinity = scaleSet.affinity or { };
          };
        };

        # Scale set configuration
        minRunners = scaleSet.minRunners or 1;
        maxRunners = scaleSet.maxRunners or 3;
        desiredRunners = scaleSet.desiredRunners or 1;

        # Metrics and monitoring
        metricsPort = scaleSet.metricsPort or 8080;

        # Stateful set configuration
        statefulSetConfiguration = scaleSet.statefulSetConfiguration or { };

        # Ephemeral runner settings
        ephemeral = scaleSet.ephemeral or true;

        # Graceful stopping timeout
        gracefulStoppingTimeout = scaleSet.gracefulStoppingTimeout or 3600;

        # Maximum runner duration
        maxRunnerDuration = scaleSet.maxRunnerDuration or 86400;
      };
    };
  }) cfg.scaleSets;

in
{
  options.ci.github-runner = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable GitHub Actions runner controller";
    };

    namespace = mkOption {
      type = types.str;
      default = "github-runner";
      description = "Namespace for GitHub runner";
    };

    githubConfigUrl = mkOption {
      type = types.str;
      description = "GitHub organization or enterprise URL";
      example = "https://github.com/my-org";
    };

    githubConfigSecret = mkOption {
      type = types.str;
      default = "github-runner-secret";
      description = "Name of secret containing GitHub PAT or App credentials";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Helm values for GitHub runner controller";
    };

    scaleSets = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            repository = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "GitHub repository name (format: owner/repo)";
              example = "my-org/my-repo";
            };

            organization = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "GitHub organization name";
              example = "my-org";
            };

            labels = mkOption {
              type = types.listOf types.str;
              default = [
                "self-hosted"
                "linux"
                "x64"
              ];
              description = "Labels for the runners";
            };

            group = mkOption {
              type = types.str;
              default = "default";
              description = "Runner group name";
            };

            minRunners = mkOption {
              type = types.int;
              default = 1;
              description = "Minimum number of runners";
            };

            maxRunners = mkOption {
              type = types.int;
              default = 3;
              description = "Maximum number of runners";
            };

            desiredRunners = mkOption {
              type = types.int;
              default = 1;
              description = "Desired number of runners";
            };

            image = mkOption {
              type = types.nullOr (
                types.submodule {
                  options = {
                    repository = mkOption {
                      type = types.str;
                      default = "summerwind/actions-runner";
                      description = "Runner image repository";
                    };

                    tag = mkOption {
                      type = types.str;
                      default = "v2.328.0";
                      description = "Runner image tag";
                    };

                    pullPolicy = mkOption {
                      type = types.enum [
                        "Always"
                        "IfNotPresent"
                        "Never"
                      ];
                      default = "IfNotPresent";
                      description = "Image pull policy";
                    };
                  };
                }
              );
              default = null;
              description = "Custom runner image";
            };

            resources = mkOption {
              type = types.nullOr (
                types.submodule {
                  options = {
                    requests = {
                      cpu = mkOption {
                        type = types.str;
                        default = "100m";
                        description = "CPU request";
                      };
                      memory = mkOption {
                        type = types.str;
                        default = "256Mi";
                        description = "Memory request";
                      };
                    };
                    limits = {
                      cpu = mkOption {
                        type = types.str;
                        default = "1000m";
                        description = "CPU limit";
                      };
                      memory = mkOption {
                        type = types.str;
                        default = "2Gi";
                        description = "Memory limit";
                      };
                    };
                  };
                }
              );
              default = null;
              description = "Resource limits and requests for runners";
            };

            env = mkOption {
              type = types.listOf (
                types.submodule {
                  options = {
                    name = mkOption {
                      type = types.str;
                      description = "Environment variable name";
                    };
                    value = mkOption {
                      type = types.str;
                      description = "Environment variable value";
                    };
                    valueFrom = mkOption {
                      type = types.nullOr types.attrs;
                      default = null;
                      description = "Value from secret or config map";
                    };
                  };
                }
              );
              default = [ ];
              description = "Environment variables for runners";
            };

            securityContext = mkOption {
              type = types.attrsOf types.anything;
              default = {
                runAsNonRoot = true;
                seccompProfile = {
                  type = "RuntimeDefault";
                };
              };
              description = "Security context for runner pods";
            };

            nodeSelector = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Node selector for runner pods";
            };

            tolerations = mkOption {
              type = types.listOf types.attrs;
              default = [ ];
              description = "Tolerations for runner pods";
            };

            affinity = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = "Affinity rules for runner pods";
            };

            serviceAccountName = mkOption {
              type = types.str;
              default = "default";
              description = "Service account name for runners";
            };

            ephemeral = mkOption {
              type = types.bool;
              default = true;
              description = "Use ephemeral runners";
            };

            dockerdWithinRunnerContainer = mkOption {
              type = types.bool;
              default = false;
              description = "Run Docker within the runner container";
            };

            metricsPort = mkOption {
              type = types.int;
              default = 8080;
              description = "Metrics port for the scale set";
            };

            gracefulStoppingTimeout = mkOption {
              type = types.int;
              default = 3600;
              description = "Graceful stopping timeout in seconds";
            };

            maxRunnerDuration = mkOption {
              type = types.int;
              default = 86400;
              description = "Maximum runner duration in seconds";
            };

            statefulSetConfiguration = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = "StatefulSet configuration";
            };
          };
        }
      );
      default = { };
      description = "Runner scale set configurations";
      example = {
        default = {
          repository = "my-org/my-repo";
          labels = [
            "self-hosted"
            "linux"
            "x64"
            "docker"
          ];
          minRunners = 1;
          maxRunners = 5;
          desiredRunners = 2;
        };
      };
    };

    serviceAccount = {
      annotations = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Annotations for the service account";
      };
    };

    monitoring = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable monitoring for GitHub runner controller";
      };

      serviceMonitor = {
        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable ServiceMonitor for metrics collection";
        };

        interval = mkOption {
          type = types.str;
          default = "30s";
          description = "Scraping interval";
        };
      };
    };

    networkPolicies = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network policies";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ];

    applications.github-runner = {
      inherit namespace;
      createNamespace = true;

      helm.releases.github-runner = {
        inherit values;
        chart = charts."actions-runner-controller".actions-runner-controller;
      };

      resources = {
        # Create runner scale sets
        resources = runnerScaleSets;

        # Network policies
        networkPolicies = lib.mkIf cfg.networkPolicies.enabled {
          github-runner-controller = {
            metadata = {
              name = "github-runner-controller";
              namespace = namespace;
            };
            spec = {
              podSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "actions-runner-controller";
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
                      namespaceSelector = { };
                    }
                  ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 9443;
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
                # Allow HTTPS to GitHub API
                {
                  to = [
                    {
                      namespaceSelector = { };
                    }
                  ];
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

          github-runner-listener = {
            metadata = {
              name = "github-runner-listener";
              namespace = namespace;
            };
            spec = {
              podSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "gha-runner-scale-set";
                  "app.kubernetes.io/component" = "listener";
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
                      port = 8080;
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
                # Allow HTTPS to GitHub API
                {
                  to = [ ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 443;
                    }
                  ];
                }
              ];
            };
          };
        };

        # ServiceMonitor for metrics
        serviceMonitor = lib.mkIf (cfg.monitoring.enabled && cfg.monitoring.serviceMonitor.enabled) {
          github-runner-controller = {
            metadata = {
              name = "github-runner-controller";
              namespace = namespace;
              labels = {
                "app.kubernetes.io/name" = "github-runner";
                "app.kubernetes.io/component" = "controller";
              };
            };
            spec = {
              selector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "actions-runner-controller";
                  "app.kubernetes.io/component" = "controller";
                };
              };
              endpoints = [
                {
                  port = "metrics";
                  interval = cfg.monitoring.serviceMonitor.interval;
                  path = "/metrics";
                }
              ];
            };
          };
        };
      };
    };
  };
}
