{ lib, config, charts, ... }:

let
  cfg = config.secrets.eso;
  namespace = "kube-system";
  values = cfg.values;
in {
  options.secrets.eso = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    applications.eso = {
      config = {
        inherit namespace;

        helm.releases.eso = {
          inherit values;
          chart = charts.external-secrets.external-secrets;
        };

        resources.externalSecrets.passboltDemo = {
          apiVersion = "external-secrets.io/v1";
          kind = "ExternalSecret";
          metadata = {
            name = "passbolt-demo";
            namespace = namespace;
          };
          spec = {
            refreshInterval = "1h";
            secretStoreRef = {
              name = "passbolt";
              kind = "SecretStore";
            };
            target.name = "passbolt-example";
            data = [
              {
                secretKey = "full_secret";
                remoteRef.key = "e22487a8-feb8-4591-95aa-14b193930cb4";
              }
              {
                secretKey = "password_only";
                remoteRef = {
                  key = "e22487a8-feb8-4591-95aa-14b193930cb4";
                  property = "password";
                };
              }
            ];
          };
        };
      };
    };
  };
}
