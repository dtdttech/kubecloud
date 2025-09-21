{lib, charts, ...}@args: {
  imports = [
    # ./argocd
    # ./cilium
    ./storage
    ./traefik
    ./external-secrets
    ./prometheus
    ./grafana
    # ./nextcloud
    ./passbolt
    ./librebooking
    ./bookstack
    ./keycloak
    ./acme-dns
    ./zammad
    # ./ceph-csi  # Moved to ./storage/ceph
  ];
  options = with lib; {
    networking.domain = mkOption {
      type = types.str;
    };
    # Allow unknown 'services' option to satisfy generated modules
    # services = mkOption {
    #   type = types.attrsOf types.anything;
    #   default = {};
    #   description = "Dummy catch-all for generated services option.";
    # };
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

        helm.transformer = map (lib.kube.removeLabels [
          "app.kubernetes.io/managed-by"
          "app.kubernetes.io/version"
          "helm.sh/chart"
        ]);
      };
    };
  };
}
