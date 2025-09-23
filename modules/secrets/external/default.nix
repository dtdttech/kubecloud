# External Secrets Operator provider
{ lib, config, charts, ... }:
let
  cfg = config.secrets.providers.external;
  namespace = cfg.namespace;
  values = cfg.values;
in {
  options.secrets.providers.external = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable External Secrets Operator";
    };

    namespace = mkOption {
      type = types.str;
      default = "external-secrets-system";
      description = "Namespace for External Secrets Operator";
    };

    values = mkOption {
      type = types.attrsOf types.anything;
      default = {
        installCRDs = true;
        replicaCount = 1;
        serviceMonitor.enabled = true;
        metrics.enabled = true;
        webhook = {
          create = true;
          port = 9443;
        };
        certController = {
          create = true;
        };
      };
      description = "Helm values for External Secrets Operator";
    };

    secretStores = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          provider = mkOption {
            type = types.enum [ "vault" "aws" "azure" "gcp" "kubernetes" ];
            description = "Secret store provider type";
          };

          namespace = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Namespace for SecretStore (null for ClusterSecretStore)";
          };

          config = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Provider-specific configuration";
          };

          auth = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Authentication configuration";
          };
        };
      });
      default = {};
      description = "Secret stores configuration";
      example = {
        vault-store = {
          provider = "vault";
          namespace = "default";
          config = {
            server = "https://vault.example.com";
            path = "secret";
            version = "v2";
          };
          auth = {
            kubernetes = {
              mountPath = "kubernetes";
              role = "external-secrets";
            };
          };
        };
      };
    };

    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable monitoring for External Secrets Operator";
      };

      alerts = {
        externalSecretFailure = mkOption {
          type = types.bool;
          default = true;
          description = "Alert on external secret sync failures";
        };

        secretStoreUnhealthy = mkOption {
          type = types.bool;
          default = true;
          description = "Alert when secret stores are unhealthy";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ./generated.nix ];
    
    applications.external-secrets = {
      inherit namespace;
      createNamespace = true;
      
      helm.releases.external-secrets = {
        inherit values;
        chart = charts.external-secrets.external-secrets;
      };

      resources = 
        # Create SecretStores and ClusterSecretStores
        lib.mapAttrs' (name: store: {
          name = if store.namespace != null 
            then "secretStores.${name}"
            else "clusterSecretStores.${name}";
          value = {
            apiVersion = "external-secrets.io/v1beta1";
            kind = if store.namespace != null then "SecretStore" else "ClusterSecretStore";
            metadata = {
              inherit name;
            } // lib.optionalAttrs (store.namespace != null) {
              namespace = store.namespace;
            };
            spec = {
              provider = 
                if store.provider == "vault" then {
                  vault = store.config // {
                    auth = store.auth;
                  };
                }
                else if store.provider == "aws" then {
                  aws = store.config // {
                    auth = store.auth;
                  };
                }
                else if store.provider == "azure" then {
                  azurekv = store.config // {
                    auth = store.auth;
                  };
                }
                else if store.provider == "gcp" then {
                  gcpsm = store.config // {
                    auth = store.auth;
                  };
                }
                else if store.provider == "kubernetes" then {
                  kubernetes = store.config // {
                    auth = store.auth;
                  };
                }
                else throw "Unsupported secret store provider: ${store.provider}";
            };
          };
        }) cfg.secretStores;
    };

    # Monitoring configuration for External Secrets Operator
    monitoring.prometheus.rules = lib.mkIf cfg.monitoring.enable [
      {
        name = "external-secrets";
        rules = [
          ({
            alert = "ExternalSecretSyncFailure";
            expr = ''
              increase(external_secrets_sync_calls_error_total[5m]) > 0
            '';
            for = "5m";
            labels.severity = "warning";
            annotations = {
              summary = "External secret {{ $labels.name }} sync failing";
              description = "External secret {{ $labels.name }} in namespace {{ $labels.namespace }} has failed to sync for 5 minutes";
            };
          } // lib.optionalAttrs cfg.monitoring.alerts.externalSecretFailure {})

          ({
            alert = "SecretStoreUnhealthy";
            expr = ''
              external_secrets_secret_store_connection_status != 1
            '';
            for = "10m";
            labels.severity = "critical";
            annotations = {
              summary = "Secret store {{ $labels.name }} is unhealthy";
              description = "Secret store {{ $labels.name }} in namespace {{ $labels.namespace }} has been unhealthy for 10 minutes";
            };
          } // lib.optionalAttrs cfg.monitoring.alerts.secretStoreUnhealthy {})

          {
            alert = "ExternalSecretStale";
            expr = ''
              (time() - external_secrets_sync_calls_total) > 86400
            '';
            for = "1h";
            labels.severity = "warning";
            annotations = {
              summary = "External secret {{ $labels.name }} hasn't synced in 24 hours";
              description = "External secret {{ $labels.name }} in namespace {{ $labels.namespace }} hasn't synced successfully for 24 hours";
            };
          }
        ];
      }
    ];
  };
}