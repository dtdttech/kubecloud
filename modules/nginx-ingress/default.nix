{
  lib,
  config,
  charts,
  ...
}:
let
  cfg = config.networking.nginx-ingress;

  namespace = "ingress-nginx";
  values = lib.attrsets.recursiveUpdate {
    # Controller configuration
    controller = {
      name = "controller";
      image = {
        repository = "registry.k8s.io/ingress-nginx/controller";
        tag = "v1.11.2";
        digest = "sha256:28b11ce69e5788dee65368ce55de76308cfea8fb6090e813d9a3c4a9022612cd";
        pullPolicy = "IfNotPresent";
      };
      ingressClassResource = {
        name = cfg.ingressClassName;
        enabled = true;
        default = true;
        controllerValue = "k8s.io/ingress-nginx";
      };
      service = {
        type = "LoadBalancer";
        externalTrafficPolicy = "Local";
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb";
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true";
        };
      };
      publishService = {
        enabled = true;
        pathOverride = "";
      };
      config = {
        # Global configuration snippets
        "global-static-annotations" = {
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
          "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true";
          "nginx.ingress.kubernetes.io/use-regex" = "true";
          "nginx.ingress.kubernetes.io/rewrite-target" = "/";
        };
        # Security headers
        "http-snippet" = ''
          more_set_headers "X-Frame-Options: SAMEORIGIN";
          more_set_headers "X-Content-Type-Options: nosniff";
          more_set_headers "X-XSS-Protection: 1; mode=block";
          more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
        '';
        # Rate limiting
        "limit-connections" = "100";
        "limit-rps" = "50";
        "limit-burst" = "100";
        # Client timeouts
        "proxy-connect-timeout" = "15";
        "proxy-send-timeout" = "60";
        "proxy-read-timeout" = "60";
        "client-body-buffer-size" = "100k";
        "client-body-timeout" = "60";
        "client-header-timeout" = "60";
        "keep-alive-timeout" = "60";
        "keep-alive-requests" = "1000";
        # SSL/TLS configuration
        "ssl-protocols" = "TLSv1.2 TLSv1.3";
        "ssl-ciphers" =
          "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
        "ssl-session-cache" = "shared:SSL:10m";
        "ssl-session-timeout" = "1d";
        "ssl-session-tickets" = "false";
        # Log format
        "log-format-upstream" =
          ''$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length $request_time [$proxy_upstream_name] [$proxy_upstream_addr] [$upstream_response_time] [$upstream_status] [$upstream_response_length]'';
        # Access log settings
        "enable-access-log-for-default-backend" = "true";
        "access-log-path" = "/var/log/nginx/access.log";
        "error-log-path" = "/var/log/nginx/error.log";
      };
      resources = {
        requests = {
          cpu = "100m";
          memory = "90Mi";
        };
        limits = {
          cpu = "500m";
          memory = "250Mi";
        };
      };
      # Enable Prometheus metrics
      metrics = {
        enabled = true;
        serviceMonitor = {
          enabled = true;
          additionalLabels = {
            release = "prometheus";
          };
        };
      };
      # Admission webhook
      admissionWebhooks = {
        enabled = true;
        objectSelector = {
          matchLabels = {
            "nginx-ingress.kubernetes.io/enable" = "true";
          };
        };
      };
      # Host network and daemon set options
      hostNetwork = false;
      hostPort = {
        enabled = false;
      };
      daemonset = {
        useHostPort = false;
      };
      # DNS policy
      dnsPolicy = "ClusterFirst";
      # Tolerations for control plane nodes
      tolerations = [
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
      # Security context
      containerSecurityContext = {
        allowPrivilegeEscalation = true;
        runAsUser = 101;
        runAsNonRoot = true;
        capabilities = {
          drop = [ "ALL" ];
          add = [ "NET_BIND_SERVICE" ];
        };
        seccompProfile = {
          type = "RuntimeDefault";
        };
      };
      # Pod security context
      podSecurityContext = {
        fsGroup = 101;
        runAsUser = 101;
        runAsNonRoot = true;
        seccompProfile = {
          type = "RuntimeDefault";
        };
      };
      # Service account
      serviceAccount = {
        create = true;
        name = "nginx-ingress";
        automountServiceAccountToken = true;
      };
      # RBAC
      rbac = {
        create = true;
        scope = false;
      };
    };
    # Default backend
    defaultBackend = {
      enabled = true;
      image = {
        repository = "registry.k8s.io/defaultbackend-amd64";
        tag = "1.5";
        pullPolicy = "IfNotPresent";
      };
      resources = {
        requests = {
          cpu = "10m";
          memory = "20Mi";
        };
        limits = {
          cpu = "20m";
          memory = "40Mi";
        };
      };
    };
    # TCP and UDP services
    tcp = { };
    udp = { };
    # Namespace
    namespace = namespace;
    # Replica count
    replicaCount = 2;
    # Update strategy
    updateStrategy = {
      type = "RollingUpdate";
      rollingUpdate = {
        maxUnavailable = 1;
        maxSurge = 1;
      };
    };
    # Min available pods for disruption budget
    minAvailable = 1;
    # Pod labels
    podLabels = {
      "app.kubernetes.io/name" = "ingress-nginx";
      "app.kubernetes.io/component" = "controller";
    };
    # Pod annotations
    podAnnotations = {
      "prometheus.io/scrape" = "true";
      "prometheus.io/port" = "10254";
      "prometheus.io/path" = "/metrics";
    };
  } cfg.values;
in
{
  options.networking.nginx-ingress = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable NGINX Ingress Controller";
    };
    ingressClassName = mkOption {
      type = types.str;
      default = "nginx";
      description = "Name of the ingress class to create";
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Additional values to pass to the Helm chart";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.nginx-ingress = {
      inherit namespace;
      createNamespace = true;

      helm.releases.nginx-ingress = {
        inherit values;
        chart = charts.ingress-nginx;
      };

      resources = {
        # Network policy allowing tailscale proxy to access ingress controller
        networkPolicies.allow-tailscale-ingress.spec = {
          podSelector.matchLabels."app.kubernetes.io/name" = "ingress-nginx";
          policyTypes = [ "Ingress" ];
          ingress = [
            {
              from = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "tailscale";
                  podSelector.matchLabels."tailscale.com/parent-resource" = "nginx-ingress";
                }
              ];
              ports = [
                {
                  protocol = "TCP";
                  port = 80;
                }
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
  };
}
