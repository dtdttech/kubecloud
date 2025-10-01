{
  lib,
  config,
  charts,
  ...
}:

let
  cfg = config.networking.coredns;

  namespace = "coredns";

  values = {
    # CoreDNS image configuration
    image = {
      repository = "coredns/coredns";
      tag = "1.11.1";
      pullPolicy = "IfNotPresent";
    };

    # CoreDNS configuration
    isClusterService = true;

    # Server configuration
    servers = [
      {
        port = 53;
        zones = [
          {
            zone = ".";
            scheme = "";
            useTCP = true;
          }
        ];
        plugins = [
          {
            name = "errors";
            config = {
              # No configuration needed for errors plugin
            };
          }
          {
            name = "health";
            config = {
              lameduck = "5s";
            };
          }
          {
            name = "ready";
          }
          {
            name = "prometheus";
            parameters = "0.0.0.0:9153";
          }
          {
            name = "forward";
            parameters = ". /etc/resolv.conf";
            config = {
              policy = "sequential";
              prefer_udp = true;
            };
          }
          {
            name = "cache";
            parameters = "30";
            config = {
              success = 9984;
              denial = 9984;
              prefetch = 1;
            };
          }
          {
            name = "loop";
          }
          {
            name = "reload";
          }
          {
            name = "loadbalance";
          }
        ];
      }
    ];

    # Service configuration
    serviceType = "ClusterIP";

    # ClusterIP configuration for DNS service
    clusterIP = "10.96.0.10";

    # Additional service annotations
    serviceAnnotations = {
      "prometheus.io/port" = "9153";
      "prometheus.io/scrape" = "true";
    };

    # Resource limits
    resources = {
      requests = {
        cpu = "100m";
        memory = "70Mi";
      };
      limits = {
        cpu = "1000m";
        memory = "170Mi";
      };
    };

    # Liveness and readiness probes
    livenessProbe = {
      enabled = true;
      httpGet = {
        path = "/health";
        port = 8080;
      };
      initialDelaySeconds = 60;
      timeoutSeconds = 5;
      failureThreshold = 5;
    };

    readinessProbe = {
      enabled = true;
      httpGet = {
        path = "/ready";
        port = 8181;
      };
      initialDelaySeconds = 0;
      timeoutSeconds = 5;
      failureThreshold = 5;
    };

    # Autoscaling configuration
    autoscaler = {
      enabled = false;
      minReplicas = 1;
      maxReplicas = 10;
      targetCPUUtilizationPercentage = 60;
      targetMemoryUtilizationPercentage = 80;
    };

    # Affinity and tolerations
    affinity = {
      podAntiAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = [
          {
            labelSelector = {
              matchExpressions = [
                {
                  key = "app.kubernetes.io/name";
                  operator = "In";
                  values = [ "coredns" ];
                }
              ];
            };
            topologyKey = "kubernetes.io/hostname";
          }
        ];
      };
    };

    tolerations = [
      {
        key = "CriticalAddonsOnly";
        operator = "Exists";
      }
      {
        key = "node-role.kubernetes.io/control-plane";
        effect = "NoSchedule";
      }
      {
        key = "node-role.kubernetes.io/master";
        effect = "NoSchedule";
      }
    ];

    # Node selector
    nodeSelector = {
      "kubernetes.io/os" = "linux";
    };

    # Priority class name
    priorityClassName = "system-cluster-critical";

    # Replicas count
    replicaCount = 2;
  }
  // cfg.values;
in
{
  options.networking.coredns = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable CoreDNS via Helm";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extra Helm values for CoreDNS";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.coredns = {
      inherit namespace;
      createNamespace = true;

      helm.releases.coredns = {
        chart = charts.coredns;
        inherit values;
      };
    };
  };
}
