{lib, ...}: {
  imports = [
    ./cilium
    ./traefik
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
      target.repository = "https://github.com/arnarg/cluster.git";

      chartsDir = ../charts;

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
