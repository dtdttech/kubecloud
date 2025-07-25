{lib, charts, ...}@args: {
  imports = [
    # ./argocd
    ./cilium
    ./traefik
    ./eso
    ./prometheus
  ];
  options = with lib; {
    networking.domain = mkOption {
      type = types.str;
    };
    # Allow unknown 'services' option to satisfy generated modules
    services = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Dummy catch-all for generated services option.";
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

        helm.transformer = map (lib.kube.removeLabels [
          "app.kubernetes.io/managed-by"
          "app.kubernetes.io/version"
          "helm.sh/chart"
        ]);
      };
    };
  };
}
