{ lib, charts, ... }@args:
{
  imports = [
    # ./argocd
    ./cilium
    # ./storage
    # ./secrets
    # ./nginx-ingress
    # ./external-dns
    # ./external-secrets # Keep for backward compatibility, but new external secrets config in ./secrets/external
    # ./prometheus
    # ./grafana
    # ./nextcloud
    # ./passbolt
    # ./librebooking
    # ./bookstack
    # ./keycloak
    # ./acme-dns
    # ./zammad
    # ./cert-manager
    # ./github-runner
    # ./samba
    # ./coredns
    # ./uptime-kuma
    # ./docker-registry
    # ./ceph-csi  # Moved to ./storage/ceph
    ./test-module
  ];
  options = with lib; {
    kconf.core.baseDomain = mkOption {
      type = types.str;
    };
  };

  config = {
    nixidy = {
      defaults = {
        syncPolicy = {
          autoSync = {
            enable = true;
            prune = true;
            selfHeal = true;
          };
        };

        helm.transformer = map (
          lib.kube.removeLabels [
            "app.kubernetes.io/managed-by"
            "app.kubernetes.io/version"
            "helm.sh/chart"
          ]
        );
      };
    };
  };
}
