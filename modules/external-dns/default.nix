{
  lib,
  config,
  charts,
  ...
}:
let
  cfg = config.networking.external-dns;

  namespace = "external-dns";
in
{
  options.networking.external-dns = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable external-dns for DNS record management";
    };

    domainFilters = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of domain filters for external-dns";
    };

    provider = mkOption {
      type = types.enum [
        "coredns"
        "cloudflare"
        "route53"
      ];
      default = "coredns";
      description = "DNS provider for external-dns";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.external-dns = {
      inherit namespace;
      createNamespace = true;

      helm.releases.external-dns = {
        values = lib.attrsets.recursiveUpdate {
          # External-dns configuration
          provider = cfg.provider;
          domainFilters = cfg.domainFilters;
          sources = [
            "service"
            "ingress"
          ];

          # CoreDNS provider specific configuration
          coredns = {
            # When using CoreDNS as provider, external-dns creates records in CoreDNS
            # and CoreDNS serves them directly
          };

          # Policy for how to handle DNS records
          policy = "sync"; # sync external-dns records with DNS

          # Interval for checking DNS changes
          interval = "1m";

          # Don't process annotations on the same resource more than once
          txtOwnerId = "external-dns";

          # Resources to monitor
          service = {
            # Don't publish services without an annotation
            publishInternalServices = false;
          };

          # Log level
          logLevel = "info";

          # Metrics
          metrics = {
            enabled = true;
            port = 7979;
            serviceMonitor = {
              enabled = true;
              additionalLabels.release = "prometheus";
            };
          };

          # RBAC configuration
          rbac = {
            create = true;
          };

          # Security context
          securityContext = {
            fsGroup = 65534;
            runAsUser = 65534;
            runAsNonRoot = true;
            readOnlyRootFilesystem = true;
          };

          # Resources
          resources = {
            requests = {
              cpu = "50m";
              memory = "50Mi";
            };
            limits = {
              cpu = "200m";
              memory = "128Mi";
            };
          };
        } cfg.values;

        chart = charts.external-dns.external-dns;
      };

      # Network policies for external-dns
      resources = {
        networkPolicies.external-dns.spec = {
          podSelector.matchLabels."app.kubernetes.io/name" = "external-dns";
          policyTypes = [
            "Ingress"
            "Egress"
          ];

          # Allow ingress from monitoring
          ingress = [
            {
              from = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "monitoring";
                }
              ];
              ports = [
                {
                  protocol = "TCP";
                  port = 7979;
                }
              ];
            }
          ];

          # Allow egress to DNS servers and Kubernetes API
          egress = [
            {
              toPorts = [
                {
                  ports = [
                    {
                      port = "53";
                      protocol = "UDP";
                    }
                    {
                      port = "53";
                      protocol = "TCP";
                    }
                  ];
                  rules.dns = [ { matchPattern = "*"; } ];
                }
              ];
            }
            {
              toEndpoints = [
                {
                  matchLabels = {
                    "k8s:io.kubernetes.pod.namespace" = "kube-system";
                    "k8s:k8s-app" = "kube-dns";
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
