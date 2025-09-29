# Option 1: Use a different namespace (recommended)
{
  lib,
  config,
  charts,
  ...
}:
let
  cfg = config.services.argocd;
  namespace = "argocd";
  values = lib.attrsets.recursiveUpdate {
    server.ingress = {
      inherit (config.networking.nginx-ingress) ingressClassName;
      enabled = true;
      hostname = "argocd.${config.networking.domain}";
    };
    repoServer.dnsConfig.options = [
      {
        name = "ndots";
        value = "1";
      }
    ];
    global.networkPolicy.create = true;
  } cfg.values;
in
{
  options.services.argocd = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.argocd = {
      inherit namespace;
      helm.releases.argocd = {
        inherit values;
        chart = charts.argoproj.argo-cd;
      };
      resources = {
        # Allow ingress traffic from nginx to argocd-server.
        networkPolicies.allow-nginx-ingress = {
          apiVersion = "networking.k8s.io/v1";
          kind = "NetworkPolicy";
          metadata = {
            name = "allow-nginx-ingress";
            namespace = namespace;
          };
          spec = {
            podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
            policyTypes = [ "Ingress" ];
            ingress = [
              {
                from = [
                  {
                    namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "ingress-nginx";
                    podSelector.matchLabels."app.kubernetes.io/name" = "ingress-nginx";
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
          };
        };

        ciliumNetworkPolicies = {
          # Allow argocd-repo-server egress access to github.com
          allow-world-egress = {
            apiVersion = "cilium.io/v2";
            kind = "CiliumNetworkPolicy";
            metadata = {
              name = "allow-world-egress";
              namespace = namespace;
            };
            spec = {
              endpointSelector.matchLabels."app.kubernetes.io/name" = "argocd-repo-server";
              egress = [
                # Enable DNS proxying
                {
                  toEndpoints = [
                    {
                      matchLabels = {
                        "k8s:io.kubernetes.pod.namespace" = "kube-system";
                        "k8s:k8s-app" = "kube-dns";
                      };
                    }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "53";
                          protocol = "ANY";
                        }
                      ];
                      rules.dns = [
                        { matchPattern = "*"; }
                      ];
                    }
                  ];
                }
                # Allow HTTPS to github.com
                {
                  toFQDNs = [
                    { matchName = "github.com"; }
                  ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "443";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };
          };

          # Allow all ArgoCD pods to access kube-apiserver
          allow-kube-apiserver-egress = {
            apiVersion = "cilium.io/v2";
            kind = "CiliumNetworkPolicy";
            metadata = {
              name = "allow-kube-apiserver-egress";
              namespace = namespace;
            };
            spec = {
              endpointSelector.matchLabels."app.kubernetes.io/part-of" = "argocd";
              egress = [
                {
                  toEntities = [ "kube-apiserver" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = "6443";
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ];
            };
          };
        };
      };
    };
  };
}
