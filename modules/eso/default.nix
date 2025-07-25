# main module
{ lib, config, charts, ... }:
let
  cfg = config.secrets.external-secrets;
  namespace = "kube-system";
  values = cfg.values;
in {
  options.secrets.external-secrets = with lib; {
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
    nixidy.applicationImports = [ ./generated.nix ];
    
    applications.external-secrets = {
      inherit namespace;
      
      helm.releases.external-secrets = {
        inherit values;
        chart = charts.external-secrets.external-secrets;
      };
      
      # Now use the alias name that matches generated.nix
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
          target = {
            name = "passbolt-example";
          };
          data = [
            {
              secretKey = "full_secret";
              remoteRef = {
                key = "e22487a8-feb8-4591-95aa-14b193930cb4";
              };
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
}